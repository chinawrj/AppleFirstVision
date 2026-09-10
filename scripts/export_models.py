"""Reproducible official YOLO26 FP16 export (640px, end-to-end, no NMS)."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
import ultralytics
import coremltools
from ultralytics import YOLO

parser = argparse.ArgumentParser()
parser.add_argument('--variants', nargs='+', default=['m', 's', 'x'], choices=list('nsmlx'))
parser.add_argument('--force', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
cache = root / 'artifacts' / 'weights'
cache.mkdir(parents=True, exist_ok=True)
for variant in args.variants:
    name = f'yolo26{variant}'
    weights = cache / f'{name}.pt'
    target = root / 'AppleFirstVision' / 'Models' / f'{name}.mlpackage'
    manifest = target.with_suffix('.json')
    expected = json.loads(manifest.read_text()) if manifest.exists() else {}
    if not weights.exists() or (expected and hashlib.sha256(weights.read_bytes()).hexdigest() != expected['weights_sha256']):
        temporary = weights.with_suffix('.pt.download')
        subprocess.run(['curl', '--fail', '--location', '--retry', '3', '--connect-timeout', '20',
                        '--max-time', '600', f'https://github.com/ultralytics/assets/releases/download/v8.4.0/{name}.pt',
                        '--output', str(temporary)], check=True)
        temporary.replace(weights)
    digest = hashlib.sha256(weights.read_bytes()).hexdigest()
    if expected and digest != expected['weights_sha256']:
        raise RuntimeError(f'Official weight checksum mismatch: {name}')
    if target.exists() and expected and not args.force:
        print(f'{name}: verified weights; using existing Core ML package', flush=True)
        continue
    model = YOLO(str(weights))
    output = Path(model.export(format='coreml', imgsz=640, quantize=16, nms=False, device='cpu'))
    if target.exists(): shutil.rmtree(target)
    shutil.copytree(output, target)
    metadata = {'model': name, 'ultralytics': ultralytics.__version__, 'coremltools': coremltools.__version__,
                'input': [1, 3, 640, 640], 'output': '[1,300,6] xyxy pixels, confidence, class; NMS-free',
                'weights_sha256': digest}
    manifest.write_text(json.dumps(metadata, indent=2) + '\n')
    (root / 'AppleFirstVision' / 'labels.json').write_text(json.dumps(list(model.names.values())) + '\n')
