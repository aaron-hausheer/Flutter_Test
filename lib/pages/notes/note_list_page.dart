import 'package:flutter/material.dart';
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
  final Set<int> _selectedIds = <int>{};
  Note? _lastDeleted;

  int? _selectedGroupId;
  List<Group> _groupsCache = const <Group>[];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Stream<List<Note>> _noteStream() {
    return _notes.streamForCurrentUser(sortDesc: _sortDesc, groupId: _selectedGroupId);
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

  Future<void> _createGroupDialog() async {
    final TextEditingController ctrl = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext c) {
        return AlertDialog(
          title: const Text('Neue Gruppe'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(c).pop(null), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.of(c).pop(ctrl.text.trim()), child: const Text('Erstellen')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    final Group g = await _groups.createAndReturn(name);
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
      setState(() => _lastDeleted = note);
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
    setState(() => _lastDeleted = toDelete.isNotEmpty ? toDelete.first : null);
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
              await _notes.create(n.title, n.content, groupId: n.groupId);
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
        return StickyNoteTile(
          title: n.title,
          content: n.content,
          footer: _formatDate(n.createdAt),
          selectionMode: _selectionMode,
          selected: selected,
          colorIndex: n.id,
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
            setState(() => _lastDeleted = n);
            await _notes.delete(n.id);
            _showUndoSnackbar(<Note>[n]);
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
    return StreamBuilder<List<Note>>(
      stream: _noteStream(),
      builder: (BuildContext context, AsyncSnapshot<List<Note>> snapshot) {
        final Widget body = Column(
          children: <Widget>[
            _buildSearchBar(),
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
                    return const Expanded(child: Center(child: Text('Keine Notizen')));
                  }
                  return Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await _notes.refreshTick();
                      },
                      child: _grid(context, visible),
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
    );
  }
}
