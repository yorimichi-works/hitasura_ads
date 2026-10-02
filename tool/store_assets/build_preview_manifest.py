#!/usr/bin/env python3
"""Inventory actual pixels without claiming native capture or upload readiness."""
import argparse,hashlib,json,pathlib,struct,subprocess
p=argparse.ArgumentParser();p.add_argument('--status',default='rendering_in_progress');a=p.parse_args()
root=pathlib.Path('build/store_assets');results=json.loads((root/'render_results.json').read_text());passed={r['locale'] for r in results if r['exit_code']==0};records=[]
for file in sorted((root/'flutter_previews').glob('*/*/*.png')):
 data=file.read_bytes();lang,device,scene=file.parts[-3:];width,height=struct.unpack('>II',data[16:24])
 records.append({'path':str(file),'locale':lang,'device':device,'scene':file.stem,'width':width,'height':height,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'png_color_type':data[25],'alpha_channel_present':data[25] in [4,6],'renderer':'flutter_test_production_widgets','native_ios_capture':False,'render_test_passed':lang in passed,'submission_status':'content_preview_not_native_capture'})
sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
manifest={'status':a.status,'inventory_git_sha':sha,'note':'Earlier local renders may predate this inventory SHA; capture logs and file hashes are retained. Release patch changed later settings/purchase/notification labels, not these five captured screen layouts.','locales_verified':sorted(passed),'verified_screenshot_count':sum(r['render_test_passed'] for r in records),'unverified_or_partial_count':sum(not r['render_test_passed'] for r in records),'target_total':200,'render_results':results,'records':records}
(root/'flutter_preview_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in manifest.items() if k not in ['records','render_results']},ensure_ascii=False))
