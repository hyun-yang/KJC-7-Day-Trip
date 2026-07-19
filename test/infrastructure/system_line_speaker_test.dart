import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/infrastructure/tts/system_line_speaker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Flutter TTS requests Android audio focus', () async {
    final tts = RecordingFlutterTts();

    await FlutterTtsSpeechEngine(tts).speak('你好');

    expect(tts.spokenText, '你好');
    expect(tts.requestedFocus, isTrue);
  });

  test('unavailable target language is reported as a speech failure', () async {
    final tts = RecordingFlutterTts(languageResult: 0);
    final speaker = SystemLineSpeaker(tts: tts);

    await expectLater(
      speaker.speak(text: 'こんにちは', country: Country.japan, speaker: 1),
      throwsA(isA<Exception>()),
    );
    expect(tts.spokenText, isNull);
  });

  test('rejected platform playback is reported as a speech failure', () async {
    final tts = RecordingFlutterTts(speakResult: 0);
    final speaker = SystemLineSpeaker(tts: tts);

    await expectLater(
      speaker.speak(text: '안녕하세요', country: Country.korea, speaker: 2),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'rapid speaks use last-tap-wins without mixing engine settings',
    () async {
      final engine = ControllableSpeechEngine();
      final speaker = SystemLineSpeaker(engine: engine);

      final first = speaker.speak(
        text: 'first',
        country: Country.japan,
        speaker: 1,
      );
      final second = speaker.speak(
        text: 'second',
        country: Country.korea,
        speaker: 2,
      );

      await Future<void>.delayed(Duration.zero);
      expect(engine.stopCalls, hasLength(1));
      engine.stopCalls.single.complete();
      await Future.wait([first, second]);

      expect(engine.languages, ['ko-KR']);
      expect(engine.pitches, [0.85]);
      expect(engine.texts, ['second']);
    },
  );
}

class RecordingFlutterTts extends FlutterTts {
  RecordingFlutterTts({this.languageResult = 1, this.speakResult = 1});

  final int languageResult;
  final int speakResult;
  String? spokenText;
  bool? requestedFocus;

  @override
  Future<dynamic> stop() async => 1;

  @override
  Future<dynamic> setLanguage(String language) async => languageResult;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenText = text;
    requestedFocus = focus;
    return speakResult;
  }
}

class ControllableSpeechEngine implements LineSpeechEngine {
  final stopCalls = <Completer<void>>[];
  final languages = <String>[];
  final pitches = <double>[];
  final texts = <String>[];

  @override
  Future<void> stop() {
    final completer = Completer<void>();
    stopCalls.add(completer);
    return completer.future;
  }

  @override
  Future<bool> setLanguage(String language) async {
    languages.add(language);
    return true;
  }

  @override
  Future<void> setPitch(double pitch) async => pitches.add(pitch);

  @override
  Future<bool> speak(String text) async {
    texts.add(text);
    return true;
  }
}
