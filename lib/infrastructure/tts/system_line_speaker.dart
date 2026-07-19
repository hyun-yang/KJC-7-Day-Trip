import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/entities/country.dart';
import '../../domain/providers/line_speaker.dart';

abstract interface class LineSpeechEngine {
  Future<String?> getDefaultEngine();
  Future<List<String>> getEngines();
  Future<void> setEngine(String engine);
  Future<void> stop();
  Future<bool> setLanguage(String language);
  Future<void> setPitch(double pitch);
  Future<bool> speak(String text);
}

class FlutterTtsSpeechEngine implements LineSpeechEngine {
  FlutterTtsSpeechEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<String?> getDefaultEngine() async {
    final engine = await _tts.getDefaultEngine;
    return engine is String ? engine : null;
  }

  @override
  Future<List<String>> getEngines() async {
    final engines = await _tts.getEngines;
    if (engines is! List) return const [];
    return engines.whereType<String>().toList(growable: false);
  }

  @override
  Future<void> setEngine(String engine) async => _tts.setEngine(engine);

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
  SystemLineSpeaker({
    LineSpeechEngine? engine,
    FlutterTts? tts,
    bool? isAndroid,
  }) : assert(engine == null || tts == null),
       _engine = engine ?? FlutterTtsSpeechEngine(tts),
       _isAndroid =
           isAndroid ?? defaultTargetPlatform == TargetPlatform.android;

  final LineSpeechEngine _engine;
  final bool _isAndroid;
  String? _activeEngine;
  int _request = 0;
  Future<void> _tail = Future<void>.value();

  static const _googleTtsEngine = 'com.google.android.tts';
  static const _pitchBySpeaker = {1: 1.1, 2: 0.85};

  Future<void> _restoreEngine(String engine) async {
    _activeEngine = null;
    try {
      await _engine.setEngine(engine);
      _activeEngine = engine;
    } catch (_) {}
  }

  Future<bool> _prepareLanguage(String locale, int request) async {
    try {
      if (await _engine.setLanguage(locale)) return true;
      if (!_isAndroid || request != _request) return false;

      final engines = await _engine.getEngines();
      if (request != _request || !engines.contains(_googleTtsEngine)) {
        return false;
      }

      final previousEngine = _activeEngine ?? await _engine.getDefaultEngine();
      if (request != _request || previousEngine == null) return false;
      _activeEngine ??= previousEngine;
      if (previousEngine == _googleTtsEngine) return false;

      try {
        await _engine.setEngine(_googleTtsEngine);
        _activeEngine = _googleTtsEngine;
      } catch (_) {
        _activeEngine = null;
        await _restoreEngine(previousEngine);
        return false;
      }
      if (request != _request) {
        await _restoreEngine(previousEngine);
        return false;
      }

      try {
        final languageReady = await _engine.setLanguage(locale);
        if (request != _request || !languageReady) {
          await _restoreEngine(previousEngine);
          return false;
        }
        return true;
      } catch (_) {
        await _restoreEngine(previousEngine);
        return false;
      }
    } catch (_) {
      return false;
    }
  }

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
      final languageReady = await _prepareLanguage(country.ttsLocale, request);
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
