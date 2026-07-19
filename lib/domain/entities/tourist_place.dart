class RecommendedScene {
  const RecommendedScene({
    required this.categoryId,
    required this.subtopicId,
    required this.labelEn,
  });

  final String categoryId;
  final String subtopicId;
  final String labelEn;
}

class TouristPlace {
  TouristPlace({
    required this.id,
    required this.cityId,
    required this.nameEn,
    required this.nameLocal,
    required this.descriptionEn,
    required this.mapX,
    required this.mapY,
    required List<RecommendedScene> recommendedScenes,
  }) : recommendedScenes = List.unmodifiable(recommendedScenes) {
    if (recommendedScenes.length != 3) {
      throw ArgumentError.value(
        recommendedScenes.length,
        'recommendedScenes',
        'A tourist place must have exactly three recommended scenes.',
      );
    }
  }

  final int id;
  final int cityId;
  final String nameEn;
  final String nameLocal;
  final String descriptionEn;
  final double mapX;
  final double mapY;
  final List<RecommendedScene> recommendedScenes;
}
