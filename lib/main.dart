import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart';
import 'admin_pages.dart';
import 'admin_stats.dart';

const String SUPABASE_URL = 'https://qjojmiexgnxmibqcblqj.supabase.co';
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqb2ptaWV4Z254bWlicWNibHFqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYwMzQwNzksImV4cCI6MjA3MTYxMDA3OX0.CQv4sm0uDUSrFRoiroaUKUXIQuq-uoCyZCx-95uYw-Y';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
  runApp(const CrudApp());
}

class CrudApp extends StatelessWidget {
  const CrudApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B82F6),
        appBarTheme: const AppBarTheme(centerTitle: true),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      home: const AuthGate(child: NoteListPage()),
    );
  }
}

class Note {
  final int id;
  final String title;
  final String content;
  final DateTime createdAt;

  const Note({required this.id, required this.title, required this.content, required this.createdAt});

  factory Note.fromMap(Map<String, dynamic> m) {
    final int id = (m['id'] as num).toInt();
    final String title = (m['title'] as String?) ?? '';
    final String content = (m['content'] as String?) ?? '';
    final dynamic createdRaw = m['created_at'];
    final DateTime createdAt = createdRaw is String ? DateTime.parse(createdRaw) : (createdRaw is DateTime ? createdRaw : DateTime.now());
    return Note(id: id, title: title, content: content, createdAt: createdAt);
  }
}

