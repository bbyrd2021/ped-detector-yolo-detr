#!/bin/bash
# =============================================
# Caltech Pedestrian Dataset Conversion Script
# =============================================

START_TIME=$(date)
DATE_TAG=$(date +"%Y%m%d_%H%M%S")

PROJECT_DIR="/Users/brandonbyrd/Documents/Big Data/Big Data Project"
REPO_DIR="$PROJECT_DIR/tools/caltech-ped-converter"
DATA_ROOT="$PROJECT_DIR/data/caltechpedestriandataset"
OUT_DIR="$PROJECT_DIR/derived/caltech_yolo"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/convert_caltech_${DATE_TAG}.log"

mkdir -p "$LOG_DIR"
mkdir -p "$OUT_DIR"

echo "=============================================" | tee "$LOG_FILE"
echo " Caltech Pedestrian Dataset Conversion Script" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"
echo "Started: $START_TIME" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "---------------------------------------------" | tee -a "$LOG_FILE"

# --- Environment info ---
echo "Conda env: $(conda info --envs | grep '*' | awk '{print $1}')" | tee -a "$LOG_FILE"
echo "Python: $(python --version)" | tee -a "$LOG_FILE"

# --- Clone or update converter repo ---
if [ ! -d "$REPO_DIR" ]; then
  echo ">>> Cloning converter repo..." | tee -a "$LOG_FILE"
  git clone https://github.com/mitmul/caltech-pedestrian-dataset-converter.git "$REPO_DIR" >> "$LOG_FILE" 2>&1
else
  echo ">>> Repo exists: $REPO_DIR" | tee -a "$LOG_FILE"
fi

cd "$REPO_DIR"
echo "Using commit: $(git rev-parse HEAD)" | tee -a "$LOG_FILE"

# --- Install dependencies ---
echo ">>> Installing dependencies..." | tee -a "$LOG_FILE"
pip install opencv-python numpy scipy >> "$LOG_FILE" 2>&1

# --- Rebuild data layout ---
echo ">>> Preparing data links..." | tee -a "$LOG_FILE"
rm -rf data
mkdir -p data/seqs

# Detect nested structure (setXX/setXX/V000.seq)
FOUND_NESTED=false
for d in "$DATA_ROOT"/Train/set*/set*; do
  if [ -d "$d" ]; then
    FOUND_NESTED=true
    break
  fi
done

if [ "$FOUND_NESTED" = true ]; then
  echo "Nested folder structure detected — linking inner set folders" | tee -a "$LOG_FILE"
  for inner in "$DATA_ROOT"/Train/set*/set* "$DATA_ROOT"/Test/set*/set*; do
    [ -d "$inner" ] || continue
    name=$(basename "$(dirname "$inner")")   # e.g. set00
    ln -sf "$inner" "data/seqs/$name"
  done
else
  echo "Standard structure detected — linking top-level set folders" | tee -a "$LOG_FILE"
  for d in "$DATA_ROOT"/Train/set* "$DATA_ROOT"/Test/set*; do
    [ -d "$d" ] || continue
    ln -sf "$d" "data/seqs/$(basename "$d")"
  done
fi

echo "Linked sets:" | tee -a "$LOG_FILE"
ls -l data/seqs | tee -a "$LOG_FILE"

# --- Run conversion ---
echo ">>> Running sequence conversion..." | tee -a "$LOG_FILE"
python scripts/convert_seqs.py >> "$LOG_FILE" 2>&1

echo ">>> Running annotation conversion..." | tee -a "$LOG_FILE"
python scripts/convert_annotations.py >> "$LOG_FILE" 2>&1

# --- Move converted output to derived directory ---
echo ">>> Moving converted output to $OUT_DIR ..." | tee -a "$LOG_FILE"
mkdir -p "$OUT_DIR/images" "$OUT_DIR/labels"
mv data/images/* "$OUT_DIR/images/" 2>/dev/null || true
mv data/annotations/* "$OUT_DIR/labels/" 2>/dev/null || true

# --- Cleanup ---
echo ">>> Cleaning temporary data directory..." | tee -a "$LOG_FILE"
rm -rf data

END_TIME=$(date)
echo "---------------------------------------------" | tee -a "$LOG_FILE"
echo "Finished: $END_TIME" | tee -a "$LOG_FILE"
echo "Converted data saved to: $OUT_DIR" | tee -a "$LOG_FILE"
echo "Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"



