import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS application target is generated with the supported deployment target',
    () {
      expect(Directory('ios/Runner.xcodeproj').existsSync(), isTrue);

      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(project, contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;'));
    },
  );

  test('iOS app metadata and launcher configuration are present', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(info, contains('<key>CFBundleDisplayName</key>'));
    expect(info, contains('<string>KJC 7-Day Trip</string>'));
    expect(info, isNot(contains('NSMicrophoneUsageDescription')));
    expect(podfile, contains("platform :ios, '13.0'"));
    expect(pubspec, contains('ios: true'));
    expect(pubspec, contains('assets/branding/kjc_launcher_icon.png'));
    expect(
      File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      ).existsSync(),
      isTrue,
    );
  });

  test('iOS is included in the mobile TTS provider selection', () {
    final providers = File('lib/providers.dart').readAsStringSync();

    expect(providers, contains('Platform.isAndroid || Platform.isIOS'));
  });
}
