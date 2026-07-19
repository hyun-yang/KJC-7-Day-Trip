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
        File(
          'android/app/src/main/res/mipmap-$density/ic_launcher.png',
        ).existsSync(),
        isTrue,
      );
    }
  });

  test(
    'Android launch themes show KJC branding instead of Flutter branding',
    () {
      final dayV31 = File('android/app/src/main/res/values-v31/styles.xml');
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
        expect(xml, isNot(contains('android:postSplashScreenTheme')));
      }
      expect(legacy, contains('@color/kjc_launch_background'));
      expect(legacy, contains('@drawable/ic_launcher_foreground'));
      expect(legacy, isNot(contains('@mipmap/ic_launcher')));
      expect(legacy, isNot(contains('@android:color/white')));
    },
  );
}
