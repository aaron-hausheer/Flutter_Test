class Tag {
  final int id;
  final String name;

  const Tag({required this.id, required this.name});

  factory Tag.fromMap(Map<String, dynamic> m) {
    final int id = (m['id'] as num).toInt();
    final String name = m['name'] as String;
    return Tag(id: id, name: name);
    }
}
