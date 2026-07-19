# Android TTS Engine Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Japanese conversation audio play on Android devices whose default TTS engine lacks Japanese by falling back once to installed Google TTS.

**Architecture:** Extend the existing `LineSpeechEngine` adapter boundary with installed-engine discovery and engine selection. Keep the fallback policy in `SystemLineSpeaker`, gate it behind injected Android platform state, preserve the current last-tap-wins sequencing, and leave the UI error path unchanged.

**Tech Stack:** Flutter, Dart, `flutter_tts` 4.2.5, `flutter_test`, Android ADB

---

## File map

- Modify `lib/infrastructure/tts/system_line_speaker.dart`: add engine discovery/selection to the adapter and one-shot Android Google TTS fallback to playback orchestration.
- Modify `test/infrastructure/system_line_speaker_test.dart`: cover adapter mapping, fallback success, platform gating, missing fallback engine, failed retry, and no retry after speech rejection.
- Modify `docs/superpowers/plans/2026-07-19-android-tts-engine-fallback.md`: mark each completed checkbox during execution.

### Task 1: Expose installed-engine discovery and engine selection

**Files:**
- Modify: `lib/infrastructure/tts/system_line_speaker.dart:6-31`
- Test: `test/infrastructure/system_line_speaker_test.dart`

- [ ] **Step 1: Write failing adapter tests**

Add these tests after `Flutter TTS requests Android audio focus`:

```dart
test('Flutter TTS reports installed engines as strings', () async {
  final tts = RecordingFlutterTts(
    engines: ['com.samsung.SMT', 'com.google.android.tts', 7],
  );

  final engines = await FlutterTtsSpeechEngine(tts).getEngines();

  expect(engines, ['com.samsung.SMT', 'com.google.android.tts']);
});

test('Flutter TTS selects a requested engine', () async {
  final tts = RecordingFlutterTts();

  await FlutterTtsSpeechEngine(tts).setEngine('com.google.android.tts');

  expect(tts.selectedEngine, 'com.google.android.tts');
});
```

Extend `RecordingFlutterTts` with engine fixtures and overrides:

```dart
RecordingFlutterTts({
  this.languageResult = 1,
  this.speakResult = 1,
  this.engines = const <Object>[],
});

final List<Object> engines;
String? selectedEngine;

@override
Future<dynamic> get getEngines async => engines;

@override
Future<dynamic> setEngine(String engine) async {
  selectedEngine = engine;
  return 1;
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
flutter test test/infrastructure/system_line_speaker_test.dart
```

Expected: compilation fails because `LineSpeechEngine` and
`FlutterTtsSpeechEngine` do not define `getEngines` or `setEngine`.

- [ ] **Step 3: Add the minimal adapter API**

Add to `LineSpeechEngine`:

```dart
Future<List<String>> getEngines();
Future<void> setEngine(String engine);
```

Add to `FlutterTtsSpeechEngine`:

```dart
@override
Future<List<String>> getEngines() async {
  final engines = await _tts.getEngines;
  if (engines is! List) return const [];
  return engines.whereType<String>().toList(growable: false);
}

@override
Future<void> setEngine(String engine) async {
  await _tts.setEngine(engine);
}
```

Add no-op implementations to `ControllableSpeechEngine` so the existing rapid-tap test compiles:

```dart
@override
Future<List<String>> getEngines() async => const [];

@override
Future<void> setEngine(String engine) async {}
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run:

```bash
flutter test test/infrastructure/system_line_speaker_test.dart
```

Expected: all tests in the file pass.

- [ ] **Step 5: Commit the adapter boundary**

```bash
git add lib/infrastructure/tts/system_line_speaker.dart test/infrastructure/system_line_speaker_test.dart
git commit -m "feat: expose installed Android TTS engines"
```

### Task 2: Fall back to Google TTS after locale rejection

**Files:**
- Modify: `lib/infrastructure/tts/system_line_speaker.dart:42-94`
- Test: `test/infrastructure/system_line_speaker_test.dart`

- [ ] **Step 1: Add a controllable engine fake**

Replace the no-op engine additions from Task 1 in `ControllableSpeechEngine`
with recorded values while preserving its existing fields and methods:

```dart
ControllableSpeechEngine({
  this.languageResults = const [true],
  this.engines = const [],
  this.speakResult = true,
  this.failEngineSelection = false,
});

