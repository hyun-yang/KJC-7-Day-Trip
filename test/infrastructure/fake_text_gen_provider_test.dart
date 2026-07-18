import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/infrastructure/fake/fake_text_gen_provider.dart';

void main() {
  test('고정 응답을 반환하고 호출한 프롬프트를 순서대로 기록한다', () async {
    final provider = FakeTextGenProvider('{"lines": []}');

    expect(provider.name, 'fake');
    expect(await provider.generate('first'), '{"lines": []}');
    expect(await provider.generate('second'), '{"lines": []}');
    expect(provider.prompts, ['first', 'second']);
  });
}
