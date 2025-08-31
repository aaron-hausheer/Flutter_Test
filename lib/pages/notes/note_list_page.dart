import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/note.dart';
import '../../models/group.dart';
import '../../services/notes_service.dart';
import '../../services/groups_service.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/note_editor_sheet.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/group_filter_bar.dart';
import '../../widgets/sticky_note_tile.dart';
import 'note_detail_page.dart';

class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});
  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final NotesService _notes = NotesService();
  final GroupsService _groups = GroupsService();

  String _searchQuery = '';
  bool _sortDesc = true;
  bool _selectionMode = false;
  bool _favOnly = false;
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
    return _notes.streamForCurrentUser(sortDesc: _sortDesc, groupId: _selectedGroupId, favOnly: _favOnly);
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
      ),
    );
    if (r == null) return;
    if (!r.isDelete) {
      await _notes.create(r.title, r.content, groupId: r.groupId);
    }
  }

  Future<void> _openEditSheet(Note note) async {
    final List<Group> groups = await _groups.fetchAllForCurrentUser();
    final NoteEditorResult? r = await showModalBottomSheet<NoteEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext c) => NoteEditorSheet(
        initialTitle: note.title,
        initialContent: note.content,
        isEditing: true,
        groups: groups,
        initialGroupId: note.groupId,
      ),
    );
    if (r == null) return;
    if (r.isDelete) {
      final bool confirm = await _confirmDelete(count: 1);
      if (!confirm) return;
      await _notes.delete(note.id);
      _showUndoSnackbar(<Note>[note]);
    } else {
      await _notes.update(note.id, r.title, r.content, groupId: r.groupId);
    }
  }

  Future<bool> _confirmDelete({required int count}) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) {
        return AlertDialog(
          title: Text(count == 1 ? 'Notiz löschen?' : '$count Notizen löschen?'),
          content: Text(count == 1 ? 'Diese Aktion kann nicht rückgängig gemacht werden.' : 'Diese Aktion kann nicht rückgängig gemacht werden.'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Abbrechen')),
            FilledButton.tonal(onPressed: () => Navigator.of(c).pop(true), child: const Text('Löschen')),
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
    final bool ok = await _confirmDelete(count: _selectedIds.length);
    if (!ok) return;
    final List<Note> toDelete = visible.where((Note n) => _selectedIds.contains(n.id)).toList();
    await _notes.deleteMany(_selectedIds);
    _toggleSelectionMode(false);
    _showUndoSnackbar(toDelete);
  }

  void _showUndoSnackbar(List<Note> deleted) {
    if (deleted.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted.length == 1 ? 'Notiz gelöscht' : '${deleted.length} Notizen gelöscht'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () async {
            for (final Note n in deleted) {
              await _notes.create(n.title, n.content, groupId: n.groupId, isFavorite: n.isFavorite);
            }
          },
        ),
      ),
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
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Abmelden'),
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) Navigator.of(c).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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
    if (chips.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _loadingSkeletonGrid(BuildContext context) {
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
      itemCount: cols * 2,
      itemBuilder: (BuildContext context, int i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
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
        return StickyNoteTile(
          title: n.title,
          content: n.content,
          footer: _formatDate(n.createdAt),
          selectionMode: _selectionMode,
          selected: selected,
          tileColor: tileColor,
          isFavorite: n.isFavorite,
          onTap: () {
            if (_selectionMode) {
              _toggleSelected(n.id);
            } else {
              _openEditSheet(n);
            }
          },
          onLongPress: () => _toggleSelectionMode(true),
          onOpen: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext c) => NoteDetailPage(note: n)));
          },
          onEdit: () => _openEditSheet(n),
          onDuplicate: () async => _notes.duplicate(n),
          onDelete: () async {
            final bool ok = await _confirmDelete(count: 1);
            if (!ok) return;
            await _notes.delete(n.id);
            _showUndoSnackbar(<Note>[n]);
          },
          onToggleFavorite: () async => _notes.setFavorite(n.id, !n.isFavorite),
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
          IconButton(onPressed: () => _deleteSelected(visible), icon: const Icon(Icons.delete)),
        ],
      );
    }
    return AppBar(
      title: const Text('Notizen'),
      actions: <Widget>[
        IconButton(
          onPressed: _createGroupDialog,
          icon: const Icon(Icons.folder),
          tooltip: 'Neue Gruppe',
        ),
        IconButton(
          onPressed: () => setState(() => _favOnly = !_favOnly),
          icon: Icon(_favOnly ? Icons.star : Icons.star_border),
          tooltip: _favOnly ? 'Nur Favoriten' : 'Alle Notizen',
        ),
        IconButton(onPressed: _openSettings, icon: const Icon(Icons.tune)),
        IconButton(
          onPressed: () {
            setState(() => _sortDesc = !_sortDesc);
          },
          icon: Icon(_sortDesc ? Icons.arrow_downward : Icons.arrow_upward),
          tooltip: _sortDesc ? 'Neueste zuerst' : 'Älteste zuerst',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): const _FocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): const _FocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): const _NewNoteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): const _NewNoteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): const _ToggleFavIntent(),
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): const _ToggleFavIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, shift: true): const _ToggleSortIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(onInvoke: (Intent i) {
            _searchFocus.requestFocus();
            return null;
          }),
          _NewNoteIntent: CallbackAction<_NewNoteIntent>(onInvoke: (Intent i) {
            _openCreateSheet();
            return null;
          }),
          _ToggleFavIntent: CallbackAction<_ToggleFavIntent>(onInvoke: (Intent i) {
            setState(() => _favOnly = !_favOnly);
            return null;
          }),
          _ToggleSortIntent: CallbackAction<_ToggleSortIntent>(onInvoke: (Intent i) {
            setState(() => _sortDesc = !_sortDesc);
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: StreamBuilder<List<Note>>(
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
                    Expanded(child: _loadingSkeletonGrid(context))
                  else if (snapshot.hasError)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text('Fehler: ${snapshot.error}', textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () async {
                                await _notes.refreshTick();
                                if (mounted) setState(() {});
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Erneut versuchen'),
                            ),
                          ],
                        ),
                      ),
                    )
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
                                  const Icon(Icons.note_add, size: 48),
                                  const SizedBox(height: 8),
                                  const Text('Noch keine Notizen'),
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    onPressed: _openCreateSheet,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Neue Notiz'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              await _notes.refreshTick();
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _grid(context, visible),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );

              return Scaffold(
                appBar: _buildAppBar(_applyClientFilters(snapshot.data ?? const <Note>[])),
                drawer: const AdminDrawer(),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: _openCreateSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Neu'),
                ),
                body: body,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _NewNoteIntent extends Intent {
  const _NewNoteIntent();
}

class _ToggleFavIntent extends Intent {
  const _ToggleFavIntent();
}

class _ToggleSortIntent extends Intent {
  const _ToggleSortIntent();
}
