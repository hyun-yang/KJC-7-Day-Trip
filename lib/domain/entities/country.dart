/// 여행 대상국. dbValue는 DB·설정 직렬화 키.
enum Country {
  korea('KR', 'Korea', '한국', '🇰🇷', 'Korean', 'Revised Romanization', 'ko-KR'),
  japan('JP', 'Japan', '日本', '🇯🇵', 'Japanese', 'Hepburn romaji', 'ja-JP'),
  china(
    'CN',
    'China',
    '中国',
    '🇨🇳',
    'Mandarin Chinese',
    'Hanyu Pinyin',
    'zh-CN',
  );

  const Country(
    this.dbValue,
    this.labelEn,
    this.nameLocal,
    this.flag,
    this.targetLanguage,
    this.romanizationSystem,
    this.ttsLocale,
  );

  final String dbValue;
  final String labelEn;
  final String nameLocal;
  final String flag;

  /// 프롬프트에 쓰는 대상 언어 이름 (영어).
  final String targetLanguage;

  /// 프롬프트에 쓰는 로마자 표기 체계 이름.
  final String romanizationSystem;

  /// flutter_tts 로케일.
  final String ttsLocale;

  static Country fromDb(String value) => values.firstWhere(
    (country) => country.dbValue == value,
    orElse: () => throw ArgumentError('unknown Country: $value'),
  );
}
