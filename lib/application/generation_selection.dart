import '../domain/catalog/phrase_catalog.dart';
import '../domain/entities/city.dart';
import '../domain/entities/tourist_place.dart';

/// The complete, typed choice made before conversation generation begins.
class GenerationSelection {
  const GenerationSelection({
    required this.city,
    required this.category,
    required this.subtopic,
    this.place,
  });

  final City city;
  final PhraseCategory category;
  final Subtopic subtopic;
  final TouristPlace? place;
}
