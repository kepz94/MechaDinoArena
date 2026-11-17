#!/bin/bash
# gen_point_vo.sh v1.4 (Mecha Dino Arena) — the Hardpoint voice callouts (MDA-552, sound pass round 12); v1.1: the match intro
# lines in voice A (round 13, MDA_SFX_vo_intro<n>.wav); v1.2: the post-game title lines, voice A, radio R and stadium S
# (round 14, MDA_SFX_vt_<title><n>_<R|S>.wav); v1.3: those lines rewritten as a commander on the radio (round 14b, Kepu "It's
# like a commander talking to you. This is just a narrator."), voices A am_michael 0.97 / B bm_george 0.95, radio filter,
# MDA_SFX_vt_<title><n>_<A|B>.wav; v1.4: the commander's result lines (victory / defeat, round 14c presentation mockup),
# MDA_SFX_vr_<win|lose><n>_<A|B>.wav. Lines synthesized with
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
# v1.1 the match intro lines (round 13), voice A (am_michael 1.05, the radio style)
python3 -I "$T/say.py" "$M" "$V" "$T/raw_intro" am_michael 1.05 \
  "intro1=Hardpoint's up. Get there first, and use your mecha upgrades to your advantage." \
  "intro2=All units, move to the hardpoint. Your mecha upgrades are your edge. Use them." \
  "intro3=Mechs online. Take the hardpoint and hold it. Make every upgrade count." \
  "intro4=Listen up. The hardpoint is marked. Gear up, move out, and hold that ground." \
  "intro5=Systems hot. Get to the hardpoint, and let your upgrades do the talking."
F="highpass=f=320,lowpass=f=3300,acompressor=threshold=-18dB:ratio=4:attack=5:release=60,asoftclip=type=tanh:param=1.6,volume=1.2"
for i in 1 2 3 4 5; do
  ffmpeg -v error -y -i "$T/raw_intro/intro$i.wav" -af "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,$F,loudnorm=I=-14:TP=-1:LRA=7,aresample=48000" -ac 1 -c:a pcm_s16le "$OUT/MDA_SFX_vo_intro$i.wav"
done
# v1.2 the post-game title lines (round 14), voice A (am_michael 1.05), three per VictoryTitles 1.1 title, two treatments:
# R = the radio style above, S = clean with a big stadium echo
python3 -I "$T/say.py" "$M" "$V" "$T/raw_titles" am_michael 1.05 \
  "apex1=Apex Predator! Top of the food chain!" "apex2=Apex Predator! Nothing on this island eats you." \
  "apex3=Apex Predator! The whole lobby is on the menu." \
  "king1=King of the Hill! Wouldn't get off the point!" "king2=King of the Hill! That point has a new owner." \
  "king3=King of the Hill! Planted, and refused to move." \
  "unkill1=Unkillable! The asteroid missed. Again." "unkill2=Unkillable! They threw everything, and it didn't matter." \
  "unkill3=Unkillable! Somebody check that health bar. It's broken." \
  "medic1=Medic! Patched up the whole team!" "medic2=Medic! Kept the whole squad in the fight." \
  "medic3=Medic! Nobody stays down on this watch." \
  "masher1=Button Masher! Never met a cooldown it liked!" "masher2=Button Masher! Every upgrade, every second." \
  "masher3=Button Masher! Those buttons are smoking." \
  "extinct1=Extinct. Died the most. Again." "extinct2=Extinct. The respawn screen is your best friend." \
  "extinct3=Extinct. Somebody put this one in a museum." \
  "carried1=Carried! Packed up, and carried to the win." "carried2=Carried! Thank your team for the free ride." \
  "carried3=Carried! Feet up, trophy in hand." \
  "pacifist1=Pacifist! Won without hurting a fly." "pacifist2=Pacifist! Zero damage. Full victory." \
  "pacifist3=Pacifist! Peace was the only option."
