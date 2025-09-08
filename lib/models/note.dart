class Note {
  final int id;
  final String title;
  final String content;
  final DateTime createdAt;
  final int? groupId;
  final bool isFavorite;
  final DateTime? deletedAt;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.groupId,
    required this.isFavorite,
    required this.deletedAt,
  });

  factory Note.fromMap(Map<String, dynamic> m) {
    final int id = (m['id'] as num).toInt();
    final String title = (m['title'] as String?) ?? '';
    final String content = (m['content'] as String?) ?? '';
    final dynamic createdRaw = m['created_at'];
    final DateTime createdAt = createdRaw is String ? DateTime.parse(createdRaw) : (createdRaw is DateTime ? createdRaw : DateTime.now());
    final int? groupId = m['group_id'] == null ? null : (m['group_id'] as num).toInt();
    final bool isFavorite = (m['is_favorite'] as bool?) ?? false;
    final dynamic delRaw = m['deleted_at'];
    final DateTime? deletedAt = delRaw == null ? null : (delRaw is String ? DateTime.parse(delRaw) : (delRaw is DateTime ? delRaw : null));
    return Note(id: id, title: title, content: content, createdAt: createdAt, groupId: groupId, isFavorite: isFavorite, deletedAt: deletedAt);
  }
}
