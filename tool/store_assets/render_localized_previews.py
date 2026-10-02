#!/usr/bin/env python3
"""Run each locale in a fresh Flutter test process to isolate thumbnail caches.
Use --resume to skip prior successful locales. Creating the pause file stops
before the next locale without discarding completed captures.
"""
import argparse,json,os,pathlib,subprocess
LOCALES=['en','ja','zh','zh_TW','ko','es','fr','de','pt','ru','it','hi','bn','ar','ur','fa','id','tr','vi','th']
p=argparse.ArgumentParser();p.add_argument('--flutter',default='flutter');p.add_argument('--locales',default=','.join(LOCALES));p.add_argument('--resume',action='store_true');p.add_argument('--pause-file',default='build/store_assets/PAUSE_RENDERING');a=p.parse_args()
out=pathlib.Path('build/store_assets');out.mkdir(parents=True,exist_ok=True)
result_path=out/'render_results.json'
results=json.loads(result_path.read_text()) if result_path.exists() else []
for locale in a.locales.split(','):
 if locale not in LOCALES:raise ValueError(locale)
 if pathlib.Path(a.pause_file).exists():print('Paused before next locale; completed assets preserved.',flush=True);break
 if a.resume and any(r['locale']==locale and r['exit_code']==0 for r in results):continue
 log=out/f'render_{locale}.log'
 with log.open('w') as f:r=subprocess.run([a.flutter,'--suppress-analytics','test','tool/store_assets/localized_ui_snap_test.dart','--no-pub',f'--dart-define=CAPTURE_LOCALES={locale}','--reporter','expanded'],stdout=f,stderr=subprocess.STDOUT,env=dict(os.environ,CI='true'),timeout=360)
 results=[r0 for r0 in results if r0['locale']!=locale]+[{'locale':locale,'exit_code':r.returncode,'log':str(log)}]
 print(locale,r.returncode,flush=True);result_path.write_text(json.dumps(results,indent=2))
raise SystemExit(any(r['exit_code'] for r in results))
