#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT_DIR/bin/llama-funasr-sensevoice-batch"
DEFAULT_MODEL="$ROOT_DIR/models/sensevoice-small-q8.gguf"
DEFAULT_VAD="$ROOT_DIR/models/fsmn-vad.gguf"

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-$INPUT_DIR}"
THREADS="${3:-6}"
MODEL="${SENSEVOICE_MODEL:-$DEFAULT_MODEL}"
VAD_MODEL="${FSMN_VAD_MODEL:-$DEFAULT_VAD}"
LOG="${ASR_LOG:-$OUTPUT_DIR/asr_batch.log}"

say() { printf '[asr] %s\n' "$*"; }
die() { printf '[asr] ERROR: %s\n' "$*" >&2; exit 1; }

[ -d "$INPUT_DIR" ] || die "input directory not found: $INPUT_DIR"
mkdir -p "$OUTPUT_DIR"

[ -x "$BIN" ] || die "batch binary not found: $BIN — run scripts/bootstrap.sh first"
[ -f "$MODEL" ] || die "SenseVoice model not found: $MODEL"
[ -f "$VAD_MODEL" ] || die "FSMN-VAD model not found: $VAD_MODEL"

case "$THREADS" in
    ''|*[!0-9]*) die "threads must be a positive integer: $THREADS" ;;
    0) die "threads must be >= 1" ;;
esac

MANIFEST="$(mktemp "${TMPDIR:-/tmp}/sensevoice-batch.XXXXXX")"
trap 'rm -f "$MANIFEST"' EXIT INT TERM

JOBS=0
SKIPPED=0

# The C++ batch runtime expects: input_audio<TAB>output_srt
while IFS= read -r -d '' INPUT_FILE; do
    NAME="$(basename "$INPUT_FILE")"
    BASE="${NAME%.*}"
    SRT_FILE="$OUTPUT_DIR/$BASE.srt"
    TXT_FILE="$OUTPUT_DIR/$BASE.txt"

    if [ -f "$SRT_FILE" ] && [ -f "$TXT_FILE" ]; then
        SKIPPED=$((SKIPPED + 1))
        say "skip: $NAME"
        continue
    fi

    printf '%s\t%s\n' "$INPUT_FILE" "$SRT_FILE" >> "$MANIFEST"
    JOBS=$((JOBS + 1))
done < <(find "$INPUT_DIR" -maxdepth 1 -type f -iname '*.mp4' -print0)

if [ "$JOBS" -eq 0 ]; then
    say "nothing to process; skipped=$SKIPPED"
    exit 0
fi

say "input:  $INPUT_DIR"
say "output: $OUTPUT_DIR"
say "jobs:   $JOBS"
say "skip:   $SKIPPED"
say "threads: $THREADS"
say "log:    $LOG"

# Keep the screen clean: batch progress goes to stdout; detailed runtime logs go to LOG.
set +e
"$BIN" \
  -m "$MODEL" \
  --vad "$VAD_MODEL" \
  --threads "$THREADS" \
  --srt \
  --batch-list "$MANIFEST" \
  2>> "$LOG"
BATCH_RC=$?
set -e

SUCCESS=0
FAILED=0

# Convert every expected SRT to plain text. Write via a temporary file so an interrupted
# awk invocation does not leave a misleadingly complete-looking .txt file behind.
while IFS=$'\t' read -r INPUT_FILE SRT_FILE; do
    [ -n "$SRT_FILE" ] || continue
    NAME="$(basename "$INPUT_FILE")"
    BASE="${NAME%.*}"
    TXT_FILE="$OUTPUT_DIR/$BASE.txt"

    if [ -f "$SRT_FILE" ]; then
        TMP_TXT="${TXT_FILE}.tmp"
        LC_ALL=C awk '
            /^[[:space:]]*[0-9]+[[:space:]]*$/ { next }
            /-->[[:space:]]/ { next }
            /^[[:space:]]*$/ { next }
            {
                gsub(/<[^>]*>/, "")
                print
            }
        ' "$SRT_FILE" > "$TMP_TXT"
        mv "$TMP_TXT" "$TXT_FILE"
    fi

    if [ -f "$SRT_FILE" ] && [ -f "$TXT_FILE" ]; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAILED=$((FAILED + 1))
        printf '[asr] failed: %s\n' "$INPUT_FILE" >> "$LOG"
    fi
done < "$MANIFEST"

say "finished: success=$SUCCESS failed=$FAILED skipped=$SKIPPED"
say "details:  $LOG"

if [ "$BATCH_RC" -ne 0 ] || [ "$FAILED" -ne 0 ]; then
    exit 1
fi
