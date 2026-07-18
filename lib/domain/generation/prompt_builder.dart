import '../catalog/phrase_catalog.dart';
import '../entities/city.dart';
import '../entities/country.dart';
import '../entities/native_language.dart';

class PromptBuilder {
  /// 언어 혼입을 막는 명시적 언어 규칙 + JSON 뼈대 + 형식 예시 1줄 구조
  /// (sensei 2026-07-15 프롬프트 실험 결론 계승).
  static String build({
    required Country country,
    required City city,
    required PhraseCategory category,
    required Subtopic subtopic,
    required NativeLanguage nativeLanguage,
  }) {
    final target = country.targetLanguage;
    final native = nativeLanguage.promptName;
    final sameLanguage = _isSameLanguage(country, nativeLanguage);
    final transliterationRule = sameLanguage
        ? '- "transliteration": the target language and the traveler\'s language are the same — copy "text" unchanged.'
        : '- "transliteration": rewrite the pronunciation of "text" using $native '
              'orthography so a $native speaker can read it aloud. '
              'Use only $native script. Do not use Latin letters unless $native uses them.';
    final translationRule = sameLanguage
        ? '- "translation": the languages are the same — copy "text" unchanged.'
        : '- "translation": a natural $native translation of "text". $native only.';

    return '''
You are a phrasebook writer for travelers. Write one natural $target conversation between speaker 1 (a traveler visiting ${city.nameEn}, ${country.labelEn}) and speaker 2 (a local, e.g. staff or passer-by).

## Scene
- Situation: ${category.labelEn} — ${subtopic.labelEn}
- Details: ${subtopic.promptHint}
- Location: ${city.nameEn} (${city.nameLocal})

## Style
- Survival phrases for a 1-week trip: short, practical, polite everyday speech.
- One piece of information per sentence. No slang, no rare vocabulary.

## Language rules (must follow)
- "text": $target sentences only. Never mix other languages or scripts.
- "romanization": the ${country.romanizationSystem} romanization of "text".
$transliterationRule
$translationRule
- Do not repeat the same sentence or phrase.

## Line format example (format reference only — do NOT copy its content)
{"speaker": 1, "text": "<one $target sentence>", "romanization": "<${country.romanizationSystem} romanization of text>", "transliteration": "<pronunciation of text written for a $native reader>", "translation": "<natural $native translation of text>"}

## Output
Output only the completed JSON below, no explanations. Put 8 to 12 lines in "lines", speakers 1 and 2 alternating, starting with speaker 1.
{
  "lines": []
}
''';
  }

  /// 여행 대상국 언어와 모국어가 같으면 음차·번역이 무의미하다.
  static bool _isSameLanguage(Country country, NativeLanguage native) =>
      (country == Country.korea && native == NativeLanguage.korean) ||
      (country == Country.japan && native == NativeLanguage.japanese) ||
      (country == Country.china && native == NativeLanguage.chinese);
}
