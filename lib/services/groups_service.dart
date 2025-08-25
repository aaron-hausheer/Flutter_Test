import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';

class GroupsService {
  SupabaseClient get _sb => Supabase.instance.client;

  Stream<List<Group>> streamForCurrentUser() {
    final String uid = _sb.auth.currentUser!.id;
    final SupabaseStreamBuilder s = _sb
        .from('groups')
        .stream(primaryKey: <String>['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return s.map((List<Map<String, dynamic>> rows) => rows.map((Map<String, dynamic> m) => Group.fromMap(m)).toList());
  }

  Future<List<Group>> fetchAllForCurrentUser() async {
    final String uid = _sb.auth.currentUser!.id;
    final List<dynamic> res = await _sb
        .from('groups')
        .select('id, name, color_hex, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    final List<Group> list = res.map((dynamic r) => Group.fromMap(r as Map<String, dynamic>)).toList();
    return list;
  }

  Future<Group> createAndReturn(String name, String colorHex) async {
    final String uid = _sb.auth.currentUser!.id;
    final List<dynamic> rows = await _sb
        .from('groups')
        .insert(<String, dynamic>{'name': name, 'user_id': uid, 'color_hex': colorHex})
        .select();
    final Map<String, dynamic> m = rows.first as Map<String, dynamic>;
    return Group.fromMap(m);
  }

  Future<void> create(String name, String colorHex) async {
    final String uid = _sb.auth.currentUser!.id;
    await _sb.from('groups').insert(<String, dynamic>{'name': name, 'user_id': uid, 'color_hex': colorHex});
  }

  Future<void> rename(int id, String name) async {
    await _sb.from('groups').update(<String, dynamic>{'name': name}).eq('id', id);
  }

  Future<void> recolor(int id, String colorHex) async {
    await _sb.from('groups').update(<String, dynamic>{'color_hex': colorHex}).eq('id', id);
  }

  Future<void> delete(int id) async {
    await _sb.from('groups').delete().eq('id', id);
  }
}
