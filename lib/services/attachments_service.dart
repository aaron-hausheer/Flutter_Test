import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attachment.dart';

class AttachmentsService {
  final SupabaseClient _sb = Supabase.instance.client;
  final String _bucket = 'note-images';

  Future<List<Attachment>> listForNote(int noteId) async {
    final List<dynamic> rows = await _sb
        .from('note_images')
        .select('id, note_id, path, mime_type, size, created_at')
        .eq('note_id', noteId)
        .order('created_at', ascending: false);
    final List<Attachment> list = rows.map((dynamic r) => Attachment.fromMap(r as Map<String, dynamic>)).toList();
    return list;
  }

  Future<String> signedUrl(String path, {int expiresSeconds = 3600}) async {
    final String url = await _sb.storage.from(_bucket).createSignedUrl(path, expiresSeconds);
    return url;
  }

  Future<List<Attachment>> uploadFiles(int noteId, List<PlatformFile> files) async {
    final String uid = _sb.auth.currentUser!.id;
    final String notePath = '$uid/$noteId';
    final List<Attachment> created = <Attachment>[];
    for (final PlatformFile f in files) {
      if (f.bytes == null || f.bytes!.isEmpty) continue;
      final String safeName = f.name.replaceAll('/', '_');
      final String key = '$notePath/${DateTime.now().microsecondsSinceEpoch}_$safeName';
      final Uint8List data = f.bytes!;
      await _sb.storage.from(_bucket).uploadBinary(key, data, fileOptions: const FileOptions(upsert: false));
      final List<dynamic> rows = await _sb
          .from('note_images')
          .insert(<String, dynamic>{
            'note_id': noteId,
            'path': key,
            'mime_type': f.extension ?? '',
            'size': f.size,
          })
          .select('id, note_id, path, mime_type, size, created_at')
          .limit(1);
      created.add(Attachment.fromMap(rows.first as Map<String, dynamic>));
    }
    return created;
  }
}
