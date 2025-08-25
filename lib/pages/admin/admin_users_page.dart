import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  SupabaseClient get _sb => Supabase.instance.client;
  final Map<String, String> _displayNames = <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadDisplayNames();
  }

  Future<void> _loadDisplayNames() async {
    final List<dynamic> res = await _sb.from('profiles').select('id, display_name');
    final Map<String, String> m = <String, String>{};
    for (final dynamic row in res) {
      final Map<String, dynamic> r = row as Map<String, dynamic>;
      final String id = r['id'] as String;
      final String dn = (r['display_name'] as String?) ?? '';
      if (dn.isNotEmpty) {
        m[id] = dn;
      }
    }
    if (mounted) {
      setState(() {
        _displayNames
          ..clear()
          ..addAll(m);
      });
    }
  }

  Stream<List<_UserRow>> _userStream() {
    final Stream<List<Map<String, dynamic>>> s = _sb.from('notes').stream(primaryKey: <String>['id']);
    return s.map((List<Map<String, dynamic>> rows) {
      final Map<String, _UserRow> map = <String, _UserRow>{};
      for (final Map<String, dynamic> m in rows) {
        final String? uid = m['user_id'] as String?;
        if (uid == null) continue;
        if (!map.containsKey(uid)) {
          map[uid] = _UserRow(userId: uid, noteCount: 0, lastCreatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
        }
        final _UserRow r = map[uid]!;
        final int c = r.noteCount + 1;
        final dynamic createdRaw = m['created_at'];
        final DateTime created = createdRaw is String ? DateTime.parse(createdRaw) : (createdRaw is DateTime ? createdRaw : DateTime.now());
        final DateTime last = created.isAfter(r.lastCreatedAt) ? created : r.lastCreatedAt;
        map[uid] = _UserRow(userId: uid, noteCount: c, lastCreatedAt: last);
      }
      final List<_UserRow> list = map.values.toList();
      list.sort((a, b) => b.lastCreatedAt.compareTo(a.lastCreatedAt));
      return list;
    });
  }

  String _nameFor(String userId) {
    return _displayNames[userId] ?? userId;
  }

  String _formatDate(DateTime dt) {
    final String y = dt.year.toString().padLeft(4, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y, $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Nutzer')),
      body: StreamBuilder<List<_UserRow>>(
        stream: _userStream(),
        builder: (BuildContext context, AsyncSnapshot<List<_UserRow>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final List<_UserRow> users = snapshot.data ?? const <_UserRow>[];
          if (users.isEmpty) return const Center(child: Text('Keine Nutzer'));
          return RefreshIndicator(
            onRefresh: () async {
              await _loadDisplayNames();
            },
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (BuildContext context, int i) {
                final _UserRow u = users[i];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(_nameFor(u.userId)),
                  subtitle: Text('${u.noteCount} Notizen • ${_formatDate(u.lastCreatedAt)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext c) => AdminUserNotesPage(userId: u.userId)));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class AdminUserNotesPage extends StatelessWidget {
  final String userId;
  const AdminUserNotesPage({super.key, required this.userId});

  SupabaseClient get _sb => Supabase.instance.client;

  Stream<List<_AdminNote>> _noteStream() {
    final Stream<List<Map<String, dynamic>>> s = _sb.from('notes').stream(primaryKey: <String>['id']).eq('user_id', userId).order('created_at', ascending: false);
    return s.map((List<Map<String, dynamic>> rows) => rows.map((Map<String, dynamic> m) {
      final int id = (m['id'] as num).toInt();
      final String title = (m['title'] as String?) ?? '';
      final String content = (m['content'] as String?) ?? '';
      final dynamic createdRaw = m['created_at'];
      final DateTime createdAt = createdRaw is String ? DateTime.parse(createdRaw) : (createdRaw is DateTime ? createdRaw : DateTime.now());
      return _AdminNote(id: id, title: title, content: content, createdAt: createdAt);
    }).toList());
  }

  Future<void> _deleteNote(BuildContext context, _AdminNote n) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) {
        return AlertDialog(
          title: const Text('Notiz löschen?'),
          content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Abbrechen')),
            FilledButton.tonal(onPressed: () => Navigator.of(c).pop(true), child: const Text('Löschen')),
          ],
        );
      },
    );
    if (ok != true) return;
    await _sb.from('notes').delete().eq('id', n.id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notiz gelöscht')));
  }

  String _formatDate(DateTime dt) {
    final String y = dt.year.toString().padLeft(4, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y, $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notizen: $userId')),
      body: StreamBuilder<List<_AdminNote>>(
        stream: _noteStream(),
        builder: (BuildContext context, AsyncSnapshot<List<_AdminNote>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final List<_AdminNote> notes = snapshot.data ?? const <_AdminNote>[];
          if (notes.isEmpty) return const Center(child: Text('Keine Notizen'));
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (BuildContext context, int i) {
              final _AdminNote n = notes[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(n.title.isEmpty ? 'Ohne Titel' : n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(n.content.isEmpty ? 'Ohne Inhalt' : n.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text(_formatDate(n.createdAt)),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    onPressed: () async {
                      await _deleteNote(context, n);
                    },
                    icon: const Icon(Icons.delete),
                    tooltip: 'Löschen',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _UserRow {
  final String userId;
  final int noteCount;
  final DateTime lastCreatedAt;
  const _UserRow({required this.userId, required this.noteCount, required this.lastCreatedAt});
}

class _AdminNote {
  final int id;
  final String title;
  final String content;
  final DateTime createdAt;
  const _AdminNote({required this.id, required this.title, required this.content, required this.createdAt});
}
