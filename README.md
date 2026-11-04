# Toondio voice engine

A small command-line program that speaks text with the Kokoro voices, for
Toondio. Toondio downloads it (with the voices) when someone turns on
real voices, starts it as a separate process, and talks to it over
stdin/stdout. Toondio itself contains none of the code below.

License: **GPL-3.0-or-later** (see `LICENSE`), because the speech engine it
uses, sherpa-onnx, is built with eSpeak NG (GPL-3.0-or-later) for
pronunciation.

## What is inside the release zip

| File | What it is | License |
|---|---|---|
| `toondio-voice.exe` | This program (`bin/toondio_voice.dart`, compiled with `dart compile exe`) | GPL-3.0-or-later |
| `sherpa-onnx-c-api.dll` | sherpa-onnx 1.13.8 speech engine, with eSpeak NG and piper-phonemize built in | Apache-2.0 (sherpa-onnx), GPL-3.0-or-later (eSpeak NG), MIT (piper-phonemize) |
| `onnxruntime.dll`, `onnxruntime_providers_shared.dll` | ONNX Runtime, runs the voice model | MIT |
| `LICENSE`, `LICENSE-sherpa-onnx.txt`, `THIRD-PARTY-NOTICES.txt`, `README.md` | Licenses and this file | |

The DLLs are the ones published in the `sherpa_onnx_windows` 1.13.8 package on
pub.dev, unchanged. `third_party/sherpa_onnx_dart` is the Dart FFI binding of
sherpa-onnx 1.13.8 (Apache-2.0), trimmed as described in its `CHANGES.md`.

The voices themselves (Kokoro-82M, Apache-2.0) are not in this zip; Toondio
downloads them from the sherpa-onnx releases and checks their SHA-256.

## Corresponding source

Each release of this engine carries, as release assets, the exact source of
everything compiled into it:

| Archive | What it is | SHA-256 |
|---|---|---|
| this repository at the release tag | the engine program | (GitHub's source archives) |
| `sherpa-onnx-1.13.8-source.zip` | sherpa-onnx at tag v1.13.8 (github.com/k2-fsa/sherpa-onnx) | see the release |
| `espeak-ng-ed530aa113046142eb5115cf2fc9157854d0ffe1.zip` | the eSpeak NG source sherpa-onnx 1.13.8 builds (named in its `cmake/espeak-ng-for-piper.cmake`) | `e4e262cbe34f7fe21f91f1ba3397f2728e1f30eafbae7853f2b753a9ed13f0dd` |
| `piper-phonemize-f3ff95afc03640bc1399e113e83361192a2fafb4.zip` | the piper-phonemize source it builds (named in `cmake/piper-phonemize.cmake`) | `d9cca4e2bdc7d6dd8dffb96a4668283dbd3f77a9c194a3e530c1e8eba9406a5d` |

The two hashes are the ones sherpa-onnx's build files pin for these archives.

## Build (Windows)

```
dart pub get
powershell -File build.ps1
```

This writes `build/toondio-voice-engine-<version>-win-x64.zip` and prints its
SHA-256. Toondio checks downloads against that hash (`desktop/lib/tts.dart`)
and records it in the installed engine folder (`release.sha256`), so update it
there for a new release; installed engines are then replaced.

## Protocol

```
toondio-voice.exe --model <voice pack folder> --out-dir <existing folder> [--threads N]
```

It prints `{"ready":true,"sampleRate":24000,"version":"1.0.0"}` (or
`{"error":"…"}`), then reads one JSON request per line:

```
{"text":"Hello","sid":3,"speed":1.0,"out":"<out-dir>\\line-1.wav"}
```

writes a 16-bit mono WAV to `out` and answers `{"ok":true}` or
`{"error":"…"}`. Every request is checked: text of at most 10000 characters,
`sid` a speaker of the pack, `speed` 0.5 – 2, and `out` a `.wav` file directly
inside `--out-dir`. It exits when stdin closes.
