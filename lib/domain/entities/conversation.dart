import 'country.dart';
import 'native_language.dart';

class Conversation {
  const Conversation({
    this.id,
    this.placeId,
    this.placeName,
    required this.country,
    required this.cityId,
    required this.cityName,
    required this.categoryId,
    required this.subtopicId,
    required this.subtopicLabel,
    required this.nativeLang,
    required this.model,
    required this.createdAt,
  });

  final int? id;
  final int? placeId;
  final String? placeName;
  final Country country;
  final int cityId;
  final String cityName;
  final String categoryId;
  final String subtopicId;
  final String subtopicLabel;
  final NativeLanguage nativeLang;
  final String model;
  final DateTime createdAt;
}

class ConvLine {
  const ConvLine({
    this.id,
    this.conversationId,
    required this.lineOrder,
    required this.speaker,
    required this.targetText,
    required this.romanization,
    required this.transliteration,
    required this.translation,
  });

  final int? id;
  final int? conversationId;
  final int lineOrder;

  /// 1 = 여행자, 2 = 현지인.
  final int speaker;
  final String targetText;
  final String romanization;
  final String transliteration;
  final String translation;
}

class ConversationDetail {
  const ConversationDetail({required this.conversation, required this.lines});

  final Conversation conversation;
  final List<ConvLine> lines;
}
