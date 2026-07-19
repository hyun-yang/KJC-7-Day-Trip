import '../domain/catalog/phrase_catalog.dart';
import '../domain/entities/city.dart';
import '../domain/entities/conversation.dart';
import '../domain/entities/country.dart';
import '../domain/entities/native_language.dart';
import '../domain/entities/tourist_place.dart';
import '../domain/generation/generated_conversation.dart';
import '../domain/generation/prompt_builder.dart';
import '../domain/providers/text_gen_provider.dart';
import '../infrastructure/db/conversation_repository.dart';

class GenerationOrchestrator {
  GenerationOrchestrator({
    required TextGenProvider textGen,
    required ConversationRepository repo,
    required String model,
    DateTime Function()? now,
  }) : _textGen = textGen,
       _repo = repo,
       _model = model,
       _now = now ?? DateTime.now;

  final TextGenProvider _textGen;
  final ConversationRepository _repo;
  final String _model;
  final DateTime Function() _now;

  Future<int> generateAndSave({
    required Country country,
    required City city,
    required PhraseCategory category,
    required Subtopic subtopic,
    required NativeLanguage nativeLanguage,
    TouristPlace? place,
  }) async {
    final prompt = PromptBuilder.build(
      country: country,
      city: city,
      category: category,
      subtopic: subtopic,
      nativeLanguage: nativeLanguage,
      place: place,
    );

    GeneratedConversation generated;
    final raw = await _textGen.generate(prompt);
    try {
      generated = GeneratedConversation.parse(raw, country);
    } on FormatException catch (error) {
      final retryPrompt =
          '$prompt\n\n'
          'The previous response was invalid (${error.message}). '
          'Output only the JSON in the specified schema, no explanations.';
      final retryRaw = await _textGen.generate(retryPrompt);
      generated = GeneratedConversation.parse(retryRaw, country);
    }

    return _repo.insert(
      Conversation(
        placeId: place?.id,
        placeName: place?.nameEn,
        country: country,
        cityId: city.id,
        cityName: city.nameEn,
        categoryId: category.id,
        subtopicId: subtopic.id,
        subtopicLabel: subtopic.labelEn,
        nativeLang: nativeLanguage,
        model: _model,
        createdAt: _now(),
      ),
      [
        for (final (index, line) in generated.lines.indexed)
          ConvLine(
            lineOrder: index,
            speaker: line.speaker,
            targetText: line.text,
            romanization: line.romanization,
            transliteration: line.transliteration,
            translation: line.translation,
          ),
      ],
    );
  }
}
