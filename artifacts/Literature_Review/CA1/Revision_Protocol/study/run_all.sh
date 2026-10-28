#!/usr/bin/env bash
# Stop on any unexplained error/timeout; never renew a primary cell attempt.
set -euo pipefail
cd -- "$(dirname -- "$0")"
[[ -f Manifest.sha256 ]] || { echo 'Freeze the study first.' >&2; exit 2; }
for index in {0..5}; do
  bash run.sh sensitivity-python "$index"
  bash run.sh sensitivity-weighted "$index"
  bash run.sh sensitivity-neighbors "$index"
done
# Validate every new Python cache's detector behavior before any downstream experiment.
bash run.sh sensitivity-review 0
for repetition in {1..5}; do
  for condition in {0..3}; do
    languages=(python julia)
    ((repetition%2==0)) && languages=(julia python)
    for language in "${languages[@]}"; do
      bash run.sh "benchmark-$language" "$condition" "cold-$repetition"
    done
  done
done
for condition in {0..3}; do
  languages=(python julia)
  ((condition%2==1)) && languages=(julia python)
  for language in "${languages[@]}"; do
    bash run.sh "benchmark-$language" "$condition" warm
  done
done
for index in {0..11}; do
  bash run.sh primary "$index"
done
bash run.sh analyze 0
