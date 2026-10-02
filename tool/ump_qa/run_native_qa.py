#!/usr/bin/env python3
"""Run actual UMP native-form UI tests against a prebuilt QA simulator bundle."""
import argparse
import datetime
import importlib.util
import json
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]


def verify_sdk_events(path, started_at):
    events = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    start = datetime.datetime.fromisoformat(started_at.replace('Z', '+00:00'))
    events = [event for event in events if datetime.datetime.fromisoformat(event['at'].replace('Z', '+00:00')) >= start]
    if any(event.get('stage') == 'qa_error' for event in events):
        raise ValueError('Actual SDK event log contains an error')
    for stage in ('consent_update_complete', 'consent_complete', 'privacy_options_complete'):
        matches = [event for event in events if event.get('stage') == stage]
        if len(matches) != 2:
            raise ValueError(f'Expected two actual SDK {stage} events from this run')
        for event in matches:
            if event.get('native_simulator_attested') is not True or event.get('debug_mode') is not True:
                raise ValueError('Actual SDK evidence lacks simulator/debug attestation')
            if event.get('service_has_error') is not False:
                raise ValueError('Shipping consent service did not finish successfully')
            if event.get('sdk_privacy_options_status') != 'required':
                raise ValueError('Published EEA privacy-options requirement was not observed')
            if stage != 'consent_update_complete' and event.get('sdk_consent_status') != 'obtained':
                raise ValueError('Actual UMP did not finish collecting the test choice')
            if event.get('ad_initialization_requested') is not False or event.get('ad_load_requested') is not False:
                raise ValueError('QA entrypoint reported an unexpected ad operation')
    return events


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def select_compatible_device(capture, inventory, runtimes, sdk, runtime_version, minimum_os):
    if runtime_version is None:
        return capture.select_devices(inventory, runtimes, sdk, ['iphone_6_9'])[0]
    if not re.fullmatch(r'\d+\.\d+', runtime_version):
        raise ValueError('An explicit installed major.minor runtime is required')
    version = tuple(map(int, runtime_version.split('.')))
    minimum = tuple(map(int, str(minimum_os).split('.')[:2]))
    maximum = tuple(map(int, sdk.split('.')[:2]))
    if not minimum <= version <= maximum:
        raise ValueError('Requested runtime falls outside the built app/SDK range')
    # This function still requires an actual available inventory entry and its
    # real device. It does not download or invent a runtime/device identifier.
    return capture.select_devices(inventory, runtimes, runtime_version, ['iphone_6_9'])[0]


def main():
    if sys.platform != 'darwin':
        raise RuntimeError('Actual native UMP QA requires macOS and an installed iOS simulator')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', default='build/ump_qa_app/Runner.app')
    parser.add_argument('--xctestrun', required=True)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--ui-driver-source-sha', help='Separate source when only the native test driver was rebuilt')
    parser.add_argument('--runtime-version', help='Explicit installed compatible runtime for infrastructure diagnosis')
    parser.add_argument('--output', default='build/ump_qa_evidence')
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}', args.source_sha):
        raise ValueError('Exact built/tested source SHA is required')
    driver_sha = args.ui_driver_source_sha or args.source_sha
    if not re.fullmatch(r'[0-9a-f]{40}', driver_sha):
        raise ValueError('Exact native UI-driver source SHA is required')
    out = pathlib.Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=False)
    capture = module('capture_host', ROOT / 'tool/store_assets/capture_ios_simulator.py')
    preparation = module('qa_preparation', ROOT / 'tool/ump_qa/prepare_simulator_app.py')
    app = pathlib.Path(args.app).resolve()
    info, native = preparation.validate_simulator_qa_app(app)
    if info['GADApplicationIdentifier'] != preparation.HITASURA_APP_ID:
        raise ValueError('Actual Hitasura UMP messages require its exact approved app ID')
    host = capture.HostLog(out)
    host.work_deadline = time.monotonic() + 720
    udid = None
    container = None
    result = {'native_ump': True, 'status': 'not_run', 'native_bridge': native,
              'source_sha': args.source_sha,
              'ui_driver_source_sha': driver_sha,
              'host_script_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True, timeout=10).strip(),
              'ad_initialization_requested': False, 'ad_load_requested': False}
    shutil.copyfile(app.parent / 'provenance.json', out / 'qa_app_provenance.json')
    privacy = [{'path': str(path.relative_to(app)), 'contents': plistlib.loads(path.read_bytes())}
               for path in app.rglob('PrivacyInfo.xcprivacy')]
    (out / 'bundled_privacy_manifests.json').write_text(json.dumps(privacy, indent=2))
    try:
        inventory = capture.read_simulator_inventory(host, 'devices')
        runtimes = capture.read_simulator_inventory(host, 'runtimes')
        sdk = host.run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version', timeout=30).strip()
        _, runtime, device = select_compatible_device(capture, inventory, runtimes, sdk, args.runtime_version, info.get('MinimumOSVersion', '15.0'))
        udid = device['udid']
        result.update({'runtime': runtime, 'device': device, 'sdk': sdk})
        if device['state'] != 'Booted':
            host.run('xcrun', 'simctl', 'boot', udid, timeout=120)
        host.run('xcrun', 'simctl', 'bootstatus', udid, '-b', timeout=120)
        host.run('xcrun', 'simctl', 'install', udid, str(app), timeout=60)
        container = capture.lookup_app_container(host, udid)
        # The standalone UI-test runner launches only this installed Debug app.
        # Form interaction is XCTest native accessibility, never TCF injection.
        result['status'] = 'running'
        started_at = datetime.datetime.now(datetime.timezone.utc).isoformat().replace('+00:00', 'Z')
        result['test_started_at'] = started_at
        host.run('xcodebuild', 'test-without-building', '-xctestrun',
                 str(pathlib.Path(args.xctestrun).resolve()), '-destination', f'platform=iOS Simulator,id={udid}',
                 '-parallel-testing-enabled', 'NO', '-maximum-concurrent-test-simulator-destinations', '1',
                 '-test-timeouts-enabled', 'YES', '-default-test-execution-time-allowance', '180',
                 '-maximum-test-execution-time-allowance', '240',
                 '-resultBundlePath', str(out / 'UmpQa.xcresult'), timeout=420)
        verified = verify_sdk_events(pathlib.Path(container) / 'Documents/HitasuraUmpQa/events.jsonl', started_at)
        result['actual_sdk_events_verified'] = len(verified)
        result['status'] = 'xcuitest_passed_evidence_review_pending'
    except Exception as error:
        result.update({'status': 'failed', 'error': str(error)})
        raise
    finally:
        host.begin_cleanup()
        if (out / 'UmpQa.xcresult').exists():
            host.best_effort('xcrun', 'xcresulttool', 'export', 'attachments',
                             '--path', str(out / 'UmpQa.xcresult'),
                             '--output-path', str(out / 'native_attachments'), timeout=30)
        if container is not None:
            evidence = pathlib.Path(container) / 'Documents/HitasuraUmpQa'
            if evidence.exists():
                shutil.copytree(evidence, out / 'actual_sdk_events', dirs_exist_ok=True)
        if udid is not None:
            host.best_effort('xcrun', 'simctl', 'io', udid, 'screenshot', str(out / 'final_native_screen.png'), timeout=15)
            host.best_effort('xcrun', 'simctl', 'terminate', udid, capture.BUNDLE, timeout=10)
            host.best_effort('xcrun', 'simctl', 'shutdown', udid, timeout=30)
        capture.record_host_resources(host)
        (out / 'manifest.json').write_text(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
