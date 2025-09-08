// lib/services/tags_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tag.dart';

class TagsService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<List<Tag>> fetchAllForCurrentUser() async {
    final List<dynamic> rows = await _sb
        .from('tags')
        .select('id, name, created_at')
        .order('name', ascending: true);

    return rows
        .map((dynamic r) => Tag.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<Tag>> tagsForNote(int noteId) async {
    // Tag-IDs aus der Mapping-Tabelle holen
    final List<dynamic> idRows = await _sb
        .from('note_tags')
        .select('tag_id')
        .eq('note_id', noteId);

    if (idRows.isEmpty) return <Tag>[];

    final List<int> tagIds =
        idRows.map((dynamic r) => (r['tag_id'] as num).toInt()).toList();

    final List<dynamic> rows =
        await _sb.from('tags').select('id, name').inFilter('id', tagIds);

    return rows
        .map((dynamic r) => Tag.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<Tag> createIfMissing(String name) async {
    // Exakten Treffer versuchen
    final List<dynamic> hit =
        await _sb.from('tags').select('id, name').eq('name', name).limit(1);
    if (hit.isNotEmpty) {
      return Tag.fromMap(hit.first as Map<String, dynamic>);
    }

    // Neu erstellen (user_id per DB-Default/RLS)
    final dynamic inserted = await _sb
        .from('tags')
        .insert(<String, dynamic>{'name': name})
        .select()
        .single();

    return Tag.fromMap(inserted as Map<String, dynamic>);
  }

  Future<void> addTagToNote(int noteId, int tagId) async {
    await _sb.from('note_tags').upsert(
      <String, dynamic>{'note_id': noteId, 'tag_id': tagId},
      onConflict: 'note_id,tag_id',
    );
  }

  Future<void> removeTagFromNote(int noteId, int tagId) async {
    await _sb
        .from('note_tags')
        .delete()
        .eq('note_id', noteId)
        .eq('tag_id', tagId);
  }

  /// Setzt die Tags einer Note exakt auf [tagIds] (fügt fehlende hinzu, entfernt übrige).
  Future<void> setTagsForNote(int noteId, List<int> tagIds) async {
    // Duplikate vermeiden
    final Set<int> desired = tagIds.toSet();

    // Aktuelle Tags lesen
    final List<dynamic> currentRows = await _sb
        .from('note_tags')
        .select('tag_id')
        .eq('note_id', noteId);

    final Set<int> current = currentRows
        .map((dynamic r) => (r['tag_id'] as num).toInt())
        .toSet();

    // Diffs berechnen
    final Set<int> toInsert = desired.difference(current);
    final Set<int> toDelete = current.difference(desired);

    // Entfernen, was nicht mehr gewünscht ist
    if (toDelete.isNotEmpty) {
      await _sb
          .from('note_tags')
          .delete()
          .eq('note_id', noteId)
          .inFilter('tag_id', toDelete.toList());
    }

    // Fehlende hinzufügen (Batch-Insert)
    if (toInsert.isNotEmpty) {
      final List<Map<String, dynamic>> rows = toInsert
          .map((int id) => <String, dynamic>{'note_id': noteId, 'tag_id': id})
          .toList();

      await _sb
          .from('note_tags')
          .upsert(rows, onConflict: 'note_id,tag_id');
    }
  }
}
