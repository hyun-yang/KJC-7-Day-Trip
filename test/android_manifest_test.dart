import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest exposes process-text and TTS service queries', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.intent.action.PROCESS_TEXT'));
    expect(manifest, contains('android.intent.action.TTS_SERVICE'));
  });

  test(
    'Android release manifest can reach OpenAI and uses the product name',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('android:label="KJC 7-Day Trip"'));
    },
  );
}
