import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

class RecordedPttAudio {
  const RecordedPttAudio({
    required this.bytes,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String mimeType;
}

class PttAudioRecorder {
  PttAudioRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  static const int _sampleRate = 16000;
  static const int _numChannels = 1;
  static const int _bitsPerSample = 16;
  static const String mimeType = 'audio/wav';

  final AudioRecorder _recorder;
  final List<int> _bytes = [];
  int _effectiveSampleRate = _sampleRate;
  int _effectiveNumChannels = _numChannels;
  StreamSubscription<Uint8List>? _subscription;
  Completer<void>? _doneCompleter;
  bool _isRecording = false;

  Future<void> start() async {
    if (_isRecording) return;
    _bytes.clear();
    _effectiveSampleRate = _sampleRate;
    _effectiveNumChannels = _numChannels;

    await _recorder.setOnConfigChanged((config) {
      _effectiveSampleRate = config.sampleRate;
      _effectiveNumChannels = config.numChannels;
    });

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: _numChannels,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    _doneCompleter = Completer<void>();
    _subscription = stream.listen(
      _bytes.addAll,
      onDone: () {
        if (_doneCompleter?.isCompleted == false) {
          _doneCompleter?.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_doneCompleter?.isCompleted == false) {
          _doneCompleter?.completeError(error, stackTrace);
        }
      },
    );
    _isRecording = true;
  }

  Future<RecordedPttAudio?> stop() async {
    if (!_isRecording) return null;

    _isRecording = false;
    await _recorder.stop();
    try {
      await _doneCompleter?.future.timeout(const Duration(seconds: 2));
    } catch (_) {
      // Keep the PTT flow responsive even if a platform does not close the
      // stream promptly after stop.
    }
    await _subscription?.cancel();
    _subscription = null;
    _doneCompleter = null;

    if (_bytes.isEmpty) return null;
    return RecordedPttAudio(
      bytes: _wavBytes(
        Uint8List.fromList(_bytes),
        sampleRate: _effectiveSampleRate,
        numChannels: _effectiveNumChannels,
      ),
      mimeType: mimeType,
    );
  }

  Future<void> dispose() async {
    await _recorder.setOnConfigChanged(null);
    await _subscription?.cancel();
    await _recorder.dispose();
  }
}

Uint8List _wavBytes(
  Uint8List pcmBytes, {
  required int sampleRate,
  required int numChannels,
}) {
  final dataLength = pcmBytes.length;
  final fileLength = 36 + dataLength;
  final byteRate =
      sampleRate * numChannels * PttAudioRecorder._bitsPerSample ~/ 8;
  final blockAlign = numChannels * PttAudioRecorder._bitsPerSample ~/ 8;

  final bytes = BytesBuilder(copy: false)
    ..add(_ascii('RIFF'))
    ..add(_uint32(fileLength))
    ..add(_ascii('WAVE'))
    ..add(_ascii('fmt '))
    ..add(_uint32(16))
    ..add(_uint16(1))
    ..add(_uint16(numChannels))
    ..add(_uint32(sampleRate))
    ..add(_uint32(byteRate))
    ..add(_uint16(blockAlign))
    ..add(_uint16(PttAudioRecorder._bitsPerSample))
    ..add(_ascii('data'))
    ..add(_uint32(dataLength))
    ..add(pcmBytes);

  return bytes.toBytes();
}

Uint8List _ascii(String value) {
  return Uint8List.fromList(value.codeUnits);
}

Uint8List _uint16(int value) {
  final bytes = ByteData(2)..setUint16(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _uint32(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}
