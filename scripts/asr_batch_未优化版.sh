#!/bin/zsh

setopt null_glob
setopt NO_CASE_GLOB

ROOT="/Users/zhang3r/QArticles/0141_本地语音转文字/local-asr-sensevoice"

BIN="$ROOT/bin/llama-funasr-sensevoice"
MODEL="$ROOT/models/sensevoice-small-q8.gguf"
VAD="$ROOT/models/fsmn-vad.gguf"

AUDIO="$ROOT/audio"
OUTPUT="$ROOT/output"
LOG="$OUTPUT/asr_batch.log"

INPUT_DIR="${1:-.}"

mkdir -p "$AUDIO" "$OUTPUT"

# ---------- 检查 ----------
if [[ ! -x "$BIN" ]]; then
    echo "错误：找不到 SenseVoice：$BIN"
    exit 1
fi

if [[ ! -f "$MODEL" ]]; then
    echo "错误：找不到 SenseVoice 模型：$MODEL"
    exit 1
fi

if [[ ! -f "$VAD" ]]; then
    echo "错误：找不到 FSMN-VAD：$VAD"
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "错误：找不到 ffmpeg"
    exit 1
fi

# ---------- 找到所有 MP4 ----------
files=( "$INPUT_DIR"/*.mp4 )
total_files=${#files[@]}

echo
echo "========================================"
echo " 本地中文 ASR 批处理"
echo "========================================"
echo "输入目录：$INPUT_DIR"
echo "文件数量：$total_files"
echo "输出目录：$OUTPUT"
echo "日志：    $LOG"
echo

# 每次运行重新开始一份日志
{
    echo "========================================"
    echo "ASR 批处理日志"
    echo "开始时间：$(date)"
    echo "输入目录：$INPUT_DIR"
    echo "文件数量：$total_files"
    echo "========================================"
    echo
} > "$LOG"

success=0
skip=0
failed=0
current=0

for file in "${files[@]}"; do

    current=$((current + 1))

    name="${file:t:r}"
    wav="$AUDIO/${name}.wav"
    txt="$OUTPUT/${name}.txt"
    srt="$OUTPUT/${name}.srt"

    echo "[$current/$total_files] $name.mp4"

    # ---------- 已完成则跳过 ----------
    if [[ -f "$txt" && -f "$srt" ]]; then
        echo "    → 已存在，跳过"
        skip=$((skip + 1))
        echo
        continue
    fi

    # ---------- MP4 → 16 kHz / Mono / PCM WAV ----------
    echo "    → 提取音频"

    if ! ffmpeg -hide_banner -loglevel error \
        -y \
        -i "$file" \
        -map 0:a:0 \
        -ac 1 \
        -ar 16000 \
        -c:a pcm_s16le \
        "$wav"
    then
        echo "    ✗ 音频提取失败"

        {
            echo "[$current/$total_files] $name.mp4"
            echo "FFmpeg 提取失败"
            echo
        } >> "$LOG"

        rm -f "$wav"
        failed=$((failed + 1))
        echo
        continue
    fi

    # ---------- SenseVoice → SRT ----------
    echo "    → SenseVoice 转写"

    if ! "$BIN" \
        -m "$MODEL" \
        --vad "$VAD" \
        -a "$wav" \
        --srt \
        > "$srt" \
        2>> "$LOG"
    then
        echo "    ✗ SenseVoice 转写失败"

        {
            echo "[$current/$total_files] $name.mp4"
            echo "SenseVoice 转写失败"
            echo
        } >> "$LOG"

        rm -f "$wav" "$srt"
        failed=$((failed + 1))
        echo
        continue
    fi

    # ---------- SRT → TXT ----------
    awk '
    /^[[:space:]]*[0-9]+[[:space:]]*$/ {
        next
    }

    /^[[:space:]]*[0-9][0-9]:[0-9][0-9]:[0-9][0-9],[0-9][0-9][0-9][[:space:]]+-->/ {
        next
    }

    /^[[:space:]]*$/ {
        next
    }

    {
        print
    }
    ' "$srt" > "$txt"

    # ---------- 删除临时 WAV ----------
    rm -f "$wav"

    echo "    ✓ 完成"
    success=$((success + 1))

    echo
done

echo "========================================"
echo "处理完成"
echo "========================================"
echo "文件总数：$total_files"
echo "成功：    $success"
echo "跳过：    $skip"
echo "失败：    $failed"
echo "日志：    $LOG"
echo "========================================"
