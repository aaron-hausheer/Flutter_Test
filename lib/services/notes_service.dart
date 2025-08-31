import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';

class NotesService {
  final SupabaseClient _sb = Supabase.instance.client;

  Stream<List<Note>> streamForCurrentUser({required bool sortDesc, int? groupId, bool favOnly = false}) {
    final String uid = _sb.auth.currentUser!.id;
    dynamic s = _sb.from('notes').stream(primaryKey: <String>['id']).eq('user_id', uid);
    if (groupId != null) s = s.eq('group_id', groupId);
    if (favOnly) s = s.eq('is_favorite', true);
    s = s.order('is_favorite', ascending: false).order('created_at', ascending: !sortDesc);
    final Stream<List<Map<String, dynamic>>> stream = s;
    return stream.map((List<Map<String, dynamic>> rows) => rows.map((Map<String, dynamic> m) => Note.fromMap(m)).toList());
  }

  Future<void> refreshTick() async {
    await _sb.from('notes').select('id').limit(1);
  }

  Future<void> create(String title, String content, {int? groupId, bool? isFavorite}) async {
    await _sb.from('notes').insert(<String, dynamic>{
      'title': title,
      'content': content,
      if (groupId != null) 'group_id': groupId,
      if (isFavorite != null) 'is_favorite': isFavorite,
    });
  }

  Future<void> update(int id, String title, String content, {int? groupId, bool? isFavorite}) async {
    await _sb.from('notes').update(<String, dynamic>{
      'title': title,
      'content': content,
      'group_id': groupId,
      if (isFavorite != null) 'is_favorite': isFavorite,
    }).eq('id', id);
  }

  Future<void> delete(int id) async {
    await _sb.from('notes').delete().eq('id', id);
  }

  Future<void> deleteMany(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await _sb.from('notes').delete().inFilter('id', ids.toList());
  }

  Future<void> duplicate(Note n) async {
    await create(n.title, n.content, groupId: n.groupId, isFavorite: n.isFavorite);
  }

  Future<void> setFavorite(int id, bool value) async {
    await _sb.from('notes').update(<String, dynamic>{'is_favorite': value}).eq('id', id);
  }
}
