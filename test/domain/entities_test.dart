import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';

void main() {
  test('Country: dbValue 왕복, 프롬프트·TTS 메타데이터', () {
    expect(Country.fromDb('JP'), Country.japan);
    expect(Country.japan.targetLanguage, 'Japanese');
    expect(Country.japan.romanizationSystem, 'Hepburn romaji');
    expect(Country.korea.ttsLocale, 'ko-KR');
    expect(Country.china.nameLocal, '中国');
    expect(() => Country.fromDb('XX'), throwsArgumentError);
  });

  test('NativeLanguage: 8종, 손상 값은 english 폴백', () {
    expect(NativeLanguage.values.length, 8);
    expect(NativeLanguage.fromDb('ko'), NativeLanguage.korean);
    expect(NativeLanguage.fromDb('garbage'), NativeLanguage.english);
    expect(NativeLanguage.korean.promptName, 'Korean');
  });
}
