import '../entities/native_language.dart';

const kOpenAiModels = <String>[
  'gpt-5.5',
  'gpt-5.4',
  'gpt-5.4-mini',
  'gpt-5.4-nano',
  'gpt-5-mini',
];

const kDefaultOpenAiModel = 'gpt-5.4-mini';

class KjcSettings {
  const KjcSettings({
    this.nativeLanguage = NativeLanguage.english,
    this.openaiModel = kDefaultOpenAiModel,
  });

  final NativeLanguage nativeLanguage;
  final String openaiModel;

  KjcSettings copyWith({NativeLanguage? nativeLanguage, String? openaiModel}) {
    return KjcSettings(
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      openaiModel: openaiModel ?? this.openaiModel,
    );
  }

  Map<String, Object?> toJson() => {
    'nativeLanguage': nativeLanguage.dbValue,
    'openaiModel': openaiModel,
  };

  factory KjcSettings.fromJson(Map<String, Object?> json) {
    final nativeLanguage = json['nativeLanguage'];
    final openaiModel = json['openaiModel'];

    return KjcSettings(
      nativeLanguage: nativeLanguage is String
          ? NativeLanguage.fromDb(nativeLanguage)
          : NativeLanguage.english,
      openaiModel: openaiModel is String && kOpenAiModels.contains(openaiModel)
          ? openaiModel
          : kDefaultOpenAiModel,
    );
  }
}
