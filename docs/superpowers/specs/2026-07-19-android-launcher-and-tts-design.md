# Android Launch, App Icon, and TTS Reliability Design

## Goal

Remove all visible Flutter branding during Android startup, give KJC 7-Day Trip a product-specific launcher icon, and make conversation speech reliable on physical Android devices.

## Current Behavior and Root Causes

Android 12 and newer always show a system-controlled launch splash before Flutter renders its first frame. The project has no Android 12-specific splash resources and still uses Flutter's generated `ic_launcher` images, so the system splash displays the Flutter logo. This behavior is independent of Flutter debug mode.

The app then renders its own `LaunchSplashScreen`, which contains the intended full KJC artwork. Android does not allow that Flutter widget to replace the earlier system-controlled launch window.

Conversation speaker taps reach `flutter_tts`, but the Android call uses its default `focus: false`. Device logs show the Google TTS process being classified for background-playback hardening, which can mute playback. The adapter also discards the return values from language selection and speech startup, so unavailable languages and rejected playback can appear to succeed without sound or feedback.

## Startup and Icon Design

The launcher icon will use a text-free, simplified motif derived from the existing splash artwork: a red torii in front of dark green mountains on the application's warm cream background. The source will be a high-resolution square image with generous safe-area padding so Android adaptive-icon masks do not crop the motif. Android launcher resources will include standard density variants and adaptive foreground/background resources.

The Android system splash will use the same cream background and the new KJC icon. It will transition into the existing Flutter `LaunchSplashScreen`, which retains the title and full travel illustration. Flutter branding will not appear at either stage. The two stages will look intentional and visually continuous, while respecting Android 12+ launch-screen constraints.

Legacy Android launch resources will also use the product background and icon so supported Android versions have consistent behavior. Dark mode will not substitute a black launch background; startup remains aligned with the app's light visual identity.

## TTS Design

`FlutterTtsSpeechEngine` will request Android audio focus when starting speech. Its platform adapter will preserve and validate the result of `setLanguage` and `speak` instead of treating every completed method-channel call as success.

The application-level speaker will retain the existing last-tap-wins serialization so rapid taps cannot mix voice settings. A missing target language, failed TTS initialization, or rejected playback will throw a typed or clearly described exception through the existing `LineSpeaker` boundary. `ConversationViewerScreen` will catch that failure and display its existing audio-unavailable snackbar. Successful taps remain one-action playback with no additional dialogs.

The supported target locales remain `ko-KR`, `ja-JP`, and `zh-CN`. The app will not add cloud speech, prerecorded audio, or another provider.

## Error Handling

- If Android cannot select the target locale, do not speak using an incorrect fallback voice; surface the existing unavailable-audio message.
- If Android rejects the speech request, surface the same message.
- If a newer tap supersedes an older queued request, cancel silently as the existing last-tap-wins behavior intends.
- Stopping speech during screen disposal remains best-effort and must not crash navigation.

## Testing and Verification

Tests will be written before each behavior change and observed failing for the intended reason.

- A platform-adapter test will assert that Android speech requests audio focus.
- Unit tests will assert that failed language selection and failed speech startup become errors.
- Existing rapid-tap serialization coverage will remain green.
- Android resource tests will assert that the manifest, adaptive icon, Android 12 splash theme, legacy launch background, and product launcher assets reference KJC resources rather than Flutter defaults.
- Widget coverage will confirm a TTS failure produces the unavailable-audio snackbar.

Final verification will run formatting, focused tests, the full Flutter test suite, static analysis, and an Android APK build. When an emulator is available, the APK will be installed and startup/TTS behavior will be checked through screenshots, UI automation, logcat, and Android audio playback state.

## Out of Scope

- Removing Android's system-controlled launch phase, which Android 12+ does not permit.
- Replacing the existing Flutter splash composition or its two-second duration.
- Adding non-system TTS providers, generated speech files, speech-to-text, or pronunciation features.
- Changing iOS, Linux, or web branding and audio behavior.