final List<bool> languageResults;
final List<String> engines;
final bool speakResult;
final bool failEngineSelection;
final selectedEngines = <String>[];
int _languageResultIndex = 0;

@override
Future<List<String>> getEngines() async => engines;

@override
Future<void> setEngine(String engine) async {
  selectedEngines.add(engine);
  if (failEngineSelection) throw StateError('engine initialization failed');
}

@override
Future<bool> setLanguage(String language) async {
  languages.add(language);
  final index = _languageResultIndex++;
  return index < languageResults.length ? languageResults[index] : false;
}

@override
Future<bool> speak(String text) async {
  texts.add(text);
  return speakResult;
}
```

- [ ] **Step 2: Write the failing successful-fallback test**

Add:

```dart
test('Android falls back to Google TTS when locale is unavailable', () async {
  final engine = ControllableSpeechEngine(
    languageResults: [false, true],
    engines: ['com.samsung.SMT', 'com.google.android.tts'],
  );
  final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

  await speaker.speak(
    text: 'こんにちは',
    country: Country.japan,
    speaker: 1,
  );

  expect(engine.languages, ['ja-JP', 'ja-JP']);
  expect(engine.selectedEngines, ['com.google.android.tts']);
  expect(engine.pitches, [1.1]);
  expect(engine.texts, ['こんにちは']);
});
```

- [ ] **Step 3: Run the focused test and verify RED**

Run:

```bash
flutter test test/infrastructure/system_line_speaker_test.dart --plain-name "Android falls back to Google TTS when locale is unavailable"
```

Expected: compilation fails because `SystemLineSpeaker` has no `isAndroid`
parameter, or the call throws the current unavailable-language exception.

- [ ] **Step 4: Implement the minimal one-shot fallback**

Import Flutter foundation platform APIs:

```dart
import 'package:flutter/foundation.dart';
```

Update the constructor and fields:

```dart
SystemLineSpeaker({
  LineSpeechEngine? engine,
  FlutterTts? tts,
  bool? isAndroid,
}) : assert(engine == null || tts == null),
     _engine = engine ?? FlutterTtsSpeechEngine(tts),
     _isAndroid = isAndroid ??
         defaultTargetPlatform == TargetPlatform.android;

static const _googleTtsEngine = 'com.google.android.tts';

final LineSpeechEngine _engine;
final bool _isAndroid;
```

Add this helper:

```dart
Future<bool> _prepareLanguage(String locale, int request) async {
  try {
    if (await _engine.setLanguage(locale)) return true;
    if (!_isAndroid || request != _request) return false;

    final engines = await _engine.getEngines();
    if (request != _request || !engines.contains(_googleTtsEngine)) {
      return false;
    }

    await _engine.setEngine(_googleTtsEngine);
    if (request != _request) return false;
    return _engine.setLanguage(locale);
  } on Object {
    return false;
  }
}
```

Replace the first language-selection call in `speak`:

```dart
final languageReady = await _prepareLanguage(country.ttsLocale, request);
```

- [ ] **Step 5: Run the focused test and verify GREEN**

Run:

```bash
flutter test test/infrastructure/system_line_speaker_test.dart --plain-name "Android falls back to Google TTS when locale is unavailable"
```

Expected: PASS.

- [ ] **Step 6: Write failing boundary tests**

Add:

```dart
test('available locale keeps the current Android TTS engine', () async {
  final engine = ControllableSpeechEngine(
    engines: ['com.google.android.tts'],
  );
  final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

  await speaker.speak(text: '안녕하세요', country: Country.korea, speaker: 2);

  expect(engine.selectedEngines, isEmpty);
  expect(engine.languages, ['ko-KR']);
  expect(engine.texts, ['안녕하세요']);
});

test('non-Android does not change TTS engine after locale rejection', () async {
  final engine = ControllableSpeechEngine(
    languageResults: [false],
    engines: ['com.google.android.tts'],
  );
  final speaker = SystemLineSpeaker(engine: engine, isAndroid: false);

  await expectLater(
    speaker.speak(text: 'こんにちは', country: Country.japan, speaker: 1),
    throwsA(isA<TtsPlaybackException>()),
  );

  expect(engine.selectedEngines, isEmpty);
  expect(engine.languages, ['ja-JP']);
});

