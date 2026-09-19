# local-asr-sensevoice

A small local Chinese speech-to-text project for Intel Mac, built around FunASR SenseVoiceSmall GGUF and the llama.cpp-based runtime.

The project keeps the upstream FunASR source separate from the project itself. A pinned upstream commit is restored into `src/FunASR/`, then `patches/001-sensevoice-batch.patch` adds the batch runtime used by this project.

## Design

- SenseVoiceSmall GGUF is loaded once per batch process instead of once per audio file.
- MP4 input is decoded directly through FFmpeg into a 16 kHz mono float32 PCM pipe; no temporary WAV is required by the batch runtime.
- The wrapper defaults to 6 inference threads for the user's Intel 6-core Mac, while the C++ runtime also accepts `--threads N`.
- Existing files are resumable: a video is skipped only when both its `.srt` and `.txt` outputs already exist.
- Human-facing batch progress goes to stdout. Detailed runtime diagnostics go to `asr_batch.log`.

The current batch runtime still initializes the small FSMN-VAD model for each file. SenseVoice itself is kept resident across the whole batch. VAD reuse can be optimized later without changing the project layout.

## Layout

```text
local-asr-sensevoice/
├── patches/
│   ├── 001-upstream-commit.txt
│   └── 001-sensevoice-batch.patch
├── scripts/
│   ├── bootstrap.sh
│   └── asr_batch.sh
├── src/
│   └── FunASR/          # local upstream checkout; ignored by Git
├── bin/                 # local build output; ignored by Git
├── models/              # local GGUF models; ignored by Git
├── audio/               # optional local audio; ignored by Git
├── output/              # optional local output; ignored by Git
├── .gitignore
└── README.md
```

## Requirements

This project is currently targeted at Intel macOS (`x86_64`). It expects:

- Xcode Command Line Tools (`clang`, `clang++`, `xcrun`)
- Git
- CMake
- FFmpeg

With Homebrew:

```bash
brew install git cmake ffmpeg
```

The build uses Apple's libc++ headers from the active macOS SDK. The CMake invocation intentionally unsets `CPPFLAGS`, `CXXFLAGS`, and `SDKROOT` to avoid unrelated global compiler settings interfering with the build.

## First build

From the project root:

```bash
./scripts/bootstrap.sh
```

The script will:

1. clone FunASR into `src/FunASR` when needed;
2. require the exact commit recorded in `patches/001-upstream-commit.txt`;
3. apply `patches/001-sensevoice-batch.patch`;
4. configure llama.cpp with the Intel macOS toolchain;
5. build `llama-funasr-sensevoice-batch` with 6 build jobs by default;
6. copy the resulting binary to `bin/`.

To change build parallelism:

```bash
BUILD_JOBS=4 ./scripts/bootstrap.sh
```

Build parallelism is separate from ASR inference threads.

## Models

Place these two files under `models/`:

```text
models/sensevoice-small-q8.gguf
models/fsmn-vad.gguf
```

The project does not store model files in Git.

## Batch transcription

The simplest command processes all MP4 files in a directory and writes `.srt` and `.txt` next to the source files:

```bash
./scripts/asr_batch.sh /path/to/mp4
```

You can choose a separate output directory:

```bash
./scripts/asr_batch.sh /path/to/mp4 /path/to/output
```

The third argument controls inference threads; the default is 6:

```bash
./scripts/asr_batch.sh /path/to/mp4 /path/to/output 6
```

The script also accepts model and log locations through environment variables:

```bash
SENSEVOICE_MODEL=/path/to/sensevoice-small-q8.gguf \
FSMN_VAD_MODEL=/path/to/fsmn-vad.gguf \
ASR_LOG=/path/to/asr_batch.log \
./scripts/asr_batch.sh /path/to/mp4
```

## Outputs

For:

```text
example.mp4
```

the default output is:

```text
example.srt
example.txt
```

The `.txt` file is derived from the `.srt` after the batch runtime finishes.

The detailed log is:

```text
asr_batch.log
```

The wrapper does not create intermediate WAV files.

## Reproducibility model

The important reproducibility pair is:

```text
FunASR commit 904cd18681b8083de5e1039bd0ecebc4f49ede60
        +
patches/001-sensevoice-batch.patch
```

The patch is intentionally kept outside the upstream repository. This makes upstream updates explicit: changing the pinned commit is a deliberate maintenance step, and the existing patch should be checked against the new upstream version before adopting it.

## Notes on Git

The local upstream checkout, build products, models, audio, and generated transcripts are ignored. Only the project logic, patch, and documentation belong in the project's own Git repository.
