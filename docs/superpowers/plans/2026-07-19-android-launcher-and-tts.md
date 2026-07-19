# Android Launcher and TTS Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every Android Flutter-branded launch surface with KJC branding and make physical-device TTS request audio focus while surfacing platform failures.

**Architecture:** Keep the Android system launch phase and Flutter splash as two visually continuous layers. Generate launcher resources from one repository-owned vector mark, and isolate dynamic `flutter_tts` return-value handling inside `FlutterTtsSpeechEngine` so `SystemLineSpeaker` can enforce success without leaking plugin details into UI code.

**Tech Stack:** Flutter 3.38, Dart 3.10, Android resource XML, SVG/PNG assets, `flutter_launcher_icons` 0.14.4, `flutter_tts` 4.2.5, `flutter_test`.

---

### Task 1: Product launcher mark and Android resource contract

**Files:**
- Create: `assets/branding/kjc_launcher_icon.svg`
- Create: `assets/branding/kjc_launcher_foreground.svg`
- Create: `assets/branding/kjc_launcher_icon.png`
- Create: `assets/branding/kjc_launcher_foreground.png`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: generated `android/app/src/main/res/mipmap-*/ic_launcher.png`
- Create: generated adaptive icon resources under `android/app/src/main/res/mipmap-anydpi-v26/`
- Test: `test/android_manifest_test.dart`

- [ ] **Step 1: Write the failing launcher resource test**

Add a test that reads `pubspec.yaml`, `AndroidManifest.xml`, and adaptive-icon XML and asserts:

```dart
test('Android launcher uses the KJC adaptive icon assets', () {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final adaptiveIcon = File(
    'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
  );

  expect(pubspec, contains('assets/branding/kjc_launcher_icon.png'));
  expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
  expect(adaptiveIcon.existsSync(), isTrue);
  expect(
    adaptiveIcon.readAsStringSync(),
    contains('@drawable/ic_launcher_foreground'),
  );
  for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
    expect(
      File('android/app/src/main/res/mipmap-$density/ic_launcher.png')
          .existsSync(),
      isTrue,
    );
  }
});
```

- [ ] **Step 2: Run the test and confirm it fails because adaptive KJC assets are absent**

Run: `flutter test test/android_manifest_test.dart --plain-name 'Android launcher uses the KJC adaptive icon assets'`

Expected: FAIL because `mipmap-anydpi-v26/ic_launcher.xml` does not exist and the branding asset is not registered.

- [ ] **Step 3: Create one deterministic icon source**

Create `kjc_launcher_foreground.svg` with this safe-zone composition:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <path fill="#2D6B5C" d="M205 690 394 410l118 173 116-205 204 312Z"/>
  <path fill="#164C3F" d="M128 724 343 489l97 112 72-88 191 211Z"/>
  <path fill="#D64235" d="M293 385h438l-25 58H318Zm53 90h332v46H346Zm54 28h48v253h-48Zm176 0h48v253h-48Zm-208 77h288v42H368Z"/>
  <path fill="#B92F2B" d="m271 385 35-49h412l35 49Z"/>
</svg>
```

Create `kjc_launcher_icon.svg` by using the same `viewBox`, placing `<rect width="1024" height="1024" rx="216" fill="#F7F4EE"/>` before the five foreground paths, and preserving those paths byte-for-byte. Use no words, gradients, shadows, flags, or Flutter shapes.

- [ ] **Step 4: Rasterize and configure launcher generation**

Use FFmpeg to rasterize the full icon and transparent foreground:

```bash
ffmpeg -y -i assets/branding/kjc_launcher_icon.svg \
  -vf scale=1024:1024 assets/branding/kjc_launcher_icon.png
ffmpeg -y -i assets/branding/kjc_launcher_foreground.svg \
  -vf scale=1024:1024 -pix_fmt rgba assets/branding/kjc_launcher_foreground.png
```

Then add this pinned generator configuration to `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: 0.14.4

flutter_launcher_icons:
  android: true
  ios: false
  image_path: assets/branding/kjc_launcher_icon.png
  adaptive_icon_background: '#F7F4EE'
  adaptive_icon_foreground: assets/branding/kjc_launcher_foreground.png
  adaptive_icon_monochrome: assets/branding/kjc_launcher_foreground.png
