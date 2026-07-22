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

  test('Flutter TTS reports installed engines as strings', () async {
    final tts = RecordingFlutterTts(
      enginesResult: ['com.samsung.SMT', 'com.google.android.tts', 7],
    );

    final engines = await FlutterTtsSpeechEngine(tts).getEngines();

    expect(engines, ['com.samsung.SMT', 'com.google.android.tts']);
    expect(
      () => engines.add('com.example.tts'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('Flutter TTS returns no engines for non-list plugin output', () async {
    final tts = RecordingFlutterTts(enginesResult: 'not a list');

    expect(await FlutterTtsSpeechEngine(tts).getEngines(), isEmpty);
  });

  test('Flutter TTS reports the Android default engine as a string', () async {
    final tts = RecordingFlutterTts(defaultEngineResult: 'com.samsung.SMT');

    expect(
      await FlutterTtsSpeechEngine(tts).getDefaultEngine(),
      'com.samsung.SMT',
    );
  });

  test('Flutter TTS ignores a non-string Android default engine', () async {
    final tts = RecordingFlutterTts(defaultEngineResult: 7);

    expect(await FlutterTtsSpeechEngine(tts).getDefaultEngine(), isNull);
  });

  test('Flutter TTS selects a requested engine', () async {
    final tts = RecordingFlutterTts();

    await FlutterTtsSpeechEngine(tts).setEngine('com.google.android.tts');

    expect(tts.selectedEngine, 'com.google.android.tts');
  });

  test('Flutter TTS waits for engine selection to complete', () async {
    final pluginCompletion = Completer<dynamic>();
    final tts = RecordingFlutterTts(setEngineCompleter: pluginCompletion);
    var completed = false;

    final selection = FlutterTtsSpeechEngine(
      tts,
    ).setEngine('com.google.android.tts');
    selection.then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);

    expect(tts.selectedEngine, 'com.google.android.tts');
    expect(completed, isFalse);

    pluginCompletion.complete(1);
    await selection;

    expect(completed, isTrue);
  });

  test('unavailable target language is reported as a speech failure', () async {
    final tts = RecordingFlutterTts(languageResult: 0);
    final speaker = SystemLineSpeaker(tts: tts);

    await expectLater(
      speaker.speak(text: 'こんにちは', country: Country.japan, speaker: 1),
      throwsA(
        isA<TtsPlaybackException>().having(
          (error) => error.message,
          'message',
          'TTS language ja-JP is unavailable',
        ),
      ),
    );
    expect(tts.spokenText, isNull);
  });

  test('Android falls back to Google TTS when locale is unavailable', () async {
    final engine = ControllableSpeechEngine(
      languageResults: const [false, true],
      engines: const ['com.samsung.SMT', 'com.google.android.tts'],
    );
    final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

    final playback = speaker.speak(
      text: 'こんにちは',
      country: Country.japan,
      speaker: 1,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.single.complete();
    await playback;

    expect(engine.languages, ['ja-JP', 'ja-JP']);
    expect(engine.selectedEngines, ['com.google.android.tts']);
    expect(engine.pitches, [1.1]);
    expect(engine.texts, ['こんにちは']);
  });

  test('iOS configures a playback audio session before speaking', () async {
    final engine = ControllableSpeechEngine();
    final speaker = SystemLineSpeaker(engine: engine, isIos: true);

    final playback = speaker.speak(
      text: '안녕하세요',
      country: Country.korea,
      speaker: 1,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.single.complete();
    await playback;

    expect(engine.audioCategories, [
      (
        IosTextToSpeechAudioCategory.playback,
        const <IosTextToSpeechAudioCategoryOptions>[],
        IosTextToSpeechAudioMode.spokenAudio,
      ),
    ]);
    expect(engine.sharedInstanceCalls, [true]);
    expect(engine.languages, ['ko-KR']);
    expect(engine.texts, ['안녕하세요']);
  });

  test(
    'successful fallback remains the active engine for later requests',
    () async {
      final engine = ControllableSpeechEngine(
        languageResults: const [false, true, false, false],
        engines: const ['com.samsung.SMT', 'com.google.android.tts'],
        engineSelectionResults: const [true, true, true],
      );
      final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

      final first = speaker.speak(
        text: 'first',
        country: Country.japan,
        speaker: 1,
      );
      await Future<void>.delayed(Duration.zero);
      engine.stopCalls.single.complete();
      await first;

      final second = speaker.speak(
        text: 'second',
        country: Country.korea,
        speaker: 2,
      );
      await Future<void>.delayed(Duration.zero);
      engine.stopCalls.last.complete();

      await expectLater(second, throwsA(isA<TtsPlaybackException>()));
      expect(engine.selectedEngines, ['com.google.android.tts']);
      expect(engine.currentEngine, 'com.google.android.tts');
      expect(engine.pitches, [1.1]);
      expect(engine.texts, ['first']);
    },
  );

  test('failed engine restoration leaves active engine unknown', () async {
    final engine = ControllableSpeechEngine(
      languageResults: const [false, false, false, true],
      engines: const ['com.samsung.SMT', 'com.google.android.tts'],
      engineSelectionResults: const [true, false, true],
    );
    final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

    final first = speaker.speak(
      text: 'first',
      country: Country.japan,
      speaker: 1,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.single.complete();
    await expectLater(first, throwsA(isA<TtsPlaybackException>()));

    final second = speaker.speak(
      text: 'second',
      country: Country.korea,
      speaker: 2,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.last.complete();
    await second;

    expect(engine.selectedEngines, [
      'com.google.android.tts',
      'com.samsung.SMT',
      'com.google.android.tts',
    ]);
    expect(engine.languages, ['ja-JP', 'ja-JP', 'ko-KR', 'ko-KR']);
    expect(engine.texts, ['second']);
  });

  test('stale Google TTS switch restores the previous engine', () async {
    final firstEngineSelection = Completer<void>();
    final engine = ControllableSpeechEngine(
      languageResults: const [false, true],
      engines: const ['com.samsung.SMT', 'com.google.android.tts'],
      engineSelectionResults: const [true, true],
      firstEngineSelectionCompleter: firstEngineSelection,
    );
    final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

    final first = speaker.speak(
      text: 'first',
      country: Country.japan,
      speaker: 1,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.single.complete();
    await pumpEventQueue();
    expect(engine.selectedEngines, ['com.google.android.tts']);

    final second = speaker.speak(
      text: 'second',
      country: Country.korea,
      speaker: 2,
    );
    firstEngineSelection.complete();
    await pumpEventQueue();
    expect(engine.selectedEngines, [
      'com.google.android.tts',
      'com.samsung.SMT',
    ]);
    expect(engine.stopCalls, hasLength(2));
    engine.stopCalls.last.complete();
    await Future.wait([first, second]);

    expect(engine.currentEngine, 'com.samsung.SMT');
    expect(engine.languages, ['ja-JP', 'ko-KR']);
    expect(engine.texts, ['second']);
  });

  test('stale Google TTS locale retry restores the previous engine', () async {
    final secondLanguageResult = Completer<bool>();
    final engine = ControllableSpeechEngine(
      languageResults: const [false, true, true],
      engines: const ['com.samsung.SMT', 'com.google.android.tts'],
      engineSelectionResults: const [true, true],
      secondLanguageCompleter: secondLanguageResult,
    );
    final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

    final first = speaker.speak(
      text: 'first',
      country: Country.japan,
      speaker: 1,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.single.complete();
    await pumpEventQueue();
    expect(engine.languages, ['ja-JP', 'ja-JP']);
    expect(engine.selectedEngines, ['com.google.android.tts']);

    final second = speaker.speak(
      text: 'second',
      country: Country.korea,
      speaker: 2,
    );
    secondLanguageResult.complete(true);
    await pumpEventQueue();
    expect(engine.selectedEngines, [
      'com.google.android.tts',
      'com.samsung.SMT',
    ]);
    expect(engine.stopCalls, hasLength(2));
    engine.stopCalls.last.complete();
    await Future.wait([first, second]);

    expect(engine.currentEngine, 'com.samsung.SMT');
    expect(engine.languages, ['ja-JP', 'ja-JP', 'ko-KR']);
    expect(engine.pitches, [0.85]);
    expect(engine.texts, ['second']);
  });

  test('available locale keeps the current Android TTS engine', () async {
    final engine = ControllableSpeechEngine();
    final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

    final playback = speaker.speak(
      text: '안녕하세요',
      country: Country.korea,
      speaker: 2,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.single.complete();
    await playback;

    expect(engine.languages, ['ko-KR']);
    expect(engine.selectedEngines, isEmpty);
    expect(engine.texts, ['안녕하세요']);
  });

  test(
    'non-Android does not change TTS engine after locale rejection',
    () async {
      final engine = ControllableSpeechEngine(
        languageResults: const [false],
        engines: const ['com.google.android.tts'],
      );
      final speaker = SystemLineSpeaker(engine: engine, isAndroid: false);

      final playback = speaker.speak(
        text: 'こんにちは',
        country: Country.japan,
        speaker: 1,
      );
      await Future<void>.delayed(Duration.zero);
      engine.stopCalls.single.complete();

      await expectLater(playback, throwsA(isA<TtsPlaybackException>()));
      expect(engine.languages, ['ja-JP']);
      expect(engine.selectedEngines, isEmpty);
    },
  );

  test('missing Google TTS reports unavailable locale', () async {
    final engine = ControllableSpeechEngine(
      languageResults: const [false],
      engines: const ['com.samsung.SMT'],
    );
    final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

    final playback = speaker.speak(
      text: 'こんにちは',
      country: Country.japan,
      speaker: 1,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.single.complete();

    await expectLater(playback, throwsA(isA<TtsPlaybackException>()));
    expect(engine.languages, ['ja-JP']);
    expect(engine.selectedEngines, isEmpty);
    expect(engine.texts, isEmpty);
  });

  test('failed Google TTS locale retry reports unavailable locale', () async {
    final engine = ControllableSpeechEngine(
      languageResults: const [false, false],
      engines: const ['com.google.android.tts'],
      engineSelectionResults: const [true, true],
    );
    final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

    final playback = speaker.speak(
      text: 'こんにちは',
      country: Country.japan,
      speaker: 1,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.single.complete();

    await expectLater(playback, throwsA(isA<TtsPlaybackException>()));
    expect(engine.selectedEngines, [
      'com.google.android.tts',
      'com.samsung.SMT',
    ]);
    expect(engine.currentEngine, 'com.samsung.SMT');
    expect(engine.languages, ['ja-JP', 'ja-JP']);
    expect(engine.texts, isEmpty);
  });

  test('failed Google TTS initialization reports unavailable locale', () async {
    final engine = ControllableSpeechEngine(
      languageResults: const [false],
      engines: const ['com.google.android.tts'],
      engineSelectionResults: const [false, true],
    );
    final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

    final playback = speaker.speak(
      text: 'こんにちは',
      country: Country.japan,
      speaker: 1,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.single.complete();

    await expectLater(playback, throwsA(isA<TtsPlaybackException>()));
    expect(engine.selectedEngines, [
      'com.google.android.tts',
      'com.samsung.SMT',
    ]);
    expect(engine.currentEngine, 'com.samsung.SMT');
    expect(engine.texts, isEmpty);
  });

  test(
    'default Google TTS engine is not reinitialized after rejection',
    () async {
      final engine = ControllableSpeechEngine(
        languageResults: const [false],
        engines: const ['com.google.android.tts'],
        defaultEngine: 'com.google.android.tts',
      );
      final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

      final playback = speaker.speak(
        text: 'こんにちは',
        country: Country.japan,
        speaker: 1,
      );
      await Future<void>.delayed(Duration.zero);
      engine.stopCalls.single.complete();

      await expectLater(playback, throwsA(isA<TtsPlaybackException>()));
      expect(engine.selectedEngines, isEmpty);
      expect(engine.languages, ['ja-JP']);
      expect(engine.texts, isEmpty);
    },
  );

  test('rejected speech is not retried with another engine', () async {
    final engine = ControllableSpeechEngine(
      engines: const ['com.google.android.tts'],
      speakResult: false,
    );
    final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

    final playback = speaker.speak(
      text: '안녕하세요',
      country: Country.korea,
      speaker: 2,
    );
    await Future<void>.delayed(Duration.zero);
    engine.stopCalls.single.complete();

    await expectLater(playback, throwsA(isA<TtsPlaybackException>()));
    expect(engine.selectedEngines, isEmpty);
    expect(engine.texts, ['안녕하세요']);
  });

  test('rejected platform playback is reported as a speech failure', () async {
    final tts = RecordingFlutterTts(speakResult: 0);
    final speaker = SystemLineSpeaker(tts: tts);

    await expectLater(
      speaker.speak(text: '안녕하세요', country: Country.korea, speaker: 2),
      throwsA(
        isA<TtsPlaybackException>().having(
          (error) => error.message,
          'message',
          'TTS playback was rejected',
        ),
      ),
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
  RecordingFlutterTts({
    this.languageResult = 1,
    this.speakResult = 1,
    this.enginesResult = const <Object>[],
    this.defaultEngineResult,
    this.setEngineCompleter,
  });

  final int languageResult;
  final int speakResult;
  final Object? enginesResult;
  final Object? defaultEngineResult;
  final Completer<dynamic>? setEngineCompleter;
  String? spokenText;
  bool? requestedFocus;
  String? selectedEngine;

  @override
  Future<dynamic> get getEngines async => enginesResult;

  @override
  Future<dynamic> get getDefaultEngine async => defaultEngineResult;

  @override
  Future<dynamic> setEngine(String engine) {
    selectedEngine = engine;
    return setEngineCompleter?.future ?? Future<dynamic>.value(1);
  }

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
  ControllableSpeechEngine({
    this.languageResults = const [true],
    this.engines = const [],
    this.speakResult = true,
    this.defaultEngine = 'com.samsung.SMT',
    this.engineSelectionResults = const [true],
    this.firstEngineSelectionCompleter,
    this.secondLanguageCompleter,
  }) : currentEngine = defaultEngine;

  final List<bool> languageResults;
  final List<String> engines;
  final bool speakResult;
  final String? defaultEngine;
  final List<bool> engineSelectionResults;
  final Completer<void>? firstEngineSelectionCompleter;
  final Completer<bool>? secondLanguageCompleter;
  final stopCalls = <Completer<void>>[];
  final languages = <String>[];
  final selectedEngines = <String>[];
  final pitches = <double>[];
  final texts = <String>[];
  final audioCategories =
      <
        (
          IosTextToSpeechAudioCategory,
          List<IosTextToSpeechAudioCategoryOptions>,
          IosTextToSpeechAudioMode,
        )
      >[];
  final sharedInstanceCalls = <bool>[];
  String? currentEngine;
  int _languageResultIndex = 0;
  int _engineSelectionIndex = 0;

  @override
  Future<String?> getDefaultEngine() async => defaultEngine;

  @override
  Future<List<String>> getEngines() async => engines;

  @override
  Future<void> setEngine(String engine) async {
    selectedEngines.add(engine);
    currentEngine = engine;
    final selection = _engineSelectionIndex++;
    if (selection == 0) await firstEngineSelectionCompleter?.future;
    if (selection >= engineSelectionResults.length ||
        !engineSelectionResults[selection]) {
      throw StateError('Engine selection failed');
    }
  }

  @override
  Future<void> stop() {
    final completer = Completer<void>();
    stopCalls.add(completer);
    return completer.future;
  }

  @override
  Future<bool> setLanguage(String language) async {
    languages.add(language);
    final attempt = _languageResultIndex++;
    if (attempt == 1 && secondLanguageCompleter != null) {
      return secondLanguageCompleter!.future;
    }
    if (attempt >= languageResults.length) return false;
    return languageResults[attempt];
  }

  @override
  Future<void> setPitch(double pitch) async => pitches.add(pitch);

  @override
  Future<void> setIosAudioCategory(
    IosTextToSpeechAudioCategory category,
    List<IosTextToSpeechAudioCategoryOptions> options, [
    IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode,
  ]) async {
    audioCategories.add((category, options, mode));
  }

  @override
  Future<void> setSharedInstance(bool sharedSession) async {
    sharedInstanceCalls.add(sharedSession);
  }

  @override
  Future<bool> speak(String text) async {
    texts.add(text);
    return speakResult;
  }
}