class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});
  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  bool _sortDesc = true;
  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};
  Note? _lastDeleted;
  SupabaseClient get _sb => Supabase.instance.client;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _create(String title, String content) async {
    await _sb.from('notes').insert(<String, dynamic>{'title': title, 'content': content});
  }

  Future<void> _update(int id, String title, String content) async {
    await _sb.from('notes').update(<String, dynamic>{'title': title, 'content': content}).eq('id', id);
  }

  Future<void> _delete(int id) async {
    final PostgrestFilterBuilder<dynamic> q = _sb.from('notes').delete().eq('id', id);
    await q;
  }

  Future<void> _deleteMany(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await _sb.from('notes').delete().inFilter('id', ids.toList());
  }

  Future<void> _duplicate(Note n) async {
    await _create(n.title, n.content);
  }

  Stream<List<Note>> _noteStream() {
    final String uid = Supabase.instance.client.auth.currentUser!.id;
    final Stream<List<Map<String, dynamic>>> s = Supabase.instance.client
        .from('notes')
        .stream(primaryKey: <String>['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: !_sortDesc);
    return s.map((List<Map<String, dynamic>> rows) => rows.map((Map<String, dynamic> m) => Note.fromMap(m)).toList());
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

  Future<void> _openCreateSheet() async {
    final NoteEditorResult? r = await showModalBottomSheet<NoteEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext c) => NoteEditorSheet(initialTitle: '', initialContent: '', isEditing: false),
    );
    if (r == null) return;
    if (!r.isDelete) {
      await _create(r.title, r.content);
    }
  }

  Future<void> _openEditSheet(Note note) async {
    final NoteEditorResult? r = await showModalBottomSheet<NoteEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext c) => NoteEditorSheet(initialTitle: note.title, initialContent: note.content, isEditing: true),
    );
    if (r == null) return;
    if (r.isDelete) {
      final bool confirm = await _confirmDelete(count: 1);
      if (!confirm) return;
      setState(() => _lastDeleted = note);
      await _delete(note.id);
      _showUndoSnackbar(<Note>[note]);
    } else {
      await _update(note.id, r.title, r.content);
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
    await _deleteMany(_selectedIds);
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
              await _create(n.title, n.content);
            }
          },
        ),
      ),
    );
  }

  bool _isAdmin() {
    final User? u = Supabase.instance.client.auth.currentUser;
    final Map<String, dynamic> app = u?.appMetadata ?? const <String, dynamic>{};
    final Map<String, dynamic> user = u?.userMetadata ?? const <String, dynamic>{};
    final dynamic r1 = app['role'];
    final dynamic r2 = user['role'];
    final dynamic f1 = app['is_admin'] ?? user['is_admin'];
    if (r1 == 'admin') return true;
    if (r2 == 'admin') return true;
    if (f1 == true) return true;
    return false;
  }

  Widget? _adminDrawer() {
    if (!_isAdmin()) return null;
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: <Widget>[
            const ListTile(
              leading: Icon(Icons.admin_panel_settings),
              title: Text('Admin'),
            ),
            ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Nutzer & Notizen'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (BuildContext c) => const AdminUsersPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Statistiken'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (BuildContext c) => const AdminStatsPage()),
              );
            },
            ),
          ],
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
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchCtrl,
        builder: (BuildContext context, TextEditingValue value, Widget? _) {
          final bool hasText = value.text.isNotEmpty;
          return TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: 'Suchen...',
              prefixIcon: const Icon(Icons.search),
              suffixIconConstraints: const BoxConstraints(minWidth: 96),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    onPressed: () {
                      setState(() => _searchQuery = _searchCtrl.text.trim());
                      _searchFocus.requestFocus();
                    },
                    icon: const Icon(Icons.check),
                    tooltip: 'Suche anwenden',
                  ),
                  if (hasText)
                    IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                        _searchFocus.requestFocus();
                      },
                      icon: const Icon(Icons.clear),
                      tooltip: 'Zurücksetzen',
                    ),
                ],
              ),
            ),
            onSubmitted: (String _) {
              setState(() => _searchQuery = _searchCtrl.text.trim());
              _searchFocus.requestFocus();
            },
            textInputAction: TextInputAction.search,
          );
        },
      ),
    );
  }

  Widget _noteTile(Note note) {
    final bool selected = _selectedIds.contains(note.id);
    return GestureDetector(
      onLongPress: () => _toggleSelectionMode(true),
      child: Card(
        child: ListTile(
          leading: _selectionMode
              ? Checkbox(
                  value: selected,
                  onChanged: (bool? v) => _toggleSelected(note.id),
                )
              : null,
          contentPadding: const EdgeInsets.all(16),
          title: Text(
            note.title.isEmpty ? 'Ohne Titel' : note.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  note.content.isEmpty ? 'Ohne Inhalt' : note.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(_formatDate(note.createdAt), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (String v) async {
              if (v == 'open') {
                await Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext c) => NoteDetailPage(note: note)));
              } else if (v == 'edit') {
                await _openEditSheet(note);
              } else if (v == 'dup') {
                await _duplicate(note);
              } else if (v == 'del') {
                final bool ok = await _confirmDelete(count: 1);
                if (!ok) return;
                setState(() => _lastDeleted = note);
                await _delete(note.id);
                _showUndoSnackbar(<Note>[note]);
              }
            },
            itemBuilder: (BuildContext c) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'open', child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Öffnen'))),
              const PopupMenuItem<String>(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Bearbeiten'))),
              const PopupMenuItem<String>(value: 'dup', child: ListTile(leading: Icon(Icons.copy), title: Text('Duplizieren'))),
              const PopupMenuItem<String>(value: 'del', child: ListTile(leading: Icon(Icons.delete), title: Text('Löschen'))),
            ],
          ),
          onTap: () {
            if (_selectionMode) {
              _toggleSelected(note.id);
            } else {
              _openEditSheet(note);
            }
          },
        ),
      ),
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
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
          },
          icon: const Icon(Icons.logout),
          tooltip: 'Abmelden',
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: _buildAppBar(const <Note>[]), body: const Center(child: CircularProgressIndicator()), drawer: _adminDrawer());
        }
        if (snapshot.hasError) {
          return Scaffold(appBar: _buildAppBar(const <Note>[]), body: Center(child: Text('Fehler: ${snapshot.error}')), drawer: _adminDrawer());
        }
        final List<Note> notes = snapshot.data ?? <Note>[];
        final List<Note> visible = _applyClientFilters(notes);
        return Scaffold(
          appBar: _buildAppBar(visible),
          drawer: _adminDrawer(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openCreateSheet,
            icon: const Icon(Icons.add),
            label: const Text('Neu'),
          ),
          body: Column(
            children: <Widget>[
              _buildSearchBar(),
              if (visible.isEmpty)
                const Expanded(child: Center(child: Text('Keine Notizen')))
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final PostgrestTransformBuilder<dynamic> q = _sb.from('notes').select().limit(1);
                      await q;
                    },
                    child: ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (BuildContext context, int i) => _noteTile(visible[i]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class NoteDetailPage extends StatelessWidget {
  final Note note;
  const NoteDetailPage({super.key, required this.note});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notiz')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(note.title.isEmpty ? 'Ohne Titel' : note.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(_formatDateStatic(note.createdAt), style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(note.content.isEmpty ? 'Ohne Inhalt' : note.content, style: Theme.of(context).textTheme.bodyLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateStatic(DateTime dt) {
    final String y = dt.year.toString().padLeft(4, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y, $hh:$mm';
  }
}

class NoteEditorResult {
  final String title;
  final String content;
  final bool isDelete;
  const NoteEditorResult({required this.title, required this.content, required this.isDelete});
}

class NoteEditorSheet extends StatefulWidget {
  final String initialTitle;
  final String initialContent;
  final bool isEditing;
  const NoteEditorSheet({super.key, required this.initialTitle, required this.initialContent, required this.isEditing});
  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl = TextEditingController(text: widget.initialTitle);
  late final TextEditingController _contentCtrl = TextEditingController(text: widget.initialContent);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewInsets = EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom);
    final int chars = _contentCtrl.text.characters.length;
    return Padding(
      padding: viewInsets,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Wrap(
            runSpacing: 12,
            children: <Widget>[
              Text(widget.isEditing ? 'Notiz bearbeiten' : 'Neue Notiz', style: Theme.of(context).textTheme.titleLarge),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Titel'),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                controller: _contentCtrl,
                decoration: InputDecoration(labelText: 'Inhalt', helperText: '$chars Zeichen'),
                maxLines: 8,
                onChanged: (String _) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  if (widget.isEditing)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop(const NoteEditorResult(title: '', content: '', isDelete: true));
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Löschen'),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      final bool ok = _formKey.currentState?.validate() ?? false;
                      if (!ok) return;
                      Navigator.of(context).pop(
                        NoteEditorResult(title: _titleCtrl.text.trim(), content: _contentCtrl.text.trim(), isDelete: false),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: Text(widget.isEditing ? 'Speichern' : 'Erstellen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
