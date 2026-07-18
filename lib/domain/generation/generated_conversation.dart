import 'dart:convert';

import '../entities/country.dart';

class GeneratedLine {
  const GeneratedLine({
    required this.speaker,
    required this.text,
    required this.romanization,
    required this.transliteration,
    required this.translation,
  });

  final int speaker;
  final String text;
  final String romanization;
  final String transliteration;
  final String translation;
}

class GeneratedConversation {
  GeneratedConversation({required List<GeneratedLine> lines})
    : lines = List<GeneratedLine>.unmodifiable(lines);

  static const _minimumLineCount = 8;
  static const _maximumLineCount = 12;

  static final _hangul = RegExp(r'[가-힣]');
  static final _kana = RegExp(r'[ぁ-ゖァ-ヺー]');
  static final _han = RegExp(r'[一-鿿]');

  final List<GeneratedLine> lines;

  static GeneratedConversation parse(String raw, Country country) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('response is not valid JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('top level is not a JSON object');
    }

    final rawLines = decoded['lines'];
    if (rawLines is! List ||
        rawLines.length < _minimumLineCount ||
        rawLines.length > _maximumLineCount) {
      throw FormatException(
        'lines must have $_minimumLineCount-$_maximumLineCount entries',
      );
    }

    final lines = <GeneratedLine>[];
    for (final rawLine in rawLines) {
      if (rawLine is! Map<String, dynamic>) {
        throw const FormatException('line is not a JSON object');
      }

      final speaker = rawLine['speaker'];
      if (speaker is! int || (speaker != 1 && speaker != 2)) {
        throw const FormatException('speaker must be 1 or 2');
      }

      final text = _requireText(rawLine, 'text');
      _validateTargetLanguage(text, country);
      lines.add(
        GeneratedLine(
          speaker: speaker,
          text: text,
          romanization: _requireText(rawLine, 'romanization'),
          transliteration: _requireText(rawLine, 'transliteration'),
          translation: _requireText(rawLine, 'translation'),
        ),
      );
    }

    if (lines.map((line) => line.speaker).toSet().length != 2) {
      throw const FormatException('both speakers 1 and 2 must appear');
    }
    if (country == Country.japan &&
        !lines.any((line) => _kana.hasMatch(line.text))) {
      throw const FormatException(
        'Japanese conversation must contain at least one kana character',
      );
    }

    return GeneratedConversation(lines: lines);
  }

  static String _requireText(Map<String, dynamic> line, String field) {
    final value = line[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a non-empty string');
    }
    return value;
  }

  static void _validateTargetLanguage(String text, Country country) {
    switch (country) {
      case Country.korea:
        if (!_hangul.hasMatch(text)) {
          throw FormatException('Korean text must contain Hangul: $text');
        }
        if (_kana.hasMatch(text)) {
          throw FormatException('Korean text contains kana: $text');
        }
      case Country.japan:
        if (_hangul.hasMatch(text)) {
          throw FormatException('Japanese text contains Hangul: $text');
        }
        if (!_kana.hasMatch(text) && !_han.hasMatch(text)) {
          throw FormatException(
            'Japanese text must contain kana or Han: $text',
          );
        }
      case Country.china:
        if (_hangul.hasMatch(text) || _kana.hasMatch(text)) {
          throw FormatException('Chinese text contains Hangul or kana: $text');
        }
        if (!_han.hasMatch(text)) {
          throw FormatException('Chinese text must contain Han: $text');
        }
    }
  }
}
