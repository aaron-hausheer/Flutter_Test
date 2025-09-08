import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/note.dart';
import '../../models/group.dart';
import '../../models/tag.dart';
import '../../services/notes_service.dart';
import '../../services/groups_service.dart';
import '../../services/tags_service.dart';
import '../../services/attachments_service.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/note_editor_sheet.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/group_filter_bar.dart';
import '../../widgets/sticky_note_tile.dart';
import 'note_detail_page.dart';
import '../settings/settings_page.dart';

class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});
  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NewNoteIntent extends Intent { const _NewNoteIntent(); }
class _FocusSearchIntent extends Intent { const _FocusSearchIntent(); }
class _ToggleFavFilterIntent extends Intent { const _ToggleFavFilterIntent(); }
class _ToggleSortIntent extends Intent { const _ToggleSortIntent(); }

class _NoteListPageState extends State<NoteListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final NotesService _notes = NotesService();
  final GroupsService _groups = GroupsService();
  final AttachmentsService _attachments = AttachmentsService();

  String _searchQuery = '';
  bool _sortDesc = true;
  bool _selectionMode = false;
  bool _favOnly = false;
  bool _trashOnly = false;
  final Set<int> _selectedIds = <int>{};
  int? _selectedGroupId;
  List<Group> _groupsCache = const <Group>[];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Stream<List<Note>> _noteStream() {
    return _notes.streamForCurrentUser(
      sortDesc: _sortDesc,
      groupId: _selectedGroupId,
      favOnly: _favOnly,
      trashedOnly: _trashOnly,
    );
  }

  List<Note> _applyClientFilters(List<Note> all) {
    final String q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((Note n) => n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q)).toList();
  }

  String _formatDate(DateTime dt) {
    final String y = dt.year.toString().padLeft(4, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y, $hh:$mm';
  }

  Color _parseHexColor(String hex) {
    String h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    final int v = int.parse(h, radix: 16);
    return Color(v);
  }

  Color _tileColorFor(int? groupId) {
    if (groupId == null) return const Color(0xFFFFF59D);
    for (final Group g in _groupsCache) {
      if (g.id == groupId) return _parseHexColor(g.colorHex);
    }
    return const Color(0xFFFFF59D);
  }

  Future<void> _createGroupDialog() async {
    final List<String> palette = <String>['#FFF59D', '#FFE082', '#FFCC80', '#FFAB91', '#E1BEE7', '#BBDEFB', '#B2DFDB', '#C8E6C9'];
    final TextEditingController ctrl = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext c) {
        int sel = 0;
        return StatefulBuilder(
          builder: (BuildContext c, StateSetter setS) {
            return AlertDialog(
              title: const Text('Neue Gruppe'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<Widget>.generate(palette.length, (int i) {
                      final bool selected = sel == i;
                      return InkWell(
                        onTap: () => setS(() => sel = i),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _parseHexColor(palette[i]),
                            shape: BoxShape.circle,
                            border: Border.all(width: selected ? 3 : 1, color: selected ? Colors.black87 : Colors.black26),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(c).pop(null), child: const Text('Abbrechen')),
                FilledButton(onPressed: () => Navigator.of(c).pop('${ctrl.text.trim()}|${palette[sel]}'), child: const Text('Erstellen')),
              ],
            );
          },
        );
      },
    );
    if (result == null || result.isEmpty) return;
    final List<String> parts = result.split('|');
    if (parts.isEmpty || parts.first.isEmpty) return;
    final String name = parts.first;
    final String hex = parts.length > 1 ? parts.last : '#FFF59D';
    final Group g = await _groups.createAndReturn(name, hex);
    setState(() => _selectedGroupId = g.id);
  }

  Future<void> _openCreateSheet() async {
    final List<Group> groups = await _groups.fetchAllForCurrentUser();
    final TagsService tagsSvc = TagsService();
    final List<Tag> allTags = await tagsSvc.fetchAllForCurrentUser();

    final NoteEditorResult? r = await showModalBottomSheet<NoteEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext c) => NoteEditorSheet(
        initialTitle: '',
        initialContent: '',
        isEditing: false,
        groups: groups,
        initialGroupId: _selectedGroupId,
        availableTags: allTags,
        initialTagIds: const <int>[],
      ),
    );
    if (r == null || r.isDelete) return;

    // 1) Note anlegen und ID bekommen
    final int newId = await _notes.create(
      r.title,
      r.content,
      groupId: r.groupId,
      tagIds: r.tagIds,
    );

    // 2) Falls Bilder ausgewählt: hochladen
    if (r.images.isNotEmpty) {
      await _attachments.uploadFiles(newId, r.images);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${r.images.length} Bild(er) hochgeladen')),
        );
      }
    }
  }

  Future<bool> _confirmDelete({required int count, bool permanent = false}) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) {
        return AlertDialog(
          title: Text(permanent ? (count == 1 ? 'Endgültig löschen?' : '$count endgültig löschen?') : (count == 1 ? 'In Papierkorb?' : '$count in Papierkorb?')),
          content: Text(permanent ? 'Diese Aktion kann nicht rückgängig gemacht werden.' : 'Dies kann rückgängig gemacht werden.'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Abbrechen')),
            FilledButton.tonal(onPressed: () => Navigator.of(c).pop(true), child: Text(permanent ? 'Löschen' : 'Verschieben')),
          ],
        );
      },
    );
    return ok ?? false;
  }

  void _toggleSelectionMode([bool? enable]) {
    setState(() {
      _selectionMode = enable ?? !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelected(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected(List<Note> visible) async {
    if (_selectedIds.isEmpty) return;

    if (_trashOnly) {
      // Endgültig nur die ausgewählten löschen
      final bool ok = await _confirmDelete(count: _selectedIds.length, permanent: true);
      if (!ok) return;
      for (final int id in _selectedIds) {
        await _notes.purge(id);
      }
      _toggleSelectionMode(false);
      return;
    }

    final bool ok = await _confirmDelete(count: _selectedIds.length);
    if (!ok) return;
    await _notes.moveManyToTrash(_selectedIds);
    _toggleSelectionMode(false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('In Papierkorb verschoben')));
  }

  Future<List<String>> _previewUrlsFor(int noteId) {
    return _attachments.listUrls(noteId, limit: 3);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SubmitSearchBar(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onApply: (String q) => setState(() => _searchQuery = q),
      ),
    );
  }

  Widget _activeFiltersChips() {
    final List<Widget> chips = <Widget>[];
    if (_searchQuery.isNotEmpty) {
      chips.add(InputChip(
        label: Text('Suche: $_searchQuery'),
        onDeleted: () => setState(() {
          _searchQuery = '';
          _searchCtrl.clear();
          _searchFocus.requestFocus();
        }),
      ));
    }
    if (_selectedGroupId != null) {
      final Group? g = _groupsCache.where((Group e) => e.id == _selectedGroupId).cast<Group?>().firstWhere((Group? _) => true, orElse: () => null);
      final String name = g?.name ?? 'Gruppe';
      chips.add(InputChip(
        label: Text(name),
        avatar: CircleAvatar(backgroundColor: _tileColorFor(_selectedGroupId)),
        onDeleted: () => setState(() => _selectedGroupId = null),
      ));
    }
    if (_favOnly) {
      chips.add(InputChip(
        label: const Text('Favoriten'),
        avatar: const Icon(Icons.star, size: 18),
        onDeleted: () => setState(() => _favOnly = false),
      ));
    }
    if (_trashOnly) {
      chips.add(InputChip(
        label: const Text('Papierkorb'),
        avatar: const Icon(Icons.delete_outline, size: 18),
        onDeleted: () => setState(() => _trashOnly = false),
      ));
    }
    if (chips.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _grid(BuildContext context, List<Note> notes) {
    final double w = MediaQuery.of(context).size.width;
    int cols = (w / 220).floor();
    if (cols < 2) cols = 2;
    if (cols > 6) cols = 6;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: notes.length,
      itemBuilder: (BuildContext context, int i) {
        final Note n = notes[i];
        final bool selected = _selectedIds.contains(n.id);
        final Color tileColor = _tileColorFor(n.groupId);
        return FutureBuilder<List<String>>(
          future: _previewUrlsFor(n.id),
          builder: (BuildContext context, AsyncSnapshot<List<String>> snap) {
            final List<String> previews = snap.data ?? const <String>[];
            return StickyNoteTile(
              title: n.title,
              content: n.content,
              footer: _formatDate(n.createdAt),
              selectionMode: _selectionMode,
              selected: selected,
              tileColor: tileColor,
              isFavorite: n.isFavorite,
              inTrash: _trashOnly,
              previewImageUrls: previews,
              onTap: () {
                if (_selectionMode) {
                  _toggleSelected(n.id);
                  return;
                }
                Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext _) => NoteDetailPage(note: n)));
              },
              onLongPress: () => _toggleSelectionMode(true),
              onDelete: () async {
                if (_trashOnly) {
                  final bool ok = await _confirmDelete(count: 1, permanent: true);
                  if (!ok) return;
                  await _notes.purge(n.id);
                } else {
                  final bool ok = await _confirmDelete(count: 1);
                  if (!ok) return;
                  await _notes.moveToTrash(n.id);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('In Papierkorb verschoben')));
                }
              },
              onToggleFavorite: () async => _notes.setFavorite(n.id, !n.isFavorite),
              onRestore: () async => _notes.restore(n.id),
              onPurge: () async {
                final bool ok = await _confirmDelete(count: 1, permanent: true);
                if (!ok) return;
                await _notes.purge(n.id);
              },
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(List<Note> visible) {
    if (_selectionMode) {
      return AppBar(
        title: Text('${_selectedIds.length} ausgewählt'),
        leading: IconButton(onPressed: () => _toggleSelectionMode(false), icon: const Icon(Icons.close)),
        actions: <Widget>[
          IconButton(onPressed: () => _deleteSelected(visible), icon: Icon(_trashOnly ? Icons.delete_forever : Icons.delete)),
        ],
      );
    }
    return AppBar(
      title: const Text('Notizen'),
      actions: <Widget>[
        IconButton(onPressed: _createGroupDialog, icon: const Icon(Icons.folder)),
        IconButton(onPressed: () => setState(() => _favOnly = !_favOnly), icon: Icon(_favOnly ? Icons.star : Icons.star_border)),
        IconButton(onPressed: () => setState(() => _trashOnly = !_trashOnly), icon: Icon(_trashOnly ? Icons.delete : Icons.delete_outline)),
        IconButton(onPressed: _openSettings, icon: const Icon(Icons.tune)),
        IconButton(onPressed: () => setState(() => _sortDesc = !_sortDesc), icon: Icon(_sortDesc ? Icons.arrow_downward : Icons.arrow_upward)),
        IconButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext c) => const SettingsPage())),
          icon: const Icon(Icons.settings),
        ),
      ],
    );
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext c) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.swap_vert),
                title: const Text('Sortierung'),
                subtitle: Text(_sortDesc ? 'Neueste zuerst' : 'Älteste zuerst'),
                onTap: () {
                  setState(() => _sortDesc = !_sortDesc);
                  Navigator.of(c).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.select_all),
                title: const Text('Mehrfachauswahl'),
                trailing: Switch(value: _selectionMode, onChanged: (bool v) => setState(() => _selectionMode = v)),
                onTap: () {
                  _toggleSelectionMode();
                  Navigator.of(c).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Neue Gruppe'),
                onTap: () async {
                  Navigator.of(c).pop();
                  await _createGroupDialog();
                },
              ),
              if (_trashOnly)
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text('Papierkorb leeren'),
                  onTap: () async {
                    Navigator.of(c).pop();
                    final bool ok = await _confirmDelete(count: 0, permanent: true);
                    if (!ok) return;
                    await _notes.purgeTrashedForCurrentUser();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Note>>(
      stream: _noteStream(),
      builder: (BuildContext context, AsyncSnapshot<List<Note>> snapshot) {
        final Widget body = Column(
          children: <Widget>[
            _buildSearchBar(),
            _activeFiltersChips(),
            StreamBuilder<List<Group>>(
              stream: _groups.streamForCurrentUser(),
              builder: (BuildContext context, AsyncSnapshot<List<Group>> gs) {
                final List<Group> groups = gs.data ?? const <Group>[];
                _groupsCache = groups;
                return GroupFilterBar(
                  groups: groups,
                  selectedGroupId: _selectedGroupId,
                  onSelected: (int? id) => setState(() => _selectedGroupId = id),
                  onCreateTap: _createGroupDialog,
                );
              },
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              Expanded(child: Center(child: Text('Fehler: ${snapshot.error}')))
            else
              Builder(
                builder: (BuildContext _) {
                  final List<Note> notes = snapshot.data ?? const <Note>[];
                  final List<Note> visible = _applyClientFilters(notes);
                  if (visible.isEmpty) {
                    return Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(_trashOnly ? Icons.delete_outline : Icons.note_add, size: 48),
                            const SizedBox(height: 8),
                            Text(_trashOnly ? 'Papierkorb ist leer' : 'Noch keine Notizen'),
                            if (!_trashOnly) ...<Widget>[
                              const SizedBox(height: 8),
                              FilledButton.icon(onPressed: _openCreateSheet, icon: const Icon(Icons.add), label: const Text('Neu')),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                  return Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => _notes.refreshTick(),
                      child: _grid(context, visible),
                    ),
                  );
                },
              ),
          ],
        );

        final List<Note> visibleForActions = _applyClientFilters(snapshot.data ?? const <Note>[]);

        return Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyF): const _FocusSearchIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const _FocusSearchIntent(),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK): const _NewNoteIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK): const _NewNoteIntent(),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyL): const _ToggleFavFilterIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL): const _ToggleFavFilterIntent(),
            LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.keyS): const _ToggleSortIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _NewNoteIntent: CallbackAction<_NewNoteIntent>(onInvoke: (_) { _openCreateSheet(); return null; }),
              _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(onInvoke: (_) { _searchFocus.requestFocus(); return null; }),
              _ToggleFavFilterIntent: CallbackAction<_ToggleFavFilterIntent>(onInvoke: (_) { setState(() => _favOnly = !_favOnly); return null; }),
              _ToggleSortIntent: CallbackAction<_ToggleSortIntent>(onInvoke: (_) { setState(() => _sortDesc = !_sortDesc); return null; }),
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                appBar: _buildAppBar(visibleForActions),
                drawer: const AdminDrawer(),
                floatingActionButton: _trashOnly
                    ? null
                    : FloatingActionButton.extended(
                        onPressed: _openCreateSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Neu'),
                      ),
                body: body,
              ),
            ),
          ),
        );
      },
    );
  }
}
