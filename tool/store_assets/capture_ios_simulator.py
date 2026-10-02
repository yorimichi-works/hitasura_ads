#!/usr/bin/env python3
"""Capture unchanged production UI on native iOS simulators, with startup evidence.
No signing, credentials, or App Store upload. Raw screenshots/video require QA.
"""
import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import shutil
import signal
import struct
import subprocess
import sys
import time
import uuid

LOCALES = ['en','ja','zh','zh_TW','ko','es','fr','de','pt','ru','it','hi','bn','ar','ur','fa','id','tr','vi','th']
SCENES = ['home','collection','pin','runner','rush']
BUNDLE = 'com.syamo.hitasuraads'

def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)

def wait_for_capture(path, locale, scene, launch_id, timeout=90, poll=.25):
    """Reject stale or failed startup evidence; report the last stage on timeout."""
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            state = json.loads(path.read_text())
            if state.get('launch_id') == launch_id:
                last = state
                if state.get('stage') == 'error':
                    raise RuntimeError(f'Capture app error: {state}')
                if state.get('stage') == 'ready':
                    if state.get('locale') != locale or state.get('requested_scene') != scene:
                        raise RuntimeError(f'Launch environment mismatch: {state}')
                    return state
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        time.sleep(poll)
    raise TimeoutError(f'Capture not ready after {timeout}s; state_path={path}; last_stage={last}')

def collect_diagnostics(udid, state_path, dest):
    dest.mkdir(parents=True, exist_ok=True)
    for suffix in ['', '.events.jsonl']:
        source = pathlib.Path(str(state_path) + suffix)
        if source.exists():
            shutil.copyfile(source, dest / ('startup_state.json' if not suffix else 'startup_events.jsonl'))
    commands = {
        'runner_system_log.txt': ['xcrun','simctl','spawn',udid,'log','show','--style','compact','--last','3m','--predicate','process == "Runner"'],
        'launchctl_jobs.txt': ['xcrun','simctl','spawn',udid,'launchctl','list'],
    }
    for name, command in commands.items():
        try:
            with (dest / name).open('w') as output:
                subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, text=True, timeout=20, check=False)
        except subprocess.TimeoutExpired:
            (dest / (name + '.timeout')).write_text('Diagnostic command exceeded 20 seconds.\n')
    subprocess.run(['xcrun','simctl','io',udid,'screenshot','--type=png',str(dest/'startup_failure.png')], timeout=20, check=False)
    crash_root = pathlib.Path.home() / 'Library/Logs/DiagnosticReports'
    for source in sorted(crash_root.glob('Runner*'), key=lambda p: p.stat().st_mtime, reverse=True)[:5]:
        if source.is_file():
            shutil.copyfile(source, dest / source.name)

def launch_capture(udid, locale, scene, container, dest, timeout):
    # The host asks simctl for the real app data container; no systemTemp guess.
    state_path = container / 'Documents/HitasuraCapture/state.json'
    state_path.parent.mkdir(parents=True, exist_ok=True)
    launch_id = str(uuid.uuid4())
    env = dict(os.environ,
        SIMCTL_CHILD_HITASURA_CAPTURE_LOCALE=locale,
        SIMCTL_CHILD_HITASURA_CAPTURE_SCENE=scene,
        SIMCTL_CHILD_HITASURA_CAPTURE_STATE_PATH=str(state_path),
        SIMCTL_CHILD_HITASURA_CAPTURE_ID=launch_id)
    console = (dest / f'{scene}_console.log').open('w')
    process = subprocess.Popen(['xcrun','simctl','launch','--console','--terminate-running-process',udid,BUNDLE],
        stdout=console, stderr=subprocess.STDOUT, text=True, env=env)
    try:
        evidence = wait_for_capture(state_path, locale, scene, launch_id, timeout=timeout)
        for suffix in ['', '.events.jsonl']:
            source = pathlib.Path(str(state_path) + suffix)
            if source.exists():
                shutil.copyfile(source, dest / f'{scene}_state{suffix or ".json"}')
        return evidence, process, console
    except Exception:
        collect_diagnostics(udid, state_path, dest / f'{scene}_failure')
        subprocess.run(['xcrun','simctl','terminate',udid,BUNDLE], check=False, capture_output=True)
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
        console.close()
        raise

