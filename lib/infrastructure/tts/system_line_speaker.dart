import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/entities/country.dart';
import '../../domain/providers/line_speaker.dart';

abstract interface class LineSpeechEngine {
  Future<void> stop();
  Future<bool> setLanguage(String language);
  Future<void> setPitch(double pitch);
  Future<bool> speak(String text);
}

class FlutterTtsSpeechEngine implements LineSpeechEngine {
  FlutterTtsSpeechEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> stop() async => _tts.stop();

  @override
  Future<bool> setLanguage(String language) async =>
      await _tts.setLanguage(language) == 1;

  @override
  Future<void> setPitch(double pitch) async => _tts.setPitch(pitch);

  @override
  Future<bool> speak(String text) async =>
      await _tts.speak(text, focus: true) == 1;
}

final class TtsPlaybackException implements Exception {
  const TtsPlaybackException(this.message);

  final String message;

  @override
  String toString() => 'TtsPlaybackException: $message';
}

class SystemLineSpeaker implements LineSpeaker {
  SystemLineSpeaker({LineSpeechEngine? engine, FlutterTts? tts})
    : assert(engine == null || tts == null),
      _engine = engine ?? FlutterTtsSpeechEngine(tts);

  final LineSpeechEngine _engine;
  int _request = 0;
  Future<void> _tail = Future<void>.value();

  static const _pitchBySpeaker = {1: 1.1, 2: 0.85};

  @override
  Future<void> speak({
    required String text,
    required Country country,
    required int speaker,
  }) {
    final request = ++_request;
    final operation = _tail.then((_) async {
      if (request != _request) return;
      await _engine.stop();
      if (request != _request) return;
      final languageReady = await _engine.setLanguage(country.ttsLocale);
      if (request != _request) return;
      if (!languageReady) {
        throw TtsPlaybackException(
          'TTS language ${country.ttsLocale} is unavailable',
        );
      }
      await _engine.setPitch(_pitchBySpeaker[speaker] ?? 1.0);
      if (request != _request) return;
      final playbackStarted = await _engine.speak(text);
      if (request != _request) return;
      if (!playbackStarted) {
        throw const TtsPlaybackException('TTS playback was rejected');
      }
    });
    _continueAfter(operation);
    return operation;
  }

  @override
  Future<void> stop() {
    _request++;
    final operation = _tail.then((_) => _engine.stop());
    _continueAfter(operation);
    return operation;
  }

  void _continueAfter(Future<void> operation) {
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  }
}
