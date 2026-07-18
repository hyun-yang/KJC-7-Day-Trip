/// 사용자의 모국어(도우미 언어) — 회화의 번역·음차에만 쓰고 UI는 영어 고정.
enum NativeLanguage {
  english('en', 'English', 'English'),
  korean('ko', '한국어', 'Korean'),
  japanese('ja', '日本語', 'Japanese'),
  chinese('zh', '中文(简体)', 'Simplified Chinese'),
  spanish('es', 'Español', 'Spanish'),
  french('fr', 'Français', 'French'),
  german('de', 'Deutsch', 'German'),
  vietnamese('vi', 'Tiếng Việt', 'Vietnamese');

  const NativeLanguage(this.dbValue, this.label, this.promptName);

  final String dbValue;

  /// 설정 화면 표시용 (해당 언어 자체 표기).
  final String label;

  /// 프롬프트에 쓰는 언어 이름 (영어).
  final String promptName;

  /// 설정 파일 손상 방어: 모르는 값은 english.
  static NativeLanguage fromDb(String value) => values.firstWhere(
    (language) => language.dbValue == value,
    orElse: () => NativeLanguage.english,
  );
}
