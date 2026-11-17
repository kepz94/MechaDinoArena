#!/bin/bash
# gen_point_vo.sh v1.0 (Mecha Dino Arena) — the Hardpoint voice callouts (MDA-552, sound pass round 12). Lines synthesized with
# Kokoro-82M (Apache-2.0; kokoro-onnx, model-files-v1.0 from github.com/thewh1teagle/kokoro-onnx releases), then trimmed,
# styled and levelled with ffmpeg (-14 LUFS, -1 dBTP, mono 48 kHz). Usage: gen_point_vo.sh <kokoro.onnx> <voices.bin> <out dir>
# Needs tools/mockup's sibling script say.py (below, written to a temp dir) and: pip install kokoro-onnx soundfile.
set -e
M="$1"; V="$2"; OUT="$3"; T=$(mktemp -d)
cat > "$T/say.py" <<'PY'
import sys, os
from kokoro_onnx import Kokoro
import soundfile as sf
model, voices, out_dir, voice, speed = sys.argv[1:6]
k = Kokoro(model, voices); os.makedirs(out_dir, exist_ok=True)
for item in sys.argv[6:]:
    name, text = item.split("=", 1)
    s, sr = k.create(text, voice=voice, speed=float(speed), lang="en-us"); sf.write(os.path.join(out_dir, name + ".wav"), s, sr)
PY
mkdir -p "$OUT"
for spec in "A am_michael 1.05" "B bm_george 1.0" "C af_heart 1.05"; do
  set -- $spec
  python3 -I "$T/say.py" "$M" "$V" "$T/raw_$1" "$2" "$3" "secured=Hardpoint secured." "lost=Enemy has the hardpoint." "contested=Hardpoint contested."
  case $1 in
    A) F="highpass=f=320,lowpass=f=3300,acompressor=threshold=-18dB:ratio=4:attack=5:release=60,asoftclip=type=tanh:param=1.6,volume=1.2";;
    B) F="highpass=f=70,acompressor=threshold=-20dB:ratio=3:attack=5:release=80,aecho=0.8:0.6:18:0.12";;
    C) F="highpass=f=90,flanger=delay=1.5:depth=1.2:regen=10:width=60:speed=0.4,acompressor=threshold=-20dB:ratio=3:attack=5:release=80";;
  esac
  for l in secured lost contested; do
    ffmpeg -v error -y -i "$T/raw_$1/$l.wav" -af "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,$F,loudnorm=I=-14:TP=-1:LRA=7,aresample=48000" -ac 1 -c:a pcm_s16le "$OUT/MDA_SFX_vo_${l}_$1.wav"
  done
done
