import '../domain/catalog/phrase_catalog.dart';
import '../domain/entities/city.dart';

/// The complete, typed choice made before conversation generation begins.
class GenerationSelection {
  const GenerationSelection({
    required this.city,
    required this.category,
    required this.subtopic,
  });

  final City city;
  final PhraseCategory category;
  final Subtopic subtopic;
}
