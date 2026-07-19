# Android TTS Engine Fallback Design

## Problem

On the physical Samsung device, tapping a conversation speaker button shows
`Audio is unavailable right now.` The device uses Samsung TTS as its default
engine, while the selected conversation requires the Japanese `ja-JP` locale.
The application currently treats a rejected language selection as a terminal
failure, even though Google TTS is also installed on the device.

## Desired behavior

Keep the user's configured TTS engine as the first choice. If that engine
cannot select the requested locale on Android, try the installed Google TTS
engine once, select the same locale again, and continue normal playback. If
Google TTS is absent or also rejects the locale, preserve the existing failure
path and snackbar.

## Considered approaches

1. **Automatic Google TTS fallback (selected).** Playback succeeds without
   requiring the user to change a device-wide preference. The app changes only
   its own TTS engine instance after the default engine rejects the locale.
2. **Send the user to Samsung voice-data settings.** This preserves the default
   engine but interrupts playback and depends on device-specific settings and
   downloadable voice availability.
3. **Keep the current generic error.** This requires no code change but leaves
   an installed, capable engine unused and does not satisfy the playback goal.

## Architecture

Extend the existing `LineSpeechEngine` boundary with the two capabilities the
application needs: list installed engines and select an engine. The
`FlutterTtsSpeechEngine` adapter maps these operations to `flutter_tts`.
`SystemLineSpeaker` remains responsible for playback orchestration and owns the
fallback policy.

The fallback engine package name is `com.google.android.tts`. The speaker will
not guess at other engines, repeatedly cycle engines, alter Android system
settings, or open settings screens.

## Playback flow

1. Stop any previous utterance.
2. Ask the current engine to select the conversation country's TTS locale.
3. If language selection succeeds, set pitch and speak as before.
4. If language selection fails, query installed engines.
5. If Google TTS is installed, select it and retry the requested locale once.
6. If the retry succeeds, set pitch and speak.
7. If Google TTS is unavailable, engine selection fails, the locale retry
   fails, or speech is rejected, throw `TtsPlaybackException` and let the
   existing UI show `Audio is unavailable right now.`

The fallback is attempted only after a language-selection failure. It does not
retry a rejected `speak` request because that can have different causes and a
retry could produce duplicate speech.

## Platform behavior

The fallback policy is enabled only on Android. Other platforms keep the
current single-engine behavior. Platform detection is injected into
`SystemLineSpeaker` so unit tests do not depend on the host operating system.

## Error handling

Plugin calls may return loosely typed values or throw platform exceptions. The
adapter normalizes installed engine values into a list of strings and reports
engine selection as success only when the plugin call completes. Any exception
continues through the existing typed TTS failure path. No device-wide TTS
setting is modified.

## Testing

Unit tests will first establish the missing behavior:

- Android falls back to Google TTS after the current engine rejects the locale.
- Playback proceeds after a successful fallback and uses audio focus.
- No fallback occurs when the original language selection succeeds.
- No fallback occurs on non-Android platforms.
- Missing Google TTS or a failed locale retry produces `TtsPlaybackException`.
- A rejected speech request is not retried through another engine.

Existing widget tests continue to cover the final generic snackbar. After the
focused tests pass, run the complete Flutter test suite, static analysis, build
an APK, install it on the connected Samsung device, and verify Japanese speech
from the same conversation speaker button.

## Scope

This change does not add cloud speech, download voice data, change app copy,
alter device-wide settings, or redesign the conversation UI.
