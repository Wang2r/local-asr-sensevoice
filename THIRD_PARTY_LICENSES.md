# Third-party licenses and attributions

This repository contains project-specific code and documentation, but it also
builds on or works with third-party software and model artifacts.

The top-level `LICENSE` applies only to original material that belongs to this
repository. It does **not** replace or relicense third-party software or model
weights.

## 1. FunASR

Source:

- https://github.com/modelscope/FunASR
- Pinned source commit:
  `904cd18681b8083de5e1039bd0ecebc4f49ede60`

FunASR's toolkit source code is licensed under the MIT License.

This project does not vendor the FunASR checkout in Git. The build script
retrieves the pinned source into `src/FunASR/` and applies the patch in
`patches/001-sensevoice-batch.patch`.

See the upstream license:

- https://github.com/modelscope/FunASR/blob/main/LICENSE

## 2. llama.cpp / ggml

The FunASR runtime used by this project is based on the llama.cpp/ggml
code included by the pinned FunASR source tree.

llama.cpp is licensed under the MIT License. Its repository also contains
additional third-party components with their own notices; this project does
not redistribute the full llama.cpp source tree.

Source:

- https://github.com/ggml-org/llama.cpp

License:

- https://github.com/ggml-org/llama.cpp/blob/master/LICENSE

## 3. SenseVoiceSmall GGUF model

Model repository:

- https://huggingface.co/FunAudioLLM/SenseVoiceSmall-GGUF

Model file used by this project:

- `sensevoice-small-q8.gguf`

The model repository currently declares the Apache License 2.0.

The model is **not included in this Git repository**. Users download it
separately into `models/`.

Keep the model's original attribution and license information when using or
redistributing the model.

## 4. FSMN-VAD GGUF model

Model repository:

- https://huggingface.co/FunAudioLLM/fsmn-vad-GGUF

Model file used by this project:

- `fsmn-vad.gguf`

The model repository currently declares the Apache License 2.0.

The model is **not included in this Git repository**. Users download it
separately into `models/`.

Keep the model's original attribution and license information when using or
redistributing the model.

## 5. FFmpeg

FFmpeg is an external runtime dependency. The batch executable invokes the
user-installed `ffmpeg` command to decode audio; this repository does not
bundle FFmpeg binaries.

FFmpeg states that most of its files are licensed under the GNU Lesser General
Public License version 2.1 or later (LGPL v2.1+). Some optional components are
under GPL v2 or later when enabled.

Source and license information:

- https://ffmpeg.org/
- https://ffmpeg.org/doxygen/trunk/md_LICENSE.html

The licensing status of a particular installed FFmpeg build depends on how
that build was configured. Check the license information for the FFmpeg
binary you distribute or deploy.

## 6. Scope

This file is a practical attribution and dependency map, not a replacement
for the original license texts.

Before redistributing model files or a packaged application, review the exact
license and attribution requirements of the versions you are shipping.
