import 'dart:convert';
import 'dart:typed_data';

class WavPcm16 {
  const WavPcm16({required this.sampleRate, required this.pcm});

  final int sampleRate;
  final Uint8List pcm;
}

WavPcm16 parseWavPcm16(Uint8List bytes) {
  return parseWavPcm16Bytes(bytes, source: 'Recorded audio');
}

WavPcm16 parseWavPcm16Bytes(Uint8List bytes, {required String source}) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 12 ||
      ascii.decode(bytes.sublist(0, 4)) != 'RIFF' ||
      ascii.decode(bytes.sublist(8, 12)) != 'WAVE') {
    throw StateError('$source must be a WAV file.');
  }

  int? audioFormat;
  int? channels;
  int? sampleRate;
  int? bitsPerSample;
  Uint8List? pcm;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = ascii.decode(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    final payloadStart = offset + 8;
    final payloadEnd = payloadStart + size;
    if (payloadEnd > bytes.length) {
      throw StateError('$source WAV chunk "$id" exceeds file length.');
    }
    if (id == 'fmt ') {
      if (size < 16) {
        throw StateError('$source WAV fmt chunk is too short.');
      }
      audioFormat = data.getUint16(payloadStart, Endian.little);
      channels = data.getUint16(payloadStart + 2, Endian.little);
      sampleRate = data.getUint32(payloadStart + 4, Endian.little);
      bitsPerSample = data.getUint16(payloadStart + 14, Endian.little);
    }
    if (id == 'data') {
      pcm = bytes.sublist(payloadStart, payloadEnd);
    }
    offset = payloadEnd + (size.isOdd ? 1 : 0);
  }

  if (audioFormat == null ||
      channels == null ||
      sampleRate == null ||
      bitsPerSample == null) {
    throw StateError('$source WAV fmt chunk not found.');
  }
  if (pcm == null) {
    throw StateError('$source WAV data chunk not found.');
  }
  if (audioFormat != 1 && audioFormat != 0xfffe) {
    throw StateError(
      '$source WAV format $audioFormat is not PCM16 '
      '(channels=$channels, sampleRate=$sampleRate, bits=$bitsPerSample).',
    );
  }
  if (bitsPerSample != 16) {
    throw StateError(
      '$source WAV must be PCM16 '
      '(channels=$channels, sampleRate=$sampleRate, bits=$bitsPerSample).',
    );
  }

  final frameSize = channels * 2;
  final alignedLength = pcm.length - (pcm.length % frameSize);
  final alignedPcm = alignedLength == pcm.length
      ? pcm
      : Uint8List.sublistView(pcm, 0, alignedLength);
  if (channels == 1) {
    return WavPcm16(sampleRate: sampleRate, pcm: alignedPcm);
  }
  if (channels == 2) {
    return WavPcm16(
      sampleRate: sampleRate,
      pcm: _downmixStereoPcm16(alignedPcm),
    );
  }
  throw StateError(
    '$source WAV has $channels channels; expected mono or stereo PCM16.',
  );
}

Uint8List _downmixStereoPcm16(Uint8List stereoPcm) {
  final input = ByteData.sublistView(stereoPcm);
  final output = Uint8List((stereoPcm.length ~/ 4) * 2);
  final outputData = ByteData.sublistView(output);
  for (var frame = 0; frame < output.length ~/ 2; frame += 1) {
    final stereoOffset = frame * 4;
    final left = input.getInt16(stereoOffset, Endian.little);
    final right = input.getInt16(stereoOffset + 2, Endian.little);
    outputData.setInt16(frame * 2, (left + right) ~/ 2, Endian.little);
  }
  return output;
}