test('missing Google TTS reports unavailable locale', () async {
  final engine = ControllableSpeechEngine(
    languageResults: [false],
    engines: ['com.samsung.SMT'],
  );
  final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

  await expectLater(
    speaker.speak(text: 'こんにちは', country: Country.japan, speaker: 1),
    throwsA(isA<TtsPlaybackException>()),
  );

  expect(engine.selectedEngines, isEmpty);
  expect(engine.texts, isEmpty);
});

test('failed Google TTS locale retry reports unavailable locale', () async {
  final engine = ControllableSpeechEngine(
    languageResults: [false, false],
    engines: ['com.google.android.tts'],
  );
  final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

  await expectLater(
    speaker.speak(text: 'こんにちは', country: Country.japan, speaker: 1),
    throwsA(isA<TtsPlaybackException>()),
  );

  expect(engine.selectedEngines, ['com.google.android.tts']);
  expect(engine.languages, ['ja-JP', 'ja-JP']);
  expect(engine.texts, isEmpty);
});

test('failed Google TTS initialization reports unavailable locale', () async {
  final engine = ControllableSpeechEngine(
    languageResults: [false],
    engines: ['com.google.android.tts'],
    failEngineSelection: true,
  );
  final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

  await expectLater(
    speaker.speak(text: 'こんにちは', country: Country.japan, speaker: 1),
    throwsA(isA<TtsPlaybackException>()),
  );

  expect(engine.selectedEngines, ['com.google.android.tts']);
  expect(engine.texts, isEmpty);
});

test('rejected speech is not retried with another engine', () async {
  final engine = ControllableSpeechEngine(
    engines: ['com.google.android.tts'],
    speakResult: false,
  );
  final speaker = SystemLineSpeaker(engine: engine, isAndroid: true);

  await expectLater(
    speaker.speak(text: '안녕하세요', country: Country.korea, speaker: 2),
    throwsA(isA<TtsPlaybackException>()),
  );

  expect(engine.selectedEngines, isEmpty);
  expect(engine.texts, ['안녕하세요']);
});
```

- [ ] **Step 7: Run the full TTS test file**

Run:

```bash
flutter test test/infrastructure/system_line_speaker_test.dart
```

Expected: all tests pass. The tests introduced in Step 6 should pass without
additional production code; if one fails, correct only the fallback boundary
that the failing assertion identifies.

- [ ] **Step 8: Format and commit the fallback behavior**

```bash
dart format lib/infrastructure/tts/system_line_speaker.dart test/infrastructure/system_line_speaker_test.dart
git add lib/infrastructure/tts/system_line_speaker.dart test/infrastructure/system_line_speaker_test.dart
git commit -m "fix: fall back to Google TTS on Android"
```

### Task 3: Verify the regression and physical-device behavior

**Files:**
- Modify: `docs/superpowers/plans/2026-07-19-android-tts-engine-fallback.md`

- [ ] **Step 1: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 2: Run the complete automated suite**

Run:

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Build the Android APK**

Run:

```bash
flutter build apk
```

Expected: `build/app/outputs/flutter-apk/app-release.apk` is produced.

- [ ] **Step 4: Install the current debug build on the connected Samsung device**

Resolve one explicit Samsung serial from `adb devices -l`, then run:

```bash
flutter run -d '<samsung-device-serial>'
```

Expected: the app launches successfully. Keep the Flutter process attached so
runtime logs remain available.

- [ ] **Step 5: Verify Japanese playback and audio focus**

Open the existing Japanese conversation and tap a speaker icon. Capture focused
logs with:

```bash
adb -s '<samsung-device-serial>' logcat -d | rg 'TextToSpeech|AudioTrack|requestAudioFocus|flutter'
```

Expected:

- Japanese speech is audible.
- No `Audio is unavailable right now.` snackbar appears.
- Logs show Google TTS playback and Android audio focus acquisition.

- [ ] **Step 6: Mark this plan complete and commit execution records**

Mark every completed checkbox in this file, then run:

```bash
git add -f docs/superpowers/plans/2026-07-19-android-tts-engine-fallback.md
git commit -m "docs: record Android TTS fallback verification"
```