```

Run:

```bash
flutter pub get
dart run flutter_launcher_icons
```

- [ ] **Step 5: Run the focused resource test**

Run: `flutter test test/android_manifest_test.dart --plain-name 'Android launcher uses the KJC adaptive icon assets'`

Expected: PASS.

- [ ] **Step 6: Commit the launcher mark**

```bash
git add assets/branding pubspec.yaml pubspec.lock android/app/src/main/res test/android_manifest_test.dart
git commit -m "feat: add KJC Android launcher icon"
```

### Task 2: Product-native Android launch splash

**Files:**
- Modify: `android/app/src/main/res/drawable/launch_background.xml`
- Modify: `android/app/src/main/res/drawable-v21/launch_background.xml`
- Modify: `android/app/src/main/res/values/styles.xml`
- Modify: `android/app/src/main/res/values-night/styles.xml`
- Create: `android/app/src/main/res/values/colors.xml`
- Create: `android/app/src/main/res/values-v31/styles.xml`
- Create: `android/app/src/main/res/values-night-v31/styles.xml`
- Test: `test/android_manifest_test.dart`

- [ ] **Step 1: Write the failing native-splash contract test**

Add a test that verifies the Android 12 and legacy resources use the KJC cream background and product icon:

```dart
test('Android launch themes show KJC branding instead of Flutter branding', () {
  final dayV31 = File(
    'android/app/src/main/res/values-v31/styles.xml',
  );
  final nightV31 = File(
    'android/app/src/main/res/values-night-v31/styles.xml',
  );
  final legacy = File(
    'android/app/src/main/res/drawable/launch_background.xml',
  ).readAsStringSync();

  expect(dayV31.existsSync(), isTrue);
  expect(nightV31.existsSync(), isTrue);
  for (final file in [dayV31, nightV31]) {
    final xml = file.readAsStringSync();
    expect(xml, contains('android:windowSplashScreenBackground'));
    expect(xml, contains('@color/kjc_launch_background'));
    expect(xml, contains('android:windowSplashScreenAnimatedIcon'));
    expect(xml, contains('@mipmap/ic_launcher'));
    expect(xml, contains('android:postSplashScreenTheme'));
  }
  expect(legacy, contains('@color/kjc_launch_background'));
  expect(legacy, contains('@mipmap/ic_launcher'));
  expect(legacy, isNot(contains('@android:color/white')));
});
```

- [ ] **Step 2: Run the test and confirm the Android 12 files are missing**

Run: `flutter test test/android_manifest_test.dart --plain-name 'Android launch themes show KJC branding instead of Flutter branding'`

Expected: FAIL because `values-v31/styles.xml` is absent.

- [ ] **Step 3: Add matching legacy and Android 12 resources**

Create `values/colors.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="kjc_launch_background">#F7F4EE</color>
</resources>
```

Use this `LaunchTheme` body in both API 31 style files, retaining each file's light `NormalTheme` definition:

```xml
<style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
    <item name="android:windowSplashScreenBackground">@color/kjc_launch_background</item>
    <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher</item>
    <item name="android:postSplashScreenTheme">@style/NormalTheme</item>
    <item name="android:windowLightStatusBar">true</item>
</style>
```

Use this layer list in both legacy launch drawable files:

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/kjc_launch_background" />
    <item>
        <bitmap android:gravity="center" android:src="@mipmap/ic_launcher" />
    </item>
</layer-list>
```

Finally, change the existing day and night pre-31 `LaunchTheme` backgrounds to `@drawable/launch_background` and both `NormalTheme` backgrounds to `@color/kjc_launch_background`, preventing a black or system-white transition frame.

- [ ] **Step 4: Run the focused test**

Run: `flutter test test/android_manifest_test.dart --plain-name 'Android launch themes show KJC branding instead of Flutter branding'`

Expected: PASS.

- [ ] **Step 5: Commit the native splash resources**

```bash
git add android/app/src/main/res test/android_manifest_test.dart
git commit -m "feat: brand the Android launch splash"
```

### Task 3: Validate TTS platform results and request Android audio focus

**Files:**
- Modify: `lib/infrastructure/tts/system_line_speaker.dart`
- Modify: `test/infrastructure/system_line_speaker_test.dart`

- [ ] **Step 1: Write failing platform-adapter tests**

Inject a `FlutterTtsSpeak` callback into `FlutterTtsSpeechEngine`, invoke it, and assert the call receives `text == '你好'` and `focus == true`. Add configurable success booleans to `ControllableSpeechEngine`; return them from `setLanguage` and `speak`, then expect `SystemLineSpeaker.speak` to throw `TtsPlaybackException` when either is false.

