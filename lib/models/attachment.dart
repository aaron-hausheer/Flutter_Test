class Attachment {
  final int id;
  final int noteId;
  final String path;
  final String mimeType;
  final int size;
  final DateTime createdAt;

  const Attachment({
    required this.id,
    required this.noteId,
    required this.path,
    required this.mimeType,
    required this.size,
    required this.createdAt,
  });

  factory Attachment.fromMap(Map<String, dynamic> m) {
    final int id = (m['id'] as num).toInt();
    final int noteId = (m['note_id'] as num).toInt();
    final String path = m['path'] as String;
    final String mimeType = (m['mime_type'] as String?) ?? '';
    final int size = (m['size'] as num?)?.toInt() ?? 0;
    final dynamic cr = m['created_at'];
    final DateTime createdAt = cr is String ? DateTime.parse(cr) : (cr is DateTime ? cr : DateTime.now());
    return Attachment(id: id, noteId: noteId, path: path, mimeType: mimeType, size: size, createdAt: createdAt);
  }
}
