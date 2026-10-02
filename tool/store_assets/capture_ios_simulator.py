#!/usr/bin/env python3
"""Native screenshot/preview collection. Requires macOS/Xcode and built debug harness.

No App Store upload, no credentials, no signing. Runs existing app widgets in an
actual iOS simulator. Output includes origin/evidence metadata. Video is silent
because simctl does not capture app audio; optional encoding adds a silent track.
"""
import argparse, hashlib, json, os, pathlib, signal, struct, subprocess, sys, time, plistlib
LOCALES = ['en','ja','zh','zh_TW','ko','es','fr','de','pt','ru','it','hi','bn','ar','ur','fa','id','tr','vi','th']
SCENES = ['home','collection','pin','runner','rush']
BUNDLE = 'com.syamo.hitasuraads'

def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)

def capture_state(udid, locale, scene):
    container=pathlib.Path(subprocess.check_output(['xcrun','simctl','get_app_container',udid,BUNDLE,'data'],text=True).strip())
    state=json.loads((container/'tmp/hitasura_capture_state.json').read_text())
    if state['locale']!=locale or state['requested_scene']!=scene:
        raise RuntimeError(f'Capture launch environment was not applied: {state}')
    return state

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--app',default='build/ios/iphonesimulator/Runner.app')
    p.add_argument('--output',default='build/store_assets/native_ios')
    p.add_argument('--locales',default=','.join(LOCALES))
    p.add_argument('--devices',default='iphone_6_9,ipad_13')
    p.add_argument('--videos',action='store_true')
    a=p.parse_args()
    if sys.platform!='darwin': p.error('Native captures require macOS/Xcode; Flutter previews are not native captures.')
    locales=a.locales.split(',')
    if any(l not in LOCALES for l in locales): p.error('Unknown locale')
    out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=True)
    inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))
    (out/'simulator_inventory.json').write_text(json.dumps(inventory,indent=2))
    app=pathlib.Path(a.app)
    privacy=[]
    for file in app.rglob('PrivacyInfo.xcprivacy'):
        privacy.append({'path':str(file.relative_to(app)), 'contents':plistlib.loads(file.read_bytes())})
    resolved=[]
    for file in pathlib.Path('ios').rglob('Package.resolved'):
        resolved.append({'path':str(file),'contents':json.loads(file.read_text())})
    (out/'bundled_privacy_and_packages.json').write_text(json.dumps({'privacy_manifests':privacy,'resolved_packages':resolved},indent=2))
    choices={
        'iphone_6_9':['iPhone 17 Pro Max','iPhone 16 Pro Max','iPhone 15 Pro Max','iPhone 14 Pro Max'],
        'ipad_13':['iPad Pro 13-inch (M4)','iPad Pro 13-inch (M5)','iPad Pro (12.9-inch) (6th generation)'],
    }
    devices=[(runtime,d) for runtime,ds in inventory['devices'].items() if 'iOS' in runtime for d in ds if d.get('isAvailable')]
    manifest={'origin':'native_ios_simulator','app_target':'tool/store_assets/native_capture_main.dart','production_ui_unchanged':True,'fixture':'40 discovered games, 1234 coins, 900 XP, 5 tickets; notifications/audio/external ads disabled','records':[]}
    for group in a.devices.split(','):
        chosen=next(((runtime,d) for name in choices[group] for runtime,d in devices if d['name']==name),None)
        if chosen is None: raise RuntimeError(f'No eligible {group} simulator. Inspect simulator_inventory.json; do not stretch a smaller image.')
        runtime,d=chosen;udid=d['udid']
        if d['state']!='Booted': run('xcrun','simctl','boot',udid)
        run('xcrun','simctl','bootstatus',udid,'-b')
        run('xcrun','simctl','status_bar',udid,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100')
        run('xcrun','simctl','install',udid,a.app)
        for locale in locales:
            dest=out/locale/group;dest.mkdir(parents=True,exist_ok=True)
            for idx,scene in enumerate(SCENES,1):
                env=dict(os.environ,SIMCTL_CHILD_HITASURA_CAPTURE_LOCALE=locale,SIMCTL_CHILD_HITASURA_CAPTURE_SCENE=scene)
                run('xcrun','simctl','launch','--terminate-running-process',udid,BUNDLE,env=env)
                time.sleep(6 if scene in ['pin','runner'] else 5)
                evidence=capture_state(udid,locale,scene)
                path=dest/f'{idx:02}_{scene}.png'
                run('xcrun','simctl','io',udid,'screenshot','--type=png',str(path))
                width,height=struct.unpack('>II',path.read_bytes()[16:24])
                allowed={(1290,2796),(1320,2868),(1260,2736)} if group=='iphone_6_9' else {(2048,2732),(2064,2752)}
                if (width,height) not in allowed: raise RuntimeError(f'Unexpected dimensions: {width}x{height}')
                manifest['records'].append({'locale':locale,'device_group':group,'device_name':d['name'],'runtime':runtime,'scene':scene,'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'dimensions':[width,height],'app_evidence':evidence,'status':'raw_native_capture_requires_pixel_review_and_alpha_removal'})
            if a.videos:
                env=dict(os.environ,SIMCTL_CHILD_HITASURA_CAPTURE_LOCALE=locale,SIMCTL_CHILD_HITASURA_CAPTURE_SCENE='preview')
                run('xcrun','simctl','launch','--terminate-running-process',udid,BUNDLE,env=env);time.sleep(3)
                evidence=capture_state(udid,locale,'preview')
                path=dest/'preview_native.mov'
                record=subprocess.Popen(['xcrun','simctl','io',udid,'recordVideo','--codec=h264','--force',str(path)])
                time.sleep(20);record.send_signal(signal.SIGINT);record.wait(timeout=30)
                if record.returncode: raise RuntimeError(f'Video capture failed: {path}')
                manifest['records'].append({'locale':locale,'device_group':group,'device_name':d['name'],'runtime':runtime,'scene':'preview','path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'audio':'not captured; silent','native_unencoded':True,'app_evidence':evidence})
            (out/'manifest.json').write_text(json.dumps(manifest,indent=2))
        run('xcrun','simctl','terminate',udid,BUNDLE)
        run('xcrun','simctl','shutdown',udid)
    print(f'Native capture complete: {out}/manifest.json. Pixel/locale review and encoding remain required before upload.')
if __name__=='__main__':main()