def finish_launch(udid, process, console):
    subprocess.run(['xcrun','simctl','terminate',udid,BUNDLE], check=False, capture_output=True)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.terminate()
        process.wait(timeout=10)
    console.close()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', default='build/ios/iphonesimulator/Runner.app')
    parser.add_argument('--output', default='build/store_assets/native_ios')
    parser.add_argument('--locales', default=','.join(LOCALES))
    parser.add_argument('--devices', default='iphone_6_9,ipad_13')
    parser.add_argument('--videos', action='store_true')
    parser.add_argument('--startup-timeout', type=float, default=90)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('Native captures require macOS/Xcode; Flutter previews are not native captures.')
    locales = args.locales.split(',')
    if any(locale not in LOCALES for locale in locales):
        parser.error('Unknown locale')
    out = pathlib.Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    inventory = json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))
    (out/'simulator_inventory.json').write_text(json.dumps(inventory, indent=2))
    # Capture runtime CLI help with the artifact; its flags are authoritative.
    with (out/'simctl_launch_help.txt').open('w') as output:
        subprocess.run(['xcrun','simctl','help','launch'], stdout=output, stderr=subprocess.STDOUT, check=False)
    app = pathlib.Path(args.app)
    privacy = [{'path':str(file.relative_to(app)), 'contents':plistlib.loads(file.read_bytes())} for file in app.rglob('PrivacyInfo.xcprivacy')]
    packages = [{'path':str(file), 'contents':json.loads(file.read_text())} for file in pathlib.Path('ios').rglob('Package.resolved')]
    (out/'bundled_privacy_and_packages.json').write_text(json.dumps({'privacy_manifests':privacy,'resolved_packages':packages}, indent=2))
    choices = {
        'iphone_6_9':['iPhone 17 Pro Max','iPhone 16 Pro Max','iPhone 15 Pro Max','iPhone 14 Pro Max'],
        'ipad_13':['iPad Pro 13-inch (M4)','iPad Pro 13-inch (M5)','iPad Pro (12.9-inch) (6th generation)'],
    }
    devices = [(runtime, device) for runtime, group in inventory['devices'].items() if 'iOS' in runtime for device in group if device.get('isAvailable')]
    manifest = {'origin':'native_ios_simulator','app_target':'tool/store_assets/native_capture_main.dart','production_ui_unchanged':True,
        'fixture':'40 discovered games, 1234 coins, 900 XP, 5 tickets; notifications/audio/external ads disabled; production purchase initialization preserved',
        'status':'in_progress','records':[]}
    def save():
        (out/'manifest.json').write_text(json.dumps(manifest, indent=2))
    save()
    try:
        for group in args.devices.split(','):
            chosen = next(((runtime, device) for name in choices[group] for runtime, device in devices if device['name'] == name), None)
            if chosen is None:
                raise RuntimeError(f'No eligible {group} simulator; do not stretch a smaller image.')
            runtime, device = chosen
            udid = device['udid']
            if device['state'] != 'Booted':
                run('xcrun','simctl','boot',udid)
            run('xcrun','simctl','bootstatus',udid,'-b')
            run('xcrun','simctl','status_bar',udid,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100')
            run('xcrun','simctl','install',udid,args.app)
            container = pathlib.Path(subprocess.check_output(['xcrun','simctl','get_app_container',udid,BUNDLE,'data'], text=True).strip())
            for locale in locales:
                dest = out/locale/group
                dest.mkdir(parents=True, exist_ok=True)
                for index, scene in enumerate(SCENES + (['preview'] if args.videos else []), 1):
                    evidence, process, console = launch_capture(udid, locale, scene, container, dest, args.startup_timeout)
                    try:
                        record = {'locale':locale,'device_group':group,'device_name':device['name'],'runtime':runtime,'scene':scene,'app_evidence':evidence}
                        if scene == 'preview':
                            path = dest/'preview_native.mov'
                            video = subprocess.Popen(['xcrun','simctl','io',udid,'recordVideo','--codec=h264','--force',str(path)])
                            time.sleep(20)
                            video.send_signal(signal.SIGINT)
                            video.wait(timeout=30)
                            if video.returncode not in [0, -signal.SIGINT, 130] or not path.exists() or path.stat().st_size == 0:
                                raise RuntimeError(f'Native recording failed: {path}')
                            record.update({'audio':'not captured; silent','native_unencoded':True})
                        else:
                            time.sleep(4 if scene in ['pin','runner'] else 2)
                            path = dest/f'{index:02}_{scene}.png'
                            run('xcrun','simctl','io',udid,'screenshot','--type=png',str(path))
                            width, height = struct.unpack('>II', path.read_bytes()[16:24])
                            allowed = {(1290,2796),(1320,2868),(1260,2736)} if group == 'iphone_6_9' else {(2048,2732),(2064,2752)}
                            if (width,height) not in allowed:
                                raise RuntimeError(f'Unexpected dimensions {width}x{height}')
                            record['dimensions'] = [width,height]
                        record.update({'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'status':'raw_native_capture_requires_pixel_review_and_normalization'})
                        manifest['records'].append(record)
                        save()
                    finally:
                        finish_launch(udid, process, console)
            run('xcrun','simctl','shutdown',udid)
        manifest['status'] = 'captured_pending_pixel_review'
        save()
    except Exception as error:
        manifest.update({'status':'failed','error':str(error)})
        save()
        raise
    print(f'Native source captures saved in {out}; review pixels and encoding before upload.')

if __name__ == '__main__':
    main()
