class LiveSpeechTranscriber {
  bool get isSupported => false;

  Future<void> start() async {}

  Future<String?> stop() async => null;

  Future<void> dispose() async {}
}