```dart
test('Flutter TTS requests Android audio focus', () async {
  String? spokenText;
  bool? requestedFocus;
  final engine = FlutterTtsSpeechEngine(
    speakCall: (text, {required focus}) async {
      spokenText = text;
      requestedFocus = focus;
      return 1;
    },
  );

  await engine.speak('你好');

  expect(spokenText, '你好');
  expect(requestedFocus, isTrue);
});
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `flutter test test/infrastructure/system_line_speaker_test.dart`

Expected: FAIL because focus is currently false and engine methods do not expose failed result codes.

- [ ] **Step 3: Implement the minimal adapter contract**

Change the engine boundary and adapter to:

```dart
abstract interface class LineSpeechEngine {
  Future<void> stop();
  Future<bool> setLanguage(String language);
  Future<void> setPitch(double pitch);
  Future<bool> speak(String text);
}

typedef FlutterTtsSpeak = Future<dynamic> Function(
  String text, {
  required bool focus,
});

class FlutterTtsSpeechEngine implements LineSpeechEngine {
  FlutterTtsSpeechEngine({FlutterTts? tts, FlutterTtsSpeak? speakCall}) {
    _tts = tts ?? FlutterTts();
    _speakCall = speakCall ?? _tts.speak;
  }

  late final FlutterTts _tts;
  late final FlutterTtsSpeak _speakCall;

  @override
  Future<void> stop() async => _tts.stop();

  @override
  Future<bool> setLanguage(String language) async =>
      await _tts.setLanguage(language) == 1;

  @override
  Future<void> setPitch(double pitch) async => _tts.setPitch(pitch);

  @override
  Future<bool> speak(String text) async =>
      await _speakCall(text, focus: true) == 1;
}
```

Add the public failure type:

```dart
final class TtsPlaybackException implements Exception {
  const TtsPlaybackException(this.message);
  final String message;
  @override
  String toString() => 'TtsPlaybackException: $message';
}
```

Update `SystemLineSpeaker` construction to `_engine = engine ?? FlutterTtsSpeechEngine(tts: tts)` while preserving the assertion that callers cannot pass both an engine and `FlutterTts` instance.

In `SystemLineSpeaker.speak`, replace the language and speech calls with:

```dart
if (!await _engine.setLanguage(country.ttsLocale)) {
  throw TtsPlaybackException(
    'TTS language ${country.ttsLocale} is unavailable',
  );
}
if (request != _request) return;
await _engine.setPitch(_pitchBySpeaker[speaker] ?? 1.0);
if (request != _request) return;
if (!await _engine.speak(text)) {
  throw const TtsPlaybackException('TTS playback was rejected');
}
```

Preserve the request guard after `stop()` and after every awaited configuration operation.

- [ ] **Step 4: Run the focused tests and confirm GREEN**

Run: `flutter test test/infrastructure/system_line_speaker_test.dart`

Expected: all tests PASS, including last-tap-wins.

- [ ] **Step 5: Run the existing UI error test**

Run: `flutter test test/ui/generation_screen_test.dart --plain-name 'speech failure is nonfatal and shows an English notice'`

Expected: PASS, proving platform errors remain visible and nonfatal.

- [ ] **Step 6: Commit the TTS fix**

```bash
git add lib/infrastructure/tts/system_line_speaker.dart test/infrastructure/system_line_speaker_test.dart
git commit -m "fix: request Android audio focus for speech"
```

### Task 4: Full verification on Flutter and Android

**Files:**
- Modify only files requiring formatting or a verified build correction.

- [ ] **Step 1: Format and inspect the diff**

Run: `dart format lib test`

Run: `git diff --check && git status --short`

Expected: no whitespace errors and only planned files changed.

- [ ] **Step 2: Run static and automated verification**

Run:

```bash
flutter analyze
flutter test
flutter build apk
```

Expected: each command exits 0 with no analyzer errors or test failures; the APK is written under `build/app/outputs/flutter-apk/`.

- [ ] **Step 3: Install and validate startup on the connected emulator**

Install the built APK, force-stop it, record the first launch frames, and confirm no frame contains the Flutter logo. Confirm the launcher shows the KJC torii-and-mountain mark and the native cream splash transitions to the existing full Flutter splash.

- [ ] **Step 4: Validate TTS on the connected emulator**

Open a saved conversation, tap a Listen button, and verify logcat shows the requested target locale plus an active, unmuted `AudioTrack`. Confirm the TTS request obtains audio focus and that no `AudioHardening ... would be muted` event is emitted for the new playback.

- [ ] **Step 5: Commit any final verification-only correction**

If formatting or build verification changed tracked files, commit only those corrections with a concise Conventional Commit message. Otherwise leave the verified task commits unchanged.
