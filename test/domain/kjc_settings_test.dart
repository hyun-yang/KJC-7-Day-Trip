import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/domain/settings/kjc_settings.dart';

void main() {
  test('defaults use English and the exact supported model list', () {
    const settings = KjcSettings();

    expect(settings.nativeLanguage, NativeLanguage.english);
    expect(settings.openaiModel, kDefaultOpenAiModel);
    expect(kOpenAiModels, const [
      'gpt-5.5',
      'gpt-5.4',
      'gpt-5.4-mini',
      'gpt-5.4-nano',
      'gpt-5-mini',
    ]);
    expect(kDefaultOpenAiModel, 'gpt-5.4-mini');
    expect(kOpenAiModels, isNot(contains('gpt-5.6')));
    expect(kOpenAiModels.where((model) => model.startsWith('gpt-3')), isEmpty);
  });

  test('copyWith and JSON conversion round-trip settings', () {
    final settings = const KjcSettings().copyWith(
      nativeLanguage: NativeLanguage.korean,
      openaiModel: kOpenAiModels.first,
    );

    expect(settings.toJson(), {
      'nativeLanguage': NativeLanguage.korean.dbValue,
      'openaiModel': kOpenAiModels.first,
    });

    final restored = KjcSettings.fromJson(settings.toJson());
    expect(restored.nativeLanguage, NativeLanguage.korean);
    expect(restored.openaiModel, kOpenAiModels.first);
  });

  test('invalid JSON fields fall back independently', () {
    final invalidLanguage = KjcSettings.fromJson({
      'nativeLanguage': 'xx',
      'openaiModel': kOpenAiModels.first,
    });
    final invalidModel = KjcSettings.fromJson({
      'nativeLanguage': NativeLanguage.french.dbValue,
      'openaiModel': 'not-a-model',
    });

    expect(invalidLanguage.nativeLanguage, NativeLanguage.english);
    expect(invalidLanguage.openaiModel, kOpenAiModels.first);
    expect(invalidModel.nativeLanguage, NativeLanguage.french);
    expect(invalidModel.openaiModel, kDefaultOpenAiModel);
  });
}
