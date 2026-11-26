"""Generate public, synthetic media only; no credentials or private streams."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

root=Path("build/web/jellop-test/v1")
root.mkdir(parents=True,exist_ok=True)
release=os.environ["GITHUB_SHA"]
assert re.fullmatch("[0-9a-f]{40}",release)
subprocess.run(["ffmpeg","-v","error","-y","-f","lavfi","-i","testsrc2=size=640x360:rate=24",
    "-f","lavfi","-i","sine=frequency=440:sample_rate=48000","-t","48",
    "-c:v","libx264","-preset","ultrafast","-threads","2","-pix_fmt","yuv420p","-g","48",
    "-c:a","aac","-b:a","96k","-f","hls","-hls_time","2","-hls_list_size","0",
    "-hls_segment_filename",str(root/"seg%03d.ts"),str(root/"fixture.m3u8")],check=True,timeout=120)
assets={}
for path in sorted(root.iterdir()):
    if path.name=="fixture.m3u8" or re.fullmatch(r"seg\d{3}\.ts",path.name):
        data=path.read_bytes()
        assert 0<len(data)<4*1024*1024
        assets[path.name]={"sha256":hashlib.sha256(data).hexdigest(),"bytes":len(data)}
assert 2<=len(assets)<=40 and sum(a["bytes"] for a in assets.values())<32*1024*1024
(root/"manifest.json").write_text(json.dumps({"schemaVersion":1,"release":release,"synthetic":True,"assets":assets},indent=2)+"\n")
print("Generated bounded synthetic HLS fixture:",len(assets),"assets")
