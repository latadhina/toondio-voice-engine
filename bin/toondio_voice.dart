// Toondio voice engine: speaks text with the Kokoro voices through sherpa-onnx
// (which uses eSpeak NG for pronunciation). It is a separate program on
// purpose: Toondio starts it, talks to it over stdin/stdout, and never
// loads these libraries itself.
//
// Copyright (C) 2026 Toondio
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.
//
// Usage:  toondio-voice.exe --model <voice pack folder> --out-dir <folder> [--threads N]
// Prints one JSON line: {"ready":true,"sampleRate":24000} or {"error":"…"}.
// Then reads one JSON request per line on stdin:
//   {"text":"Hello","sid":3,"speed":1.0,"out":"<out-dir>\\line-1.wav"}
// writes a 16-bit mono WAV to "out" and answers {"ok":true} or {"error":"…"}.
// The engine checks every request itself: text of at most 10000 characters,
// a speaker of the pack, speed 0.5 – 2, and "out" a .wav file directly inside
// --out-dir. It exits when stdin closes.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/src/init_native.dart';
import 'package:sherpa_onnx/src/tts.dart';

const version = '1.0.0';
const maxText = 10000;

void say(Map<String, Object?> m) => stdout.writeln(jsonEncode(m));

void main(List<String> args) {
  String? arg(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  if (args.contains('--version')) {
    stdout.writeln('toondio-voice $version');
    return;
  }
  final dir = arg('--model');
  final outArg = arg('--out-dir');
  if (dir == null || outArg == null || !Directory(outArg).existsSync()) {
    say({'error': 'usage: toondio-voice --model <voice pack folder> --out-dir <existing folder> [--threads N]'});
    exitCode = 2;
    return;
  }
  final threads = (int.tryParse(arg('--threads') ?? '') ?? 2).clamp(1, 8);
  final outDir = Directory(outArg).resolveSymbolicLinksSync();
  final here = File(Platform.resolvedExecutable).parent.path;

  final OfflineTts tts;
  try {
    // Windows ships an older onnxruntime.dll in System32 that would be found
    // first; load ours by full path so the engine binds to it.
    if (Platform.isWindows) DynamicLibrary.open('$here${Platform.pathSeparator}onnxruntime.dll');
    initNativeBindings(here);
    tts = OfflineTts(OfflineTtsConfig(
      model: OfflineTtsModelConfig(
        kokoro: OfflineTtsKokoroModelConfig(
          model: '$dir/model.onnx',
          voices: '$dir/voices.bin',
          tokens: '$dir/tokens.txt',
          dataDir: '$dir/espeak-ng-data',
          lexicon: '$dir/lexicon-us-en.txt,$dir/lexicon-zh.txt',
        ),
        numThreads: threads,
        debug: false,
      ),
      maxNumSenetences: 1,
    ));
  } catch (e) {
    say({'error': 'Could not load the voices: $e'});
    exitCode = 1;
    return;
  }
  say({'ready': true, 'sampleRate': tts.sampleRate, 'version': version});

  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;
    try {
      final req = jsonDecode(line);
      if (req is! Map) throw const FormatException('a request is a JSON object');
      final text = req['text'];
      final sid = req['sid'];
      final speed = req['speed'];
      final out = req['out'];
      if (text is! String || text.length > maxText) throw const FormatException('text must be at most $maxText characters');
      if (sid is! int || sid < 0 || sid >= tts.numSpeakers) throw const FormatException('unknown speaker');
      if (speed is! num || !speed.isFinite || speed < 0.5 || speed > 2) throw const FormatException('speed must be 0.5 to 2');
      if (out is! String || !isOutFile(out, outDir)) throw const FormatException('out must be a .wav file in --out-dir');
      final a = tts.generate(text: text, sid: sid, speed: speed.toDouble());
      File(out).writeAsBytesSync(wav16(a.samples, a.sampleRate), flush: true);
      say({'ok': true});
    } catch (e) {
      say({'error': 'Speech failed: $e'});
    }
  }, onDone: () {
    tts.free();
    exit(0);
  });
}

/// A .wav file name directly inside [dir] (the --out-dir, links resolved).
bool isOutFile(String path, String dir) {
  final f = File(path);
  final name = f.uri.pathSegments.isEmpty ? '' : f.uri.pathSegments.last;
  if (!RegExp(r'^[A-Za-z0-9_-][A-Za-z0-9_.-]{0,79}\.wav$').hasMatch(name)) return false;
  final parent = f.parent;
  if (!parent.existsSync()) return false;
  return parent.resolveSymbolicLinksSync().toLowerCase() == dir.toLowerCase();
}

Uint8List wav16(Float32List samples, int rate) {
  final n = samples.length;
  final b = ByteData(44 + n * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    b.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}
