import '../../domain/entities/city.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/native_language.dart';

Map<String, Object?> cityToRow(City c) => {
  'id': c.id,
  'country': c.country.dbValue,
  'name_en': c.nameEn,
  'name_local': c.nameLocal,
  'lat': c.lat,
  'lng': c.lng,
};
City cityFromRow(Map<String, Object?> r) => City(
  id: r['id']! as int,
  country: Country.fromDb(r['country']! as String),
  nameEn: r['name_en']! as String,
  nameLocal: r['name_local']! as String,
  lat: r['lat']! as double,
  lng: r['lng']! as double,
);
Map<String, Object?> conversationToRow(Conversation c) => {
  'country': c.country.dbValue,
  'city_id': c.cityId,
  'city_name': c.cityName,
  'category_id': c.categoryId,
  'subtopic_id': c.subtopicId,
  'subtopic_label': c.subtopicLabel,
  'native_lang': c.nativeLang.dbValue,
  'model': c.model,
  'created_at': c.createdAt.toIso8601String(),
};
Conversation conversationFromRow(Map<String, Object?> r) => Conversation(
  id: r['id']! as int,
  country: Country.fromDb(r['country']! as String),
  cityId: r['city_id']! as int,
  cityName: r['city_name']! as String,
  categoryId: r['category_id']! as String,
  subtopicId: r['subtopic_id']! as String,
  subtopicLabel: r['subtopic_label']! as String,
  nativeLang: NativeLanguage.fromDb(r['native_lang']! as String),
  model: r['model']! as String,
  createdAt: DateTime.parse(r['created_at']! as String),
);
Map<String, Object?> lineToRow(ConvLine l) => {
  'conversation_id': l.conversationId,
  'line_order': l.lineOrder,
  'speaker': l.speaker,
  'target_text': l.targetText,
  'romanization': l.romanization,
  'transliteration': l.transliteration,
  'translation': l.translation,
};
ConvLine lineFromRow(Map<String, Object?> r) => ConvLine(
  id: r['id']! as int,
  conversationId: r['conversation_id']! as int,
  lineOrder: r['line_order']! as int,
  speaker: r['speaker']! as int,
  targetText: r['target_text']! as String,
  romanization: r['romanization']! as String,
  transliteration: r['transliteration']! as String,
  translation: r['translation']! as String,
);
