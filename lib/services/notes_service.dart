import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';
import '../models/tag.dart';
import 'tags_service.dart';

class NotesService {
  final SupabaseClient _sb = Supabase.instance.client;

  Stream<List<Note>> streamForCurrentUser({
    required bool sortDesc,
    int? groupId,
    bool favOnly = false,
    bool trashedOnly = false,
  }) {
    final String uid = Supabase.instance.client.auth.currentUser!.id;
    final Stream<List<Map<String, dynamic>>> s = Supabase.instance.client
        .from('notes')
        .stream(primaryKey: <String>['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: !sortDesc);

    return s.map((List<Map<String, dynamic>> rows) {
      final List<Note> all = rows.map((Map<String, dynamic> m) => Note.fromMap(m)).toList();
      final List<Note> filtered = all.where((Note n) {
        if (groupId != null && n.groupId != groupId) return false;
        if (favOnly && !n.isFavorite) return false;
        if (trashedOnly && n.deletedAt == null) return false;
        if (!trashedOnly && n.deletedAt != null) return false;
        return true;
      }).toList();
      return filtered;
    });
  }

  Future<int> create(String title, String content, {int? groupId, List<int>? tagIds}) async {
    final List<dynamic> rows = await _sb
        .from('notes')
        .insert(<String, dynamic>{'title': title, 'content': content, 'group_id': groupId})
        .select('id')
        .limit(1);
    final Map<String, dynamic> m = rows.first as Map<String, dynamic>;
    final int noteId = (m['id'] as num).toInt();
    if (tagIds != null) {
      final TagsService tags = TagsService();
      await tags.setTagsForNote(noteId, tagIds);
    }
    return noteId;
  }

  Future<void> update(int id, String title, String content, {int? groupId, List<int>? tagIds}) async {
    await _sb.from('notes').update(<String, dynamic>{'title': title, 'content': content, 'group_id': groupId}).eq('id', id);
    if (tagIds != null) {
      final TagsService tags = TagsService();
      await tags.setTagsForNote(id, tagIds);
    }
  }

  Future<void> duplicate(Note n) async {
    final int newId = await create(n.title, n.content, groupId: n.groupId);
    final TagsService tags = TagsService();
    final List<Tag> t = await tags.tagsForNote(n.id);
    final List<int> tagIds = t.map((Tag e) => e.id).toList();
    if (tagIds.isNotEmpty) await tags.setTagsForNote(newId, tagIds);
  }

  Future<void> moveToTrash(int id) async {
    await _sb.from('notes').update(<String, dynamic>{'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> moveManyToTrash(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await _sb.from('notes').update(<String, dynamic>{'deleted_at': DateTime.now().toUtc().toIso8601String()}).inFilter('id', ids.toList());
  }

  Future<void> restore(int id) async {
    await _sb.from('notes').update(<String, dynamic>{'deleted_at': null}).eq('id', id);
  }

  Future<void> restoreMany(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await _sb.from('notes').update(<String, dynamic>{'deleted_at': null}).inFilter('id', ids.toList());
  }

  Future<void> purge(int id) async {
    await _sb.from('notes').delete().eq('id', id);
  }

  Future<void> purgeTrashedForCurrentUser() async {
    await _sb.from('notes').delete().not('deleted_at', 'is', null);
  }

  Future<void> setFavorite(int id, bool isFav) async {
    await _sb.from('notes').update(<String, dynamic>{'is_favorite': isFav}).eq('id', id);
  }

  Future<void> refreshTick() async {
    await _sb.from('notes').select('id').limit(1);
  }
}
