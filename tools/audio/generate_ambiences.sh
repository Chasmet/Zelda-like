#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:-assets/audio/generated}"
mkdir -p "$OUTPUT_DIR"

make_noise() {
  local filename="$1"
  local color="$2"
  local amplitude="$3"
  local filter="$4"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "anoisesrc=color=${color}:amplitude=${amplitude}:duration=12:sample_rate=44100" \
    -af "${filter},afade=t=in:st=0:d=0.08,afade=t=out:st=11.92:d=0.08" \
    -ac 1 -c:a libvorbis -q:a 2 "$OUTPUT_DIR/$filename"
}

make_drone() {
  local filename="$1"
  local color="$2"
  local frequency="$3"
  local filter="$4"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "anoisesrc=color=${color}:amplitude=0.24:duration=12:sample_rate=44100" \
    -f lavfi -i "sine=frequency=${frequency}:duration=12:sample_rate=44100" \
    -filter_complex "[0:a]${filter},volume=0.60[n];[1:a]volume=0.10[s];[n][s]amix=inputs=2:normalize=0,afade=t=in:st=0:d=0.08,afade=t=out:st=11.92:d=0.08[a]" \
    -map "[a]" -ac 1 -c:a libvorbis -q:a 2 "$OUTPUT_DIR/$filename"
}

make_noise "region_01_cote.ogg" pink 0.30 "highpass=f=70,lowpass=f=1800,volume=0.48"
make_noise "region_02_foret.ogg" brown 0.23 "highpass=f=180,lowpass=f=5200,tremolo=f=0.18:d=0.35,volume=0.52"
make_noise "region_03_montagnes.ogg" pink 0.25 "highpass=f=260,lowpass=f=2600,tremolo=f=0.11:d=0.52,volume=0.48"
make_noise "region_04_plaines.ogg" pink 0.18 "highpass=f=420,lowpass=f=6400,tremolo=f=0.24:d=0.24,volume=0.42"
make_drone "region_05_volcan.ogg" brown 48 "lowpass=f=650"
make_drone "region_06_marais.ogg" brown 72 "lowpass=f=1300,tremolo=f=0.33:d=0.42"
make_noise "region_07_cendres.ogg" pink 0.30 "highpass=f=300,lowpass=f=2200,tremolo=f=0.10:d=0.68,volume=0.52"
make_noise "region_08_port.ogg" pink 0.25 "highpass=f=120,lowpass=f=3200,tremolo=f=0.42:d=0.22,volume=0.46"
make_drone "region_09_ruines.ogg" pink 96 "highpass=f=60,lowpass=f=950"
make_noise "region_10_neige.ogg" white 0.16 "highpass=f=700,lowpass=f=4700,tremolo=f=0.12:d=0.74,volume=0.42"

make_noise "meteo_pluie.ogg" white 0.28 "highpass=f=900,lowpass=f=9000,volume=0.48"
make_noise "meteo_vent.ogg" pink 0.28 "highpass=f=260,lowpass=f=3300,tremolo=f=0.10:d=0.72,volume=0.52"
make_noise "meteo_neige.ogg" white 0.17 "highpass=f=620,lowpass=f=3600,tremolo=f=0.10:d=0.76,volume=0.40"
make_noise "meteo_cendres.ogg" brown 0.30 "highpass=f=95,lowpass=f=1650,tremolo=f=0.12:d=0.68,volume=0.52"
make_drone "sous_marin.ogg" brown 56 "lowpass=f=520"

printf 'Ambiances générées dans %s\n' "$OUTPUT_DIR"
