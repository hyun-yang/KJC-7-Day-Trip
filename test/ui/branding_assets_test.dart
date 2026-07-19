import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  const fullIconPath = 'assets/branding/kjc_launcher_icon.svg';
  const foregroundPath = 'assets/branding/kjc_launcher_foreground.svg';

  test('launcher source is a white KJC-only icon', () {
    final source = File(fullIconPath).readAsStringSync();

    expect(source, contains('id="icon-background"'));
    expect(source, contains('fill="#FFFFFF"'));
    expect(source, contains('id="letter-k"'));
    expect(source, contains('id="letter-j"'));
    expect(source, contains('id="letter-c"'));
    expect(source, isNot(contains('#F7F4EE')));
    expect(source, isNot(contains('#2D6B5C')));
    expect(source, isNot(contains('#164C3F')));
  });

  test('K is split into Taegeuk colors and J and C use flag reds', () {
    for (final path in [fullIconPath, foregroundPath]) {
      final source = File(path).readAsStringSync();

      expect(source, contains('id="k-top"'));
      expect(source, contains('fill="#CD2E3A"'));
      expect(source, contains('id="k-bottom"'));
      expect(source, contains('fill="#0047A0"'));
      expect(source, contains('id="letter-j"'));
      expect(source, contains('fill="#BC002D"'));
      expect(source, contains('id="letter-c"'));
      expect(source, contains('stroke="#DE2910"'));
    }
  });

  test('Android icon configuration uses the white KJC artwork', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains("adaptive_icon_background: '#FFFFFF'"));
    expect(
      pubspec,
      contains('image_path: assets/branding/kjc_launcher_icon.png'),
    );
    expect(
      pubspec,
      contains(
        'adaptive_icon_foreground: '
        'assets/branding/kjc_launcher_foreground.png',
      ),
    );
  });

  test('generated Android launcher contains the four KJC colors', () async {
    final colors = await _pixelColors(
      File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'),
    );

    expect(colors, contains(0xFFFFFFFF));
    expect(colors, contains(0xCD2E3AFF));
    expect(colors, contains(0x0047A0FF));
    expect(colors, contains(0xBC002DFF));
    expect(colors, contains(0xDE2910FF));
  });
}

Future<Set<int>> _pixelColors(File file) async {
  final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  final colors = <int>{};
  for (var offset = 0; offset < bytes.length; offset += 4) {
    colors.add(_rgbaAt(bytes, offset));
  }
  return colors;
}

int _rgbaAt(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
