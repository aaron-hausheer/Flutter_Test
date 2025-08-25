import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';

class NotesService {
  SupabaseClient get _sb => Supabase.instance.client;

  Stream<List<Note>> streamForCurrentUser({required bool sortDesc, int? groupId}) {
    final String uid = _sb.auth.currentUser!.id;
    final SupabaseStreamBuilder base = _sb
        .from('notes')
        .stream(primaryKey: <String>['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: !sortDesc);
    return base
        .map((List<Map<String, dynamic>> rows) => rows.map((Map<String, dynamic> m) => Note.fromMap(m)).toList())
        .map((List<Note> notes) => groupId == null ? notes : notes.where((Note n) => n.groupId == groupId).toList());
  }

  Future<void> create(String title, String content, {int? groupId}) async {
    await _sb.from('notes').insert(<String, dynamic>{'title': title, 'content': content, 'group_id': groupId});
  }

  Future<void> update(int id, String title, String content, {int? groupId}) async {
    await _sb.from('notes').update(<String, dynamic>{'title': title, 'content': content, 'group_id': groupId}).eq('id', id);
  }

  Future<void> delete(int id) async {
    await _sb.from('notes').delete().eq('id', id);
  }

  Future<void> deleteMany(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await _sb.from('notes').delete().inFilter('id', ids.toList());
  }

  Future<void> duplicate(Note n) async {
    await create(n.title, n.content, groupId: n.groupId);
  }

  Future<void> refreshTick() async {
    await _sb.from('notes').select().limit(1);
  }
}
