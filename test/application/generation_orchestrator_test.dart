import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/application/generation_orchestrator.dart';
import 'package:kjc_7day_chat/domain/catalog/phrase_catalog.dart';
import 'package:kjc_7day_chat/domain/entities/country.dart';
import 'package:kjc_7day_chat/domain/entities/native_language.dart';
import 'package:kjc_7day_chat/domain/providers/text_gen_provider.dart';
import 'package:kjc_7day_chat/infrastructure/db/conversation_repository.dart';
import 'package:kjc_7day_chat/infrastructure/fake/fake_text_gen_provider.dart';
import 'package:kjc_7day_chat/infrastructure/seed/cities_seed.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

const _validJson = '''
{"lines": [
  {"speaker": 1, "text": "すみません。", "romanization": "sumimasen.", "transliteration": "스미마셍", "translation": "실례합니다."},
  {"speaker": 2, "text": "はい、どうぞ。", "romanization": "hai, douzo.", "transliteration": "하이, 도조", "translation": "네, 말씀하세요."},
  {"speaker": 1, "text": "チェックインをお願いします。", "romanization": "chekkuin o onegaishimasu.", "transliteration": "첵쿠인 오 오네가이시마스", "translation": "체크인 부탁합니다."},
  {"speaker": 2, "text": "お名前をお願いします。", "romanization": "onamae o onegaishimasu.", "transliteration": "오나마에 오 오네가이시마스", "translation": "성함 부탁드립니다."},
  {"speaker": 1, "text": "キムです。", "romanization": "kimu desu.", "transliteration": "키무데스", "translation": "김입니다."},
  {"speaker": 2, "text": "確認できました。", "romanization": "kakunin dekimashita.", "transliteration": "카쿠닌 데키마시타", "translation": "확인되었습니다."},
  {"speaker": 1, "text": "ありがとうございます。", "romanization": "arigatou gozaimasu.", "transliteration": "아리가토 고자이마스", "translation": "감사합니다."},
  {"speaker": 2, "text": "ごゆっくりお過ごしください。", "romanization": "goyukkuri osugoshi kudasai.", "transliteration": "고유쿠리 오스고시 쿠다사이", "translation": "편안히 쉬세요."}
]}
''';

class _SequenceTextGen implements TextGenProvider {
  _SequenceTextGen(this._responses);

  final List<String> _responses;
  final prompts = <String>[];

  @override
  String get name => 'sequence';

  @override
  Future<String> generate(String prompt) async {
    prompts.add(prompt);
    return _responses[prompts.length - 1];
  }
}

class _ThrowingTextGen implements TextGenProvider {
  var callCount = 0;

  @override
  String get name => 'throwing';

  @override
  Future<String> generate(String prompt) async {
    callCount++;
    throw StateError('provider failed');
  }
}

void main() {
  late Database db;
  late ConversationRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = ConversationRepository(db);
  });
  tearDown(() async => db.close());

  final tokyo = citiesSeed.firstWhere((city) => city.nameEn == 'Tokyo');

  GenerationOrchestrator make(TextGenProvider textGen) =>
      GenerationOrchestrator(
        textGen: textGen,
        repo: repo,
        model: 'test-model',
        now: () => DateTime.utc(2026, 7, 18),
      );

  Future<int> run(GenerationOrchestrator orchestrator) =>
      orchestrator.generateAndSave(
        country: Country.japan,
        city: tokyo,
        category: findCategory('hotel'),
        subtopic: findSubtopic('hotel', 'check-in'),
        nativeLanguage: NativeLanguage.korean,
      );

  test('generates, parses, and saves metadata and indexed lines', () async {
    final id = await run(make(FakeTextGenProvider(_validJson)));

    final detail = await repo.load(id);
    expect(detail.conversation.country, Country.japan);
    expect(detail.conversation.cityId, tokyo.id);
    expect(detail.conversation.cityName, 'Tokyo');
    expect(detail.conversation.categoryId, 'hotel');
    expect(detail.conversation.subtopicId, 'check-in');
    expect(
      detail.conversation.subtopicLabel,
      'Check-in (with or without a reservation)',
    );
    expect(detail.conversation.nativeLang, NativeLanguage.korean);
    expect(detail.conversation.model, 'test-model');
    expect(detail.conversation.createdAt, DateTime.utc(2026, 7, 18));
    expect(detail.lines, hasLength(8));
    expect(detail.lines.map((line) => line.lineOrder), [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]);
    expect(detail.lines.first.targetText, 'すみません。');
    expect(detail.lines.first.romanization, 'sumimasen.');
    expect(detail.lines.first.transliteration, '스미마셍');
    expect(detail.lines.first.translation, '실례합니다.');
  });

  test('retries once with a correction after an invalid response', () async {
    final textGen = _SequenceTextGen(['{"lines": [broken', _validJson]);

    final id = await run(make(textGen));

    expect(textGen.prompts, hasLength(2));
    expect(textGen.prompts[1], startsWith(textGen.prompts[0]));
    expect(textGen.prompts[1], contains('previous response was invalid'));
    expect((await repo.load(id)).lines, hasLength(8));
  });

  test('does not save when the retry response is also invalid', () async {
    final textGen = _SequenceTextGen([
      '{"lines": [broken',
      '{"lines": [still broken',
    ]);

    await expectLater(run(make(textGen)), throwsFormatException);

    expect(textGen.prompts, hasLength(2));
    expect(await repo.listAll(), isEmpty);
  });

  test('propagates provider errors without retrying or saving', () async {
    final textGen = _ThrowingTextGen();

    await expectLater(run(make(textGen)), throwsStateError);

    expect(textGen.callCount, 1);
    expect(await repo.listAll(), isEmpty);
  });
}
