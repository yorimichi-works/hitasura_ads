import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final output = Directory('assets/audio')..createSync(recursive: true);
  _writeWave(
    File('${output.path}/ui_click.wav'),
    seconds: .09,
    sample: (time, progress) =>
        sin(2 * pi * (1100 - progress * 450) * time) * (1 - progress),
  );
  _writeWave(
    File('${output.path}/secret_se.wav'),
    seconds: .75,
    sample: (time, progress) {
      final step = min(2, (progress * 3).floor());
      final frequency = [440.0, 659.25, 880.0][step];
      return sin(2 * pi * frequency * time) * sin(pi * progress);
    },
  );
  _writeWave(
    File('${output.path}/secret_bgm.wav'),
    seconds: 3,
    sample: (time, progress) {
      final chord =
          sin(2 * pi * 110 * time) +
          .55 * sin(2 * pi * 164.81 * time) +
          .35 * sin(2 * pi * 220 * time);
      final loopEnvelope = .55 + .45 * sin(pi * progress);
      return chord / 1.9 * loopEnvelope;
    },
  );
}

void _writeWave(
  File file, {
  required double seconds,
  required double Function(double time, double progress) sample,
}) {
  const sampleRate = 44100;
  const channels = 1;
  const bitsPerSample = 16;
  final sampleCount = (sampleRate * seconds).round();
  final dataSize = sampleCount * channels * bitsPerSample ~/ 8;
  final bytes = ByteData(44 + dataSize);
  var offset = 0;

  void ascii(String value) {
    for (final codeUnit in value.codeUnits) {
      bytes.setUint8(offset++, codeUnit);
    }
  }

  ascii('RIFF');
  bytes.setUint32(offset, 36 + dataSize, Endian.little);
  offset += 4;
  ascii('WAVEfmt ');
  bytes.setUint32(offset, 16, Endian.little);
  offset += 4;
  bytes.setUint16(offset, 1, Endian.little);
  offset += 2;
  bytes.setUint16(offset, channels, Endian.little);
  offset += 2;
  bytes.setUint32(offset, sampleRate, Endian.little);
  offset += 4;
  bytes.setUint32(
    offset,
    sampleRate * channels * bitsPerSample ~/ 8,
    Endian.little,
  );
  offset += 4;
  bytes.setUint16(offset, channels * bitsPerSample ~/ 8, Endian.little);
  offset += 2;
  bytes.setUint16(offset, bitsPerSample, Endian.little);
  offset += 2;
  ascii('data');
  bytes.setUint32(offset, dataSize, Endian.little);
  offset += 4;

  for (var index = 0; index < sampleCount; index++) {
    final progress = index / sampleCount;
    final value = sample(index / sampleRate, progress).clamp(-1.0, 1.0);
    bytes.setInt16(offset, (value * 11500).round(), Endian.little);
    offset += 2;
  }
  file.writeAsBytesSync(bytes.buffer.asUint8List());
}
