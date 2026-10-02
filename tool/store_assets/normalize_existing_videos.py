#!/usr/bin/env python3
"""Normalize original LFS movies' encoding; this does NOT prove capture provenance."""
import concurrent.futures,hashlib,json,pathlib,subprocess
ROOT=pathlib.Path('build/store_assets');OUT=ROOT/'video_encoding_candidates';OUT.mkdir(parents=True,exist_ok=True)
def encode(src):
 dest=OUT/src.name
 cmd=['ffmpeg','-y','-hide_banner','-loglevel','error','-i',str(src),'-map','0:v:0','-map','0:a:0','-c:v','libx264','-threads','1','-preset','veryfast','-profile:v','high','-level:v','4.0','-pix_fmt','yuv420p','-b:v','11M','-maxrate','12M','-bufsize','12M','-r','30','-c:a','aac','-b:a','256k','-ar','48000','-ac','2','-movflags','+faststart',str(dest)]
 subprocess.run(cmd,check=True)
 probe=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_format','-show_streams','-of','json',str(dest)]))
 v=next(s for s in probe['streams'] if s['codec_type']=='video');a=next(s for s in probe['streams'] if s['codec_type']=='audio')
 assert(v['width'],v['height'],v['level'],v['r_frame_rate'])==(886,1920,40,'30/1')
 assert a['sample_rate']=='48000' and a['channels']==2
 row={'locale':src.stem[3:],'path':str(dest),'bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'source':str(src),'origin':'reencoded_existing_marketing_video','native_screen_capture_provenance':'unverified','upload_status':'hold_for_provenance_and_editorial_review','ffmpeg_command':cmd,'probe':probe}
 print(src.name,'normalized',flush=True);return row
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(encode,sorted((ROOT/'original_pv').glob('*.mp4'))))
(OUT/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
