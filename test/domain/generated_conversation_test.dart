import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/domain/generation/generated_conversation.dart';

Map<String, Object> generatedLine(int speaker, String text) => {
  'speaker': speaker,
  'text': text,
  'romanization': 'romanization',
  'transliteration': 'transliteration',
  'translation': 'translation',
};

String conversation(List<Object> lines) => jsonEncode({'lines': lines});

List<Object> validLines(String speakerOneText, String speakerTwoText) => [
  generatedLine(1, speakerOneText),
  generatedLine(2, speakerTwoText),
  generatedLine(1, speakerOneText),
  generatedLine(2, speakerTwoText),
  generatedLine(1, speakerOneText),
  generatedLine(2, speakerTwoText),
  generatedLine(1, speakerOneText),
  generatedLine(2, speakerTwoText),
];

void main() {
  test('parses a valid Japanese conversation and all generated fields', () {
    final parsed = GeneratedConversation.parse(
      conversation(validLines('すみません。', 'はい、どうぞ。')),
      Country.japan,
    );

    expect(parsed.lines, hasLength(8));
    expect(parsed.lines.first.speaker, 1);
    expect(parsed.lines.first.text, 'すみません。');
    expect(parsed.lines.first.romanization, 'romanization');
    expect(parsed.lines.first.transliteration, 'transliteration');
    expect(parsed.lines.first.translation, 'translation');
  });

  test('accepts exactly 8 and exactly 12 lines', () {
    final eightLines = validLines('あ', 'い');
    final twelveLines = [
      ...eightLines,
      generatedLine(1, 'あ'),
      generatedLine(2, 'い'),
      generatedLine(1, 'あ'),
      generatedLine(2, 'い'),
    ];

    expect(
      GeneratedConversation.parse(
        conversation(eightLines),
        Country.japan,
      ).lines,
      hasLength(8),
    );
    expect(
      GeneratedConversation.parse(
        conversation(twelveLines),
        Country.japan,
      ).lines,
      hasLength(12),
    );
  });

  test('rejects 7 and 13 lines', () {
    final sevenLines = validLines('あ', 'い').take(7).toList();
    final thirteenLines = [
      ...validLines('あ', 'い'),
      generatedLine(1, 'あ'),
      generatedLine(2, 'い'),
      generatedLine(1, 'あ'),
      generatedLine(2, 'い'),
      generatedLine(1, 'あ'),
    ];

    expect(
      () =>
          GeneratedConversation.parse(conversation(sevenLines), Country.japan),
      throwsFormatException,
    );
    expect(
      () => GeneratedConversation.parse(
        conversation(thirteenLines),
        Country.japan,
      ),
      throwsFormatException,
    );
  });

  test('defensively copies lines and exposes an unmodifiable list', () {
    const line = GeneratedLine(
      speaker: 1,
      text: 'すみません。',
      romanization: 'sumimasen',
      transliteration: 'sumimasen',
      translation: 'excuse me',
    );
    final source = <GeneratedLine>[line];
    final conversation = GeneratedConversation(lines: source);

    source.clear();

    expect(conversation.lines, [line]);
    expect(() => conversation.lines.add(line), throwsUnsupportedError);
    expect(conversation.lines.clear, throwsUnsupportedError);
  });

  test('rejects invalid JSON, top level, lines shape, and line objects', () {
    expect(
      () => GeneratedConversation.parse('{', Country.japan),
      throwsFormatException,
    );
    expect(
      () => GeneratedConversation.parse('[]', Country.japan),
      throwsFormatException,
    );
    expect(
      () => GeneratedConversation.parse('{}', Country.japan),
      throwsFormatException,
    );
    expect(
      () => GeneratedConversation.parse(
        jsonEncode({'lines': 'not a list'}),
        Country.japan,
      ),
      throwsFormatException,
    );
    expect(
      () => GeneratedConversation.parse(
        conversation(validLines('あ', 'い').take(7).toList()),
        Country.japan,
      ),
      throwsFormatException,
    );
    expect(
      () => GeneratedConversation.parse(
        conversation(List<Object>.generate(13, (_) => generatedLine(1, 'あ'))),
        Country.japan,
      ),
      throwsFormatException,
    );

    final linesWithNonObject = validLines('あ', 'い');
    linesWithNonObject[0] = 'not an object';
    expect(
      () => GeneratedConversation.parse(
        conversation(linesWithNonObject),
        Country.japan,
      ),
      throwsFormatException,
    );
  });

  test('requires integer speakers 1 and 2 and requires both to appear', () {
    final badSpeaker = validLines('あ', 'い');
    (badSpeaker[0] as Map<String, Object>)['speaker'] = 3;
    expect(
      () =>
          GeneratedConversation.parse(conversation(badSpeaker), Country.japan),
      throwsFormatException,
    );

    final nonIntegerSpeaker = validLines('あ', 'い');
    (nonIntegerSpeaker[0] as Map<String, Object>)['speaker'] = '1';
    expect(
      () => GeneratedConversation.parse(
        conversation(nonIntegerSpeaker),
        Country.japan,
      ),
      throwsFormatException,
    );

    expect(
      () => GeneratedConversation.parse(
        conversation(List<Object>.generate(8, (_) => generatedLine(1, 'あ'))),
        Country.japan,
      ),
      throwsFormatException,
    );
  });

  test('requires every string field to be non-empty after trimming', () {
    for (final field in [
      'text',
      'romanization',
      'transliteration',
      'translation',
    ]) {
      final lines = validLines('あ', 'い');
      (lines[0] as Map<String, Object>)[field] = '   ';

      expect(
        () => GeneratedConversation.parse(conversation(lines), Country.japan),
        throwsFormatException,
        reason: '$field must reject whitespace-only values',
      );
    }
  });

  test('validates Korean text and rejects kana contamination', () {
    expect(
      GeneratedConversation.parse(
        conversation(validLines('실례합니다.', '네, 말씀하세요.')),
        Country.korea,
      ).lines,
      hasLength(8),
    );
    expect(
      () => GeneratedConversation.parse(
        conversation(validLines('실례합니다す', '네.')),
        Country.korea,
      ),
      throwsFormatException,
    );
    expect(
      () => GeneratedConversation.parse(
        conversation(validLines('hello', '네.')),
        Country.korea,
      ),
      throwsFormatException,
    );
  });

  test(
    'validates Japanese text and rejects contamination or all-Han output',
    () {
      expect(
        () => GeneratedConversation.parse(
          conversation(validLines('すみません 실례합니다', 'はい。')),
          Country.japan,
        ),
        throwsFormatException,
      );
      expect(
        () => GeneratedConversation.parse(
          conversation(validLines('hello', 'はい。')),
          Country.japan,
        ),
        throwsFormatException,
      );
      expect(
        () => GeneratedConversation.parse(
          conversation(validLines('入場券', '大人二枚')),
          Country.japan,
        ),
        throwsFormatException,
      );
    },
  );

  test('validates Chinese text and rejects Hangul or kana contamination', () {
    expect(
      GeneratedConversation.parse(
        conversation(validLines('不好意思，请问。', '好的，请说。')),
        Country.china,
      ).lines,
      hasLength(8),
    );
    expect(
      () => GeneratedConversation.parse(
        conversation(validLines('不好意思한', '好的。')),
        Country.china,
      ),
      throwsFormatException,
    );
    expect(
      () => GeneratedConversation.parse(
        conversation(validLines('不好意思の', '好的。')),
        Country.china,
      ),
      throwsFormatException,
    );
    expect(
      () => GeneratedConversation.parse(
        conversation(validLines('hello', '好的。')),
        Country.china,
      ),
      throwsFormatException,
    );
  });
}
