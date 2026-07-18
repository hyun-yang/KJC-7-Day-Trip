import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/infrastructure/tts/system_line_speaker.dart';

void main() {
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
  Future<void> setLanguage(String language) async => languages.add(language);

  @override
  Future<void> setPitch(double pitch) async => pitches.add(pitch);

  @override
  Future<void> speak(String text) async => texts.add(text);
}
