import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/catalog/phrase_catalog.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/domain/generation/prompt_builder.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';

void main() {
  final tokyo = citiesSeed.firstWhere((city) => city.nameEn == 'Tokyo');

  test('일본×한국어: 언어·로마자 체계·장면·모국어가 프롬프트에 명시된다', () {
    final prompt = PromptBuilder.build(
      country: Country.japan,
      city: tokyo,
      category: findCategory('hotel'),
      subtopic: findSubtopic('hotel', 'check-in'),
      nativeLanguage: NativeLanguage.korean,
    );
    expect(prompt, contains('Write one natural Japanese conversation'));
    expect(prompt, contains('Hepburn romaji'));
    expect(prompt, contains('Korean'));
    expect(prompt, contains('Tokyo'));
    expect(prompt, contains('checking in with a reservation'));
    expect(prompt, contains('"lines"'));
    expect(prompt, contains('8 to 12 lines'));
  });

  test('일본어가 아닌 대상 언어 프롬프트에는 일본어 예시가 없다', () {
    final seoul = citiesSeed.firstWhere((city) => city.nameEn == 'Seoul');
    final prompt = PromptBuilder.build(
      country: Country.korea,
      city: seoul,
      category: findCategory('basics'),
      subtopic: findSubtopic('basics', 'greeting'),
      nativeLanguage: NativeLanguage.english,
    );

    expect(prompt, isNot(contains('すみません')));
    expect(prompt, isNot(contains('sumimasen')));
    expect(prompt, isNot(matches(RegExp(r'[ぁ-んァ-ン]'))));
  });

  test('같은 언어 여행(한국×한국어): 음차 규칙이 복사 지시로 바뀐다', () {
    final seoul = citiesSeed.firstWhere((city) => city.nameEn == 'Seoul');
    final prompt = PromptBuilder.build(
      country: Country.korea,
      city: seoul,
      category: findCategory('basics'),
      subtopic: findSubtopic('basics', 'greeting'),
      nativeLanguage: NativeLanguage.korean,
    );
    expect(prompt, contains('copy "text" unchanged'));
  });
}
