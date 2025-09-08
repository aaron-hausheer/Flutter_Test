// lib/services/attachments_service.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class AttachmentItem {
  final int id;
  final String path;
  final String url;
  final String? mimeType;
  final int? size;
  final DateTime createdAt;
  AttachmentItem({
    required this.id,
    required this.path,
    required this.url,
    required this.mimeType,
    required this.size,
    required this.createdAt,
  });
}

class AttachmentsService {
  final SupabaseClient _sb = Supabase.instance.client;
  final String _bucket = 'note-images'; // <- Bucket-Name hier anpassen, falls anders

  /// Gibt bis zu [limit] signierte URLs zurück (für kleine Vorschaumengen)
  Future<List<String>> listUrls(int noteId, {int limit = 3, int expiresSeconds = 3600}) async {
    final List<dynamic> rows = await _sb
        .from('note_images')
        .select('id, path')
        .eq('note_id', noteId)
        .order('created_at', ascending: false)
        .limit(limit);

    final List<String> urls = <String>[];
    for (final dynamic r in rows) {
      final String path = (r as Map<String, dynamic>)['path'] as String;
      final String url = await _sb.storage.from(_bucket).createSignedUrl(path, expiresSeconds);
      urls.add(url);
    }
    return urls;
  }

  /// Liste kompletter Attachment-Objekte (inkl. signierter URL)
  Future<List<AttachmentItem>> list(int noteId, {int expiresSeconds = 3600}) async {
    final List<dynamic> rows = await _sb
        .from('note_images')
        .select('id, path, mime_type, size, created_at')
        .eq('note_id', noteId)
        .order('created_at', ascending: false);

    final List<AttachmentItem> items = <AttachmentItem>[];
    for (final dynamic r in rows) {
      final Map<String, dynamic> m = r as Map<String, dynamic>;
      final String path = m['path'] as String;
      final String url = await _sb.storage.from(_bucket).createSignedUrl(path, expiresSeconds);
      final int id = (m['id'] as num).toInt();
      final String? mime = m['mime_type'] as String?;
      final int? size = (m['size'] as num?)?.toInt();
      final dynamic cr = m['created_at'];
      final DateTime createdAt = cr is String ? DateTime.parse(cr) : (cr is DateTime ? cr : DateTime.now());
      items.add(AttachmentItem(
        id: id,
        path: path,
        url: url,
        mimeType: mime,
        size: size,
        createdAt: createdAt,
      ));
    }
    return items;
  }

  /// Upload mehrerer Bilder + Insert in note_images
  Future<void> uploadFiles(int noteId, List<PlatformFile> files) async {
    final String uid = _sb.auth.currentUser!.id;
    if (files.isEmpty) return;

    for (final PlatformFile f in files) {
      final Uint8List? bytes = f.bytes;
      if (bytes == null || bytes.isEmpty) {
        // Damit Web/Desktop funktioniert: bitte FilePicker mit withData: true aufrufen
        throw Exception('Keine Bytes für "${f.name}" (FilePicker mit withData: true verwenden).');
      }

      final String safeName = _sanitizeName(f.name);
      final String path = '$uid/$noteId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final String? mime = lookupMimeType(f.name, headerBytes: bytes);
      // In Storage hochladen
      await _sb.storage
          .from(_bucket)
          .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));

      // In note_images eintragen (user_id kommt über DEFAULT)
      await _sb.from('note_images').insert(<String, dynamic>{
        'note_id': noteId,
        'path': path,
        'mime_type': mime,
        'size': bytes.length,
        // 'user_id' NICHT setzen -> DEFAULT auth.uid() greift und RLS-Policy lässt es zu
      });
    }
  }

  /// Einzelnes Attachment entfernen (DB + Storage)
  Future<void> remove(int id, String path) async {
    // Zuerst Storage
    await _sb.storage.from(_bucket).remove(<String>[path]);
    // Dann DB-Row
    await _sb.from('note_images').delete().eq('id', id);
  }

  String _sanitizeName(String name) {
    // einfache Normalisierung des Dateinamens
    final String base = p.basename(name);
    return base.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }
}
