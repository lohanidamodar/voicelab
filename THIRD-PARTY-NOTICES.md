# Third-party notices

VoiceLab is MIT (see `LICENSE`). A Windows release redistributes the libraries
below, whose licences require their notices to travel with them.

## Shipped in the download

| component | licence | copyright |
|---|---|---|
| [audio.cpp](https://github.com/0xShug0/audio.cpp) (`audiocpp_c.dll` and its ggml libraries) | [Apache-2.0](https://github.com/0xShug0/audio.cpp/blob/main/LICENSE) | ShugoAI LLC |
| [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) (`sherpa-onnx-c-api.dll`) | [Apache-2.0](https://github.com/k2-fsa/sherpa-onnx/blob/master/LICENSE) | Xiaomi Corporation and the k2-fsa authors |
| [ONNX Runtime](https://github.com/microsoft/onnxruntime) (`onnxruntime.dll`) | [MIT](https://github.com/microsoft/onnxruntime/blob/main/LICENSE) | Microsoft Corporation |
| [Flutter](https://flutter.dev) engine and framework | [BSD-3-Clause](https://github.com/flutter/flutter/blob/master/LICENSE) | the Flutter authors |

## Not shipped: the speech models

**No model weights are included in any download.** VoiceLab fetches the model
you choose from its publisher, and shows the licence before it does.

Their terms are the publishers', not this project's, and they are not all open
source. If you redistribute a build with weights included, these obligations
become yours:

| model | does | licence | what it asks |
|---|---|---|---|
| [OmniVoice](https://github.com/k2-fsa/OmniVoice) | speaks | Apache-2.0 | the notice |
| [VoxCPM2](https://huggingface.co/openbmb/VoxCPM2) | speaks | Apache-2.0 | the notice |
| [Parakeet TDT 0.6b v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) | recognises | [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/) | credit NVIDIA |
| [SenseVoice Small](https://huggingface.co/FunAudioLLM/SenseVoiceSmall) | recognises | [FunASR Model Open Source License Agreement v1.1](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE) | Alibaba's own terms — **not an OSI-approved licence** |
| [Silero VAD](https://github.com/snakers4/silero-vad) | finds speech | MIT | the notice |

The GGUF and ONNX files are conversions. A conversion repository does not
necessarily carry the model's licence, so the upstream terms above are the ones
that apply — which is what the catalogue in `voice_models` records.
