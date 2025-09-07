import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tag.dart';

class TagsService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<List<Tag>> fetchAllForCurrentUser() async {
    final List<dynamic> rows = await _sb.from('tags').select('id, name').order('name');
    final List<Tag> tags = rows.map((dynamic r) {
      final Map<String, dynamic> m = r as Map<String, dynamic>;
      return Tag.fromMap(m);
    }).toList();
    return tags;
  }

  Future<Tag> createIfMissing(String name) async {
    final Map<String, dynamic> row = await _sb
        .from('tags')
        .upsert(<String, dynamic>{'name': name}, onConflict: 'user_id,name')
        .select('id, name')
        .single();
    return Tag.fromMap(row);
  }

  Future<List<Tag>> tagsForNote(int noteId) async {
    final List<dynamic> links = await _sb.from('note_tags').select('tag_id').eq('note_id', noteId);
    final List<int> ids = links.map((dynamic r) => (r as Map<String, dynamic>)['tag_id'] as int).toList();
    if (ids.isEmpty) return <Tag>[];
    final List<dynamic> rows = await _sb.from('tags').select('id, name').inFilter('id', ids);
    final List<Tag> tags = rows.map((dynamic r) => Tag.fromMap(r as Map<String, dynamic>)).toList();
    return tags;
  }

  Future<void> setTagsForNote(int noteId, List<int> tagIds) async {
    await _sb.from('note_tags').delete().eq('note_id', noteId);
    if (tagIds.isEmpty) return;
    final List<Map<String, dynamic>> payload = tagIds.map((int id) => <String, dynamic>{'note_id': noteId, 'tag_id': id}).toList();
    await _sb.from('note_tags').upsert(payload, onConflict: 'note_id,tag_id');
  }
}
