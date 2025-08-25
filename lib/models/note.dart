class Note {
  final int id;
  final String title;
  final String content;
  final DateTime createdAt;
  final int? groupId;

  const Note({required this.id, required this.title, required this.content, required this.createdAt, required this.groupId});

  factory Note.fromMap(Map<String, dynamic> m) {
    final int id = (m['id'] as num).toInt();
    final String title = (m['title'] as String?) ?? '';
    final String content = (m['content'] as String?) ?? '';
    final dynamic createdRaw = m['created_at'];
    final DateTime createdAt = createdRaw is String ? DateTime.parse(createdRaw) : (createdRaw is DateTime ? createdRaw : DateTime.now());
    final int? groupId = (m['group_id'] as num?)?.toInt();
    return Note(id: id, title: title, content: content, createdAt: createdAt, groupId: groupId);
  }
}
