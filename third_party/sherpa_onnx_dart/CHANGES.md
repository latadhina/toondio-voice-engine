# Vendored sherpa-onnx Dart bindings

Source: https://pub.dev/packages/sherpa_onnx 1.13.8 (Apache-2.0, see LICENSE),
https://github.com/k2-fsa/sherpa-onnx/tree/master/flutter/sherpa_onnx

Changes for the Toondio voice engine (a plain Dart command-line program, not a
Flutter app):

- Removed `lib/sherpa_onnx.dart` and `lib/src/web/`, which import the
  Flutter/web platform packages. The engine imports `lib/src/tts.dart` and
  `lib/src/init_native.dart` directly.
- This `pubspec.yaml` replaces the original, keeping only the `ffi` dependency.

No other file was changed.
