import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/infrastructure/online/json_extractor.dart';

void main() {
  test('마크다운 펜스와 설명문에서 첫 JSON 객체를 추출한다', () {
    expect(
      extractJsonObject('설명\n```json\n{"a": 1}\n```\n{"b": 2}'),
      '{"a": 1}',
    );
  });

  test('중첩 객체와 문자열 안의 중괄호 및 이스케이프를 구분한다', () {
    expect(
      extractJsonObject(r'''prefix {"a": {"b": "} \" {"}} suffix'''),
      r'''{"a": {"b": "} \" {"}}''',
    );
  });

  test('JSON 객체가 없으면 FormatException을 던진다', () {
    expect(() => extractJsonObject('no json'), throwsFormatException);
  });

  test('JSON 객체가 끝나지 않으면 FormatException을 던진다', () {
    expect(() => extractJsonObject('{"a": 1'), throwsFormatException);
  });
}
