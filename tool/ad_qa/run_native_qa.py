#!/usr/bin/env python3
"""One real Google demo rewarded-ad smoke; native indicator proof is mandatory."""
import argparse
import datetime
import importlib.util
import json
import pathlib
import re
import shutil
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
TARGET = 'tool/ad_qa/rewarded_ad_qa_main.dart'
DEMO_UNIT = 'ca-app-pub-3940256099942544/1712485313'


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def verify_events(path, started_at):
    start = datetime.datetime.fromisoformat(started_at.replace('Z', '+00:00'))
    events = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    events = [event for event in events if datetime.datetime.fromisoformat(
        event['at'].replace('Z', '+00:00')) >= start]
    if any(event.get('stage') == 'ad_qa_error' or
           str(event.get('stage')).endswith('_failed') for event in events):
        raise ValueError('Actual SDK flow reported an error')
    for event in events:
        if (event.get('target') != TARGET or event.get('ad_mode') != 'test' or
                event.get('expected_demo_unit') != DEMO_UNIT or
                event.get('service_uses_test_ads') is not True or
                event.get('native_simulator_attested') is not True or
                event.get('debug_mode') is not True):
            raise ValueError('Demo unit, runtime or service attestation missing')
    stages = ('sdk_initialized', 'sdk_load_callback', 'ad_qa_loaded', 'sdk_show_requested',
              'sdk_reward_callback', 'sdk_dismiss_callback', 'ad_qa_complete')
    positions = []
    for stage in stages:
        matches = [(index, event) for index, event in enumerate(events) if event.get('stage') == stage]
        if len(matches) != 1:
            raise ValueError(f'Exactly one actual {stage} event required')
        index, event = matches[0]
        positions.append(index)
        if stage.startswith('sdk_') and event.get('source') != 'shipping_service_sdk_log':
            raise ValueError('Real shipping SDK callback source missing')
        if stage == 'ad_qa_loaded' and (event.get('sdk_can_request_ads') is not True or
                                      event.get('sdk_consent_status') != 'obtained'):
            raise ValueError('Actual UMP consent gate did not complete')
        if stage == 'ad_qa_complete' and event.get('result') != 'rewarded':
            raise ValueError('SDK did not report rewarded completion')
    if positions != sorted(positions):
        raise ValueError('Actual SDK callback ordering is invalid')
    return events


def main():
    if sys.platform != 'darwin':
        raise RuntimeError('Native QA requires macOS and an already installed iOS simulator')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', default='build/rewarded_qa_app/Runner.app')
    parser.add_argument('--xctestrun', required=True)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--runtime-version', default='18.6')
    parser.add_argument('--output', default='build/rewarded_qa_evidence')
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}', args.source_sha):
        raise ValueError('Exact built source SHA required')
    out = pathlib.Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=False)
    capture = module('capture_host', ROOT / 'tool/store_assets/capture_ios_simulator.py')
    preparation = module('rewarded_preparation', ROOT / 'tool/ad_qa/prepare_simulator_app.py')
    compatibility = module('simulator_compatibility', ROOT / 'tool/ump_qa/run_native_qa.py')
    app = pathlib.Path(args.app).resolve()
    info, native = preparation.validate(app)
    provenance = json.loads((app.parent / 'provenance.json').read_text())
    if (provenance.get('source_sha') != args.source_sha or
            provenance.get('target') != TARGET or provenance.get('ad_mode') != 'test' or
            provenance.get('demo_unit') != DEMO_UNIT or
            info.get('GADApplicationIdentifier') != preparation.HITASURA_APP_ID):
        raise ValueError('Built QA source/target/demo configuration mismatch')
    host = capture.HostLog(out)
    host.work_deadline = time.monotonic() + 720
    result = {'status': 'not_run', 'source_sha': args.source_sha,
              'target': TARGET, 'demo_unit': DEMO_UNIT, 'ad_mode': 'test',
              'native_bridge': native, 'app_store_archive': False,
              'host_script_sha': subprocess.check_output(
                  ['git', 'rev-parse', 'HEAD'], text=True, timeout=10).strip()}
    (out / 'qa_app_provenance.json').write_text(json.dumps(provenance, indent=2))
    udid = container = None
    try:
        inventory = capture.read_simulator_inventory(host, 'devices')
        runtimes = capture.read_simulator_inventory(host, 'runtimes')
        sdk = host.run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version', timeout=30).strip()
        _, runtime, device = compatibility.select_compatible_device(
            capture, inventory, runtimes, sdk, args.runtime_version, info.get('MinimumOSVersion', '15.0'))
        udid = device['udid']
        result.update({'runtime': runtime, 'device': device, 'sdk': sdk})
        if device['state'] != 'Booted':
            host.run('xcrun', 'simctl', 'boot', udid, timeout=120)
        host.run('xcrun', 'simctl', 'bootstatus', udid, '-b', timeout=120)
        host.run('xcrun', 'simctl', 'install', udid, str(app), timeout=60)
        container = capture.lookup_app_container(host, udid)
        started = datetime.datetime.now(datetime.timezone.utc).isoformat().replace('+00:00', 'Z')
        result.update({'status': 'running', 'test_started_at': started})
        host.run('xcodebuild', 'test-without-building', '-xctestrun',
                 str(pathlib.Path(args.xctestrun).resolve()),
                 '-destination', f'platform=iOS Simulator,id={udid}',
                 '-parallel-testing-enabled', 'NO', '-maximum-concurrent-test-simulator-destinations', '1',
                 '-test-timeouts-enabled', 'YES', '-default-test-execution-time-allowance', '300',
                 '-maximum-test-execution-time-allowance', '360',
                 '-resultBundlePath', str(out / 'RewardedQa.xcresult'), timeout=420)
        events = verify_events(pathlib.Path(container) / 'Documents/HitasuraRewardedQa/events.jsonl', started)
        result.update({'actual_sdk_events_verified': len(events),
                       'status': 'xcuitest_passed_native_test_mode_image_review_pending'})
    except Exception as error:
        result.update({'status': 'failed', 'error': str(error)})
        raise
    finally:
        host.begin_cleanup()
        if (out / 'RewardedQa.xcresult').exists():
            host.best_effort('xcrun', 'xcresulttool', 'export', 'attachments',
                             '--path', str(out / 'RewardedQa.xcresult'),
                             '--output-path', str(out / 'native_attachments'), timeout=30)
        if container:
            events_dir = pathlib.Path(container) / 'Documents/HitasuraRewardedQa'
            if events_dir.exists():
                shutil.copytree(events_dir, out / 'actual_sdk_events', dirs_exist_ok=True)
        if udid:
            host.best_effort('xcrun', 'simctl', 'io', udid, 'screenshot', str(out / 'final_native_screen.png'), timeout=15)
            host.best_effort('xcrun', 'simctl', 'terminate', udid, preparation.BUNDLE, timeout=10)
            host.best_effort('xcrun', 'simctl', 'shutdown', udid, timeout=30)
        capture.record_host_resources(host)
        (out / 'manifest.json').write_text(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
