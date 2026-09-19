#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNASR_DIR="$ROOT_DIR/src/FunASR"
LLAMA_DIR="$FUNASR_DIR/runtime/llama.cpp"
BUILD_DIR="$LLAMA_DIR/build"
BIN_DIR="$ROOT_DIR/bin"
PATCH_FILE="$ROOT_DIR/patches/001-sensevoice-batch.patch"
COMMIT_FILE="$ROOT_DIR/patches/001-upstream-commit.txt"
TARGET_BIN="$BIN_DIR/llama-funasr-sensevoice-batch"

BUILD_JOBS="${BUILD_JOBS:-6}"
FUNASR_REPO="${FUNASR_REPO:-https://github.com/modelscope/FunASR.git}"

say() { printf '[bootstrap] %s\n' "$*"; }
die() { printf '[bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git not found"
command -v cmake >/dev/null 2>&1 || die "cmake not found"
command -v xcrun >/dev/null 2>&1 || die "xcrun not found (this script is for macOS)"
command -v clang >/dev/null 2>&1 || die "clang not found"
command -v clang++ >/dev/null 2>&1 || die "clang++ not found"
command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg not found; install it with: brew install ffmpeg"

[ "$(uname -s)" = "Darwin" ] || die "this project currently targets macOS"
[ "$(uname -m)" = "x86_64" ] || die "this build is currently targeted at Intel macOS (x86_64)"

[ -f "$PATCH_FILE" ] || die "missing patch: $PATCH_FILE"
[ -f "$COMMIT_FILE" ] || die "missing upstream commit file: $COMMIT_FILE"

UPSTREAM_COMMIT="$(tr -d '[:space:]' < "$COMMIT_FILE")"
[ "${#UPSTREAM_COMMIT}" -eq 40 ] || die "invalid upstream commit: $UPSTREAM_COMMIT"

mkdir -p "$ROOT_DIR/src" "$BIN_DIR"

if [ ! -d "$FUNASR_DIR/.git" ]; then
    [ ! -e "$FUNASR_DIR" ] || die "$FUNASR_DIR exists but is not a git clone"
    say "cloning FunASR"
    git clone "$FUNASR_REPO" "$FUNASR_DIR"
fi

CURRENT_COMMIT="$(git -C "$FUNASR_DIR" rev-parse HEAD)"
if [ "$CURRENT_COMMIT" != "$UPSTREAM_COMMIT" ]; then
    die "src/FunASR is at $CURRENT_COMMIT, expected $UPSTREAM_COMMIT. Refusing to modify an unexpected upstream checkout."
fi

# Apply our patch only once. The presence of both our CMake target and source file
# is used as the idempotence check because the upstream commit is fixed.
if grep -q 'llama-funasr-sensevoice-batch' "$LLAMA_DIR/CMakeLists.txt" 2>/dev/null \
   && [ -f "$LLAMA_DIR/sensevoice/funasr-sensevoice/funasr-sensevoice-batch.cpp" ]; then
    say "batch patch already applied"
else
    say "checking patch against FunASR $UPSTREAM_COMMIT"
    git -C "$FUNASR_DIR" apply --check "$PATCH_FILE"
    say "applying patch"
    git -C "$FUNASR_DIR" apply "$PATCH_FILE"
fi

SDK="$(xcrun --sdk macosx --show-sdk-path)"
[ -d "$SDK/usr/include/c++/v1" ] || die "libc++ headers not found under SDK: $SDK/usr/include/c++/v1"

say "configuring CMake"
env -u CPPFLAGS -u CXXFLAGS -u SDKROOT \
cmake -S "$LLAMA_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCMAKE_OSX_SYSROOT="$SDK" \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DCMAKE_CXX_FLAGS="-stdlib=libc++ -isystem $SDK/usr/include/c++/v1" \
  -DGGML_NATIVE=ON \
  -DLLAMA_CURL=OFF

say "building llama-funasr-sensevoice-batch with -j$BUILD_JOBS"
cmake --build "$BUILD_DIR" -j "$BUILD_JOBS" --target llama-funasr-sensevoice-batch

[ -x "$BUILD_DIR/bin/llama-funasr-sensevoice-batch" ] || die "build completed but binary was not found: $BUILD_DIR/bin/llama-funasr-sensevoice-batch"

cp "$BUILD_DIR/bin/llama-funasr-sensevoice-batch" "$TARGET_BIN"
chmod +x "$TARGET_BIN"

say "ready: $TARGET_BIN"
