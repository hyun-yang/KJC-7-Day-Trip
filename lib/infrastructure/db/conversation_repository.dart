import 'package:sqflite/sqflite.dart';
import '../../domain/entities/conversation.dart';
import 'row_mappers.dart';

class ConversationRepository {
  const ConversationRepository(this._db);
  final Database _db;
  Future<int> insert(Conversation c, List<ConvLine> lines) =>
      _db.transaction((txn) async {
        final id = await txn.insert('conversations', conversationToRow(c));
        for (final l in lines) {
          await txn.insert(
            'lines',
            lineToRow(
              ConvLine(
                conversationId: id,
                lineOrder: l.lineOrder,
                speaker: l.speaker,
                targetText: l.targetText,
                romanization: l.romanization,
                transliteration: l.transliteration,
                translation: l.translation,
              ),
            ),
          );
        }
        return id;
      });
  Future<List<Conversation>> listAll() async => (await _db.query(
    'conversations',
    orderBy: 'created_at DESC, id DESC',
  )).map(conversationFromRow).toList();
  Future<ConversationDetail> load(int id) async {
    final c = await _db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (c.isEmpty) throw StateError('conversation not found: $id');
    final l = await _db.query(
      'lines',
      where: 'conversation_id = ?',
      whereArgs: [id],
      orderBy: 'line_order',
    );
    return ConversationDetail(
      conversation: conversationFromRow(c.first),
      lines: l.map(lineFromRow).toList(),
    );
  }

  Future<void> delete(int id) async {
    await _db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }
}
