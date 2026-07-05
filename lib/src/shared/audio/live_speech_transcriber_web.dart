import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

class LiveSpeechTranscriber {
  web.SpeechRecognition? _recognition;
  web.EventListener? _resultListener;
  web.EventListener? _errorListener;
  web.EventListener? _endListener;
  Completer<void>? _endCompleter;
  final List<String> _finalSegments = [];
  String _interimText = '';
  bool _started = false;

  bool get isSupported =>
      globalContext.has('SpeechRecognition') ||
      globalContext.has('webkitSpeechRecognition');

  Future<void> start() async {
    if (!isSupported || _started) return;

    _finalSegments.clear();
    _interimText = '';
    _endCompleter = Completer<void>();

    final recognition = _createRecognition()
      ..lang = 'es-ES'
      ..continuous = true
      ..interimResults = true
      ..maxAlternatives = 1;

    _resultListener = ((web.Event event) {
      _handleResult(event as web.SpeechRecognitionEvent);
    }).toJS;
    _errorListener = ((web.Event _) {}).toJS;
    _endListener = ((web.Event _) {
      if (_endCompleter?.isCompleted == false) {
        _endCompleter?.complete();
      }
    }).toJS;

    recognition.addEventListener('result', _resultListener);
    recognition.addEventListener('error', _errorListener);
    recognition.addEventListener('end', _endListener);

    recognition.start();
    _recognition = recognition;
    _started = true;
  }

  Future<String?> stop() async {
    if (!_started) return null;

    _started = false;
    try {
      _recognition?.stop();
      await _endCompleter?.future.timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      try {
        _recognition?.abort();
      } catch (_) {}
    }

    _removeListeners();

    final text = [..._finalSegments, _interimText]
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .join(' ')
        .trim();
    return text.isEmpty ? null : text;
  }

  Future<void> dispose() async {
    await stop();
  }

  web.SpeechRecognition _createRecognition() {
    final constructor = (globalContext['SpeechRecognition'] ??
        globalContext['webkitSpeechRecognition']) as JSFunction?;
    if (constructor == null) {
      throw UnsupportedError('SpeechRecognition no disponible.');
    }
    return constructor.callAsConstructor<web.SpeechRecognition>();
  }

  void _removeListeners() {
    final recognition = _recognition;
    if (recognition != null) {
      recognition.removeEventListener('result', _resultListener);
      recognition.removeEventListener('error', _errorListener);
      recognition.removeEventListener('end', _endListener);
    }
    _resultListener = null;
    _errorListener = null;
    _endListener = null;
    _endCompleter = null;
    _recognition = null;
  }

  void _handleResult(web.SpeechRecognitionEvent event) {
    final results = event.results;
    final interimSegments = <String>[];

    for (var index = event.resultIndex; index < results.length; index++) {
      final result = results.item(index);
      final transcript = result.item(0).transcript.trim();
      if (transcript.isEmpty) continue;

      if (result.isFinal) {
        _finalSegments.add(transcript);
      } else {
        interimSegments.add(transcript);
      }
    }

    _interimText = interimSegments.join(' ').trim();
  }
}
