class Group {
  final int id;
  final String name;
  final DateTime createdAt;

  const Group({required this.id, required this.name, required this.createdAt});

  factory Group.fromMap(Map<String, dynamic> m) {
    final int id = (m['id'] as num).toInt();
    final String name = (m['name'] as String?) ?? '';
    final dynamic cr = m['created_at'];
    final DateTime createdAt = cr is String ? DateTime.parse(cr) : (cr is DateTime ? cr : DateTime.now());
    return Group(id: id, name: name, createdAt: createdAt);
  }
}
