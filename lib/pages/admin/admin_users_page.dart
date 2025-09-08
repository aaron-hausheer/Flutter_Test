import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/tag.dart';
import '../../services/attachments_service.dart';
import '../../services/tags_service.dart';
import '../../widgets/sticky_note_tile.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

enum _UserSort { lastActivityDesc, noteCountDesc, nameAsc }

class _AdminUsersPageState extends State<AdminUsersPage> {
  SupabaseClient get _sb => Supabase.instance.client;

  final Map<String, String> _displayNames = <String, String>{};
  String _q = '';
  _UserSort _sort = _UserSort.lastActivityDesc;

  @override
  void initState() {
    super.initState();
    _loadDisplayNames();
  }

  Future<void> _loadDisplayNames() async {
    try {
      final List<dynamic> res =
          await _sb.from('profiles').select('id, display_name');
      final Map<String, String> m = <String, String>{};
      for (final dynamic row in res) {
        final Map<String, dynamic> r = row as Map<String, dynamic>;
        final String id = (r['id'] as String?) ?? '';
        final String dn = (r['display_name'] as String?) ?? '';
        if (id.isNotEmpty && dn.isNotEmpty) m[id] = dn;
      }
      if (mounted) {
        setState(() {
          _displayNames
            ..clear()
            ..addAll(m);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile laden fehlgeschlagen: $e')),
        );
      }
    }
  }

  Stream<List<_UserRow>> _userStream() {
    final Stream<List<Map<String, dynamic>>> s =
        _sb.from('notes').stream(primaryKey: <String>['id']);

    return s.map((List<Map<String, dynamic>> rows) {
      final Map<String, _UserRow> map = <String, _UserRow>{};

      for (final Map<String, dynamic> m in rows) {
        final String? uid = m['user_id'] as String?;
        if (uid == null || uid.isEmpty) continue;

        final dynamic createdRaw = m['created_at'];
        final DateTime created = createdRaw is String
            ? DateTime.parse(createdRaw)
            : (createdRaw is DateTime ? createdRaw : DateTime.now());

        final _UserRow existing = map[uid] ??
            _UserRow(
              userId: uid,
              noteCount: 0,
              lastCreatedAt:
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            );

        final int c = existing.noteCount + 1;
        final DateTime last = created.isAfter(existing.lastCreatedAt)
            ? created
            : existing.lastCreatedAt;

        map[uid] =
            _UserRow(userId: uid, noteCount: c, lastCreatedAt: last);
      }

      List<_UserRow> list = map.values.toList();

      final String q = _q.trim().toLowerCase();
      if (q.isNotEmpty) {
        list = list.where((u) {
          final String name = _displayNames[u.userId] ?? u.userId;
          return name.toLowerCase().contains(q) ||
              u.userId.toLowerCase().contains(q);
        }).toList();
      }

      switch (_sort) {
        case _UserSort.lastActivityDesc:
          list.sort((a, b) => b.lastCreatedAt.compareTo(a.lastCreatedAt));
          break;
        case _UserSort.noteCountDesc:
          list.sort((a, b) => b.noteCount.compareTo(a.noteCount));
          break;
        case _UserSort.nameAsc:
          list.sort((a, b) {
            final String an = _displayNames[a.userId] ?? a.userId;
            final String bn = _displayNames[b.userId] ?? b.userId;
            return an.toLowerCase().compareTo(bn.toLowerCase());
          });
          break;
      }

      return list;
    });
  }

  String _nameFor(String userId) => _displayNames[userId] ?? userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Nutzer'),
        actions: <Widget>[
          PopupMenuButton<_UserSort>(
            tooltip: 'Sortierung',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (BuildContext c) => <PopupMenuEntry<_UserSort>>[
              const PopupMenuItem(
                  value: _UserSort.lastActivityDesc,
                  child: Text('Letzte Aktivität (neu → alt)')),
              const PopupMenuItem(
                  value: _UserSort.noteCountDesc,
                  child: Text('Notizanzahl (hoch → niedrig)')),
              const PopupMenuItem(
                  value: _UserSort.nameAsc, child: Text('Name (A → Z)')),
            ],
            icon: const Icon(Icons.sort),
          ),
          IconButton(
              onPressed: _loadDisplayNames,
              tooltip: 'Namen neu laden',
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Nach Name oder User-ID suchen…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<_UserRow>>(
              stream: _userStream(),
              builder: (BuildContext context,
                  AsyncSnapshot<List<_UserRow>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Fehler: ${snapshot.error}'));
                }
                final List<_UserRow> users =
                    snapshot.data ?? const <_UserRow>[];
                if (users.isEmpty) {
                  return const Center(child: Text('Keine Nutzer gefunden'));
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext context, int i) {
                    final _UserRow u = users[i];
                    final String name = _nameFor(u.userId);
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${u.noteCount} Notizen • letzte Aktivität ${u.lastCreatedAt}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (BuildContext c) => AdminUserNotesPage(
                                userId: u.userId, displayName: name)));
                      },
                      onLongPress: () async {
                        await Clipboard.setData(
                            ClipboardData(text: u.userId));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('User-ID kopiert')));
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminUserNotesPage extends StatefulWidget {
  final String userId;
  final String? displayName;
  const AdminUserNotesPage(
      {super.key, required this.userId, this.displayName});

  @override
  State<AdminUserNotesPage> createState() => _AdminUserNotesPageState();
}

class _AdminUserNotesPageState extends State<AdminUserNotesPage> {
  SupabaseClient get _sb => Supabase.instance.client;
  final AttachmentsService _attachments = AttachmentsService();
  final TagsService _tags = TagsService();

  String _q = '';

  Stream<List<_AdminNote>> _noteStream() {
    final Stream<List<Map<String, dynamic>>> s = _sb
        .from('notes')
        .stream(primaryKey: <String>['id'])
        .eq('user_id', widget.userId)
        .order('created_at', ascending: false);

    return s.map((List<Map<String, dynamic>> rows) {
      List<_AdminNote> list = rows.map((Map<String, dynamic> m) {
        final int id = (m['id'] as num).toInt();
        final String title = (m['title'] as String?) ?? '';
        final String content = (m['content'] as String?) ?? '';
        final dynamic createdRaw = m['created_at'];
        final DateTime createdAt = createdRaw is String
            ? DateTime.parse(createdRaw)
            : (createdRaw is DateTime ? createdRaw : DateTime.now());
        return _AdminNote(
            id: id, title: title, content: content, createdAt: createdAt);
      }).toList();

      final String q = _q.trim().toLowerCase();
      if (q.isNotEmpty) {
        list = list.where((n) {
          return n.title.toLowerCase().contains(q) ||
              n.content.toLowerCase().contains(q);
        }).toList();
      }
      return list;
    });
  }

  Future<_CardData> _cardDataFor(int noteId) async {
    final List<String> previews = await _attachments.listUrls(noteId, limit: 3);
    final List<Tag> tags = await _tags.tagsForNote(noteId);
    final String tagsLine =
        tags.isEmpty ? '' : tags.map((t) => '#${t.name}').join('   ');
    return _CardData(previews, tagsLine);
  }

  Future<void> _deleteNote(BuildContext context, _AdminNote n) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) {
        return AlertDialog(
          title: const Text('Notiz löschen?'),
          content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Abbrechen')),
            FilledButton.tonal(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Löschen')),
          ],
        );
      },
    );
    if (ok != true) return;
    await _sb.from('notes').delete().eq('id', n.id);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Notiz gelöscht')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.displayName == null
        ? 'Notizen: ${widget.userId}'
        : 'Notizen: ${widget.displayName}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'In Titeln/Inhalten suchen…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<_AdminNote>>(
              stream: _noteStream(),
              builder: (BuildContext context,
                  AsyncSnapshot<List<_AdminNote>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }
                final List<_AdminNote> notes =
                    snapshot.data ?? const <_AdminNote>[];
                if (notes.isEmpty) {
                  return const Center(child: Text('Keine Notizen'));
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double w = constraints.maxWidth;
                    int cols = (w / 220).floor();
                    if (cols < 2) cols = 2;
                    if (cols > 6) cols = 6;

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: notes.length,
                      itemBuilder: (BuildContext context, int i) {
                        final _AdminNote n = notes[i];
                        return FutureBuilder<_CardData>(
                          future: _cardDataFor(n.id),
                          builder: (BuildContext context,
                              AsyncSnapshot<_CardData> snap) {
                            final _CardData cd =
                                snap.data ?? const _CardData(<String>[], '');
                            return StickyNoteTile(
                              title: n.title,
                              content: n.content,
                              footer: cd.tagsLine,
                              tileColor: const Color(0xFFFFF59D),
                              isFavorite: false,
                              inTrash: false,
                              previewImageUrls: cd.previews,
                              selectionMode: false,
                              selected: false,
                              onTap: () {},
                              onLongPress: () {},
                              onDelete: () async => _deleteNote(context, n),
                              onToggleFavorite: () async {},
                              onRestore: () async {},
                              onPurge: () async {},
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow {
  final String userId;
  final int noteCount;
  final DateTime lastCreatedAt;
  const _UserRow(
      {required this.userId,
      required this.noteCount,
      required this.lastCreatedAt});
}

class _AdminNote {
  final int id;
  final String title;
  final String content;
  final DateTime createdAt;
  const _AdminNote(
      {required this.id,
      required this.title,
      required this.content,
      required this.createdAt});
}

class _CardData {
  final List<String> previews;
  final String tagsLine;
  const _CardData(this.previews, this.tagsLine);
}