FR="highpass=f=320,lowpass=f=3300,acompressor=threshold=-18dB:ratio=4:attack=5:release=60,asoftclip=type=tanh:param=1.6,volume=1.2"
FS="highpass=f=80,equalizer=f=3000:t=q:w=1:g=3,acompressor=threshold=-20dB:ratio=4:attack=3:release=80,apad=pad_dur=0.6,aecho=0.8:0.7:60|120|190:0.32|0.22|0.14"
TRIM="silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse"
for t in apex king unkill medic masher extinct carried pacifist; do for i in 1 2 3; do
  ffmpeg -v error -y -i "$T/raw_titles/$t$i.wav" -af "$TRIM,$FR,loudnorm=I=-14:TP=-1:LRA=7,aresample=48000" -ac 1 -c:a pcm_s16le "$OUT/MDA_SFX_vt_$t${i}_R.wav"
  ffmpeg -v error -y -i "$T/raw_titles/$t$i.wav" -af "$FS,$TRIM,loudnorm=I=-14:TP=-1:LRA=7,aresample=48000" -ac 1 -c:a pcm_s16le "$OUT/MDA_SFX_vt_$t${i}_S.wav"
done; done
# v1.3 the post-game title lines as a commander on the radio (round 14b); replaces the v1.2 narrator lines on the pick page
python3 - "$T/cmd_lines.txt" <<'PY'
import sys
open(sys.argv[1], "w").write("""apex1=Command here. Our apex predator owned that field. Outstanding.
apex2=Apex predator. They hunted down everything that moved. Good work.
apex3=Top of the food chain. That's how we win wars, people.
king1=King of the hill. They held that point like their life depended on it.
king2=Command here. Our anchor never gave up the hardpoint. Well done.
king3=That point was ours all match. King of the hill. Outstanding.
unkill1=Unkillable. They took everything the enemy had, and kept coming.
unkill2=Command here. Nothing they threw mattered. Tough as they come.
unkill3=Unkillable. Somebody get that dino a medal.
medic1=Our medic kept this squad standing. Nobody wins without them.
medic2=Command here. Every wound patched, every unit back in the fight.
medic3=Medic. Best support on the field. Outstanding work.
masher1=Button masher. Every upgrade, off cooldown, all match. I like it.
masher2=Command here. They burned through every system we gave them.
masher3=Those upgrades never got a rest. Aggressive. Effective.
extinct1=Extinct. Most deaths on the team. We won anyway. Somehow.
extinct2=Command here. Somebody explain how they died that much.
extinct3=Extinct. Respawns aren't free, soldier. Lucky we won.
carried1=Carried. The squad did the heavy lifting. Say thank you.
carried2=Command here. That one rode the team all the way to the win.
carried3=Carried. A win's a win. Don't make it a habit.
pacifist1=Pacifist. Zero damage, full victory. I don't know how.
pacifist2=Command here. Didn't land a hit, still brought it home.
pacifist3=Pacifist. Next time, try hitting something.
""")
PY
mapfile -t CL < "$T/cmd_lines.txt"
python3 -I "$T/say.py" "$M" "$V" "$T/raw_cmd_A" am_michael 0.97 "${CL[@]}"
python3 -I "$T/say.py" "$M" "$V" "$T/raw_cmd_B" bm_george 0.95 "${CL[@]}"
for v in A B; do for f in "$T"/raw_cmd_$v/*.wav; do n=$(basename "$f" .wav)
  ffmpeg -v error -y -i "$f" -af "$TRIM,$FR,loudnorm=I=-14:TP=-1:LRA=7,aresample=48000" -ac 1 -c:a pcm_s16le "$OUT/MDA_SFX_vt_${n}_$v.wav"
done; done
# v1.4 the commander's result lines (round 14c): said right after the win / lose sting, inside the 2 s VICTORY banner
mapfile -t RL <<'L'
win1=Mission accomplished.
win2=Good work. Match is ours.
win3=Victory. Well fought.
lose1=Mission failed.
lose2=We lost this one. Regroup.
lose3=Fall back. Regroup.
L
python3 -I "$T/say.py" "$M" "$V" "$T/raw_res_A" am_michael 0.97 "${RL[@]}"
python3 -I "$T/say.py" "$M" "$V" "$T/raw_res_B" bm_george 0.95 "${RL[@]}"
for v in A B; do for f in "$T"/raw_res_$v/*.wav; do n=$(basename "$f" .wav)
  ffmpeg -v error -y -i "$f" -af "$TRIM,$FR,loudnorm=I=-14:TP=-1:LRA=7,aresample=48000" -ac 1 -c:a pcm_s16le "$OUT/MDA_SFX_vr_${n}_$v.wav"
done; done
