import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String SUPABASE_URL = 'https://qjojmiexgnxmibqcblqj.supabase.co';
const String SUPABASE_ANON_KEY =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqb2ptaWV4Z254bWlicWNibHFqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYwMzQwNzksImV4cCI6MjA3MTYxMDA3OX0.CQv4sm0uDUSrFRoiroaUKUXIQuq-uoCyZCx-95uYw-Y';

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
      home: const NoteListPage(),
    );
  }
}

class Note {
  final int id;
  final String title;
  final String content;
  final DateTime createdAt;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory Note.fromMap(Map<String, dynamic> m) {
    final int id = (m['id'] as num).toInt();
    final String title = (m['title'] as String?) ?? '';
    final String content = (m['content'] as String?) ?? '';
    final DateTime createdAt = DateTime.parse(
      (m['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
    return Note(id: id, title: title, content: content, createdAt: createdAt);
  }
}

class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});
  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  SupabaseClient get _sb => Supabase.instance.client;

  Future<void> _create(String title, String content) async {
    await _sb.from('notes').insert(<String, dynamic>{'title': title, 'content': content});
  }

  Future<void> _update(int id, String title, String content) async {
    await _sb.from('notes').update(<String, dynamic>{'title': title, 'content': content}).eq('id', id);
  }

  Future<void> _delete(int id) async {
    await _sb.from('notes').delete().eq('id', id);
  }

  Stream<List<Note>> _noteStream() {
    final Stream<List<Map<String, dynamic>>> s = _sb
        .from('notes')
        .stream(primaryKey: <String>['id'])
        .order('created_at', ascending: false);
    return s.map((List<Map<String, dynamic>> rows) => rows.map((Map<String, dynamic> m) => Note.fromMap(m)).toList());
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
      builder: (BuildContext c) => NoteEditorSheet(
        initialTitle: '',
        initialContent: '',
        isEditing: false,
      ),
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
      builder: (BuildContext c) => NoteEditorSheet(
        initialTitle: note.title,
        initialContent: note.content,
        isEditing: true,
      ),
    );
    if (r == null) return;
    if (r.isDelete) {
      await _delete(note.id);
    } else {
      await _update(note.id, r.title, r.content);
    }
  }

  Widget _noteCard(BuildContext context, Note note) {
    return Card(
      child: ListTile(
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
            children: [
              Text(
                note.content.isEmpty ? 'Ohne Inhalt' : note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(note.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _delete(note.id),
        ),
        onTap: () => _openEditSheet(note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notizen')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Neu'),
      ),
      body: StreamBuilder<List<Note>>(
        stream: _noteStream(),
        builder: (BuildContext context, AsyncSnapshot<List<Note>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final List<Note> notes = snapshot.data ?? <Note>[];
          if (notes.isEmpty) {
            return const Center(child: Text('Keine Notizen'));
          }
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (BuildContext context, int i) => _noteCard(context, notes[i]),
          );
        },
      ),
    );
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
  const NoteEditorSheet({
    super.key,
    required this.initialTitle,
    required this.initialContent,
    required this.isEditing,
  });
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
                decoration: const InputDecoration(labelText: 'Inhalt'),
                maxLines: 8,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  if (widget.isEditing)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop(
                          const NoteEditorResult(title: '', content: '', isDelete: true),
                        );
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Löschen'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      final bool ok = _formKey.currentState?.validate() ?? false;
                      if (!ok) return;
                      Navigator.of(context).pop(
                        NoteEditorResult(
                          title: _titleCtrl.text.trim(),
                          content: _contentCtrl.text.trim(),
                          isDelete: false,
                        ),
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






// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// const String SUPABASE_URL = 'https://qjojmiexgnxmibqcblqj.supabase.co';
// const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqb2ptaWV4Z254bWlicWNibHFqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYwMzQwNzksImV4cCI6MjA3MTYxMDA3OX0.CQv4sm0uDUSrFRoiroaUKUXIQuq-uoCyZCx-95uYw-Y';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
//   runApp(const CrudApp());
// }

// class CrudApp extends StatelessWidget {
//   const CrudApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'CRUD Demo',
//       theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
//       home: const NoteListPage(),
//     );
//   }
// }

// class Note {
//   final int id;
//   final String title;
//   final String content;
//   final DateTime createdAt;
//   const Note({required this.id, required this.title, required this.content, required this.createdAt});
//   factory Note.fromMap(Map<String, dynamic> m) {
//     final int id = (m['id'] as num).toInt();
//     final String title = (m['title'] as String?) ?? '';
//     final String content = (m['content'] as String?) ?? '';
//     final DateTime createdAt = DateTime.parse((m['created_at'] as String?) ?? DateTime.now().toIso8601String());
//     return Note(id: id, title: title, content: content, createdAt: createdAt);
//   }
//   Map<String, dynamic> toMap() {
//     return <String, dynamic>{
//       'id': id,
//       'title': title,
//       'content': content,
//       'created_at': createdAt.toIso8601String(),
//     };
//   }
//   Note copyWith({int? id, String? title, String? content, DateTime? createdAt}) {
//     return Note(
//       id: id ?? this.id,
//       title: title ?? this.title,
//       content: content ?? this.content,
//       createdAt: createdAt ?? this.createdAt,
//     );
//   }
// }

// class NoteListPage extends StatefulWidget {
//   const NoteListPage({super.key});
//   @override
//   State<NoteListPage> createState() => _NoteListPageState();
// }

// class _NoteListPageState extends State<NoteListPage> {
//   SupabaseClient get _sb => Supabase.instance.client;

//   Future<void> _create(String title, String content) async {
//     await _sb.from('notes').insert(<String, dynamic>{'title': title, 'content': content});
//   }

//   Future<void> _update(Note note, String title, String content) async {
//     await _sb.from('notes').update(<String, dynamic>{'title': title, 'content': content}).eq('id', note.id);
//   }

//   Future<void> _delete(int id) async {
//     await _sb.from('notes').delete().eq('id', id);
//   }

//   Stream<List<Note>> _noteStream() {
//     final Stream<List<Map<String, dynamic>>> s = _sb
//         .from('notes')
//         .stream(primaryKey: <String>['id'])
//         .order('created_at', ascending: false);
//     return s.map((List<Map<String, dynamic>> rows) => rows.map((Map<String, dynamic> m) => Note.fromMap(m)).toList());
//   }

//   Future<void> _openEditor({Note? note}) async {
//     final NoteEditorResult? result = await showModalBottomSheet<NoteEditorResult>(
//       context: context,
//       isScrollControlled: true,
//       builder: (BuildContext context) {
//         return NoteEditorSheet(
//           initialTitle: note?.title ?? '',
//           initialContent: note?.content ?? '',
//           isEditing: note != null,
//         );
//       },
//     );
//     if (!mounted) return;
//     if (result == null) return;
//     if (result.isDelete && note != null) {
//       await _delete(note.id);
//       return;
//     }
//     if (note == null) {
//       await _create(result.title, result.content);
//     } else {
//       await _update(note, result.title, result.content);
//     }
//   }

//   void _openDetails(Note note) {
//     Navigator.of(context).push(MaterialPageRoute<Widget>(
//       builder: (BuildContext context) {
//         return NoteDetailPage(
//           note: note,
//           onEdit: () => _openEditor(note: note),
//           onDelete: () async {
//             await _delete(note.id);
//             if (mounted) Navigator.of(context).pop();
//           },
//         );
//       },
//     ));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Notizen')),
//       body: StreamBuilder<List<Note>>(
//         stream: _noteStream(),
//         builder: (BuildContext context, AsyncSnapshot<List<Note>> snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
//           if (snapshot.hasError) return Center(child: Text('Fehler: ${snapshot.error}'));
//           final List<Note> notes = snapshot.data ?? <Note>[];
//           if (notes.isEmpty) return const Center(child: Text('Keine Notizen'));
//           return ListView.builder(
//             itemCount: notes.length,
//             itemBuilder: (BuildContext context, int index) {
//               final Note note = notes[index];
//               return Dismissible(
//                 key: ValueKey<int>(note.id),
//                 direction: DismissDirection.endToStart,
//                 onDismissed: (DismissDirection d) async {
//                   await _delete(note.id);
//                 },
//                 background: Container(
//                   alignment: Alignment.centerRight,
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   color: Theme.of(context).colorScheme.errorContainer,
//                   child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onErrorContainer),
//                 ),
//                 child: ListTile(
//                   title: Text(note.title.isEmpty ? 'Ohne Titel' : note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
//                   subtitle: Text(note.content.isEmpty ? 'Ohne Inhalt' : note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
//                   onTap: () => _openDetails(note),
//                   trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _openEditor(note: note)),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () => _openEditor(),
//         icon: const Icon(Icons.add),
//         label: const Text('Neu'),
//       ),
//     );
//   }
// }

// class NoteDetailPage extends StatelessWidget {
//   final Note note;
//   final VoidCallback onEdit;
//   final VoidCallback onDelete;
//   const NoteDetailPage({super.key, required this.note, required this.onEdit, required this.onDelete});

//   String _formatDate(DateTime dt) {
//     final String y = dt.year.toString().padLeft(4, '0');
//     final String m = dt.month.toString().padLeft(2, '0');
//     final String d = dt.day.toString().padLeft(2, '0');
//     final String hh = dt.hour.toString().padLeft(2, '0');
//     final String mm = dt.minute.toString().padLeft(2, '0');
//     return '$d.$m.$y, $hh:$mm';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Details'),
//         actions: <Widget>[
//           IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
//           IconButton(onPressed: onDelete, icon: const Icon(Icons.delete)),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: <Widget>[
//             Text(note.title.isEmpty ? 'Ohne Titel' : note.title, style: Theme.of(context).textTheme.headlineSmall),
//             const SizedBox(height: 8),
//             Text('Erstellt: ${_formatDate(note.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
//             const Divider(height: 24),
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Text(note.content.isEmpty ? 'Ohne Inhalt' : note.content, style: Theme.of(context).textTheme.bodyLarge),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class NoteEditorResult {
//   final String title;
//   final String content;
//   final bool isDelete;
//   const NoteEditorResult({required this.title, required this.content, required this.isDelete});
// }

// class NoteEditorSheet extends StatefulWidget {
//   final String initialTitle;
//   final String initialContent;
//   final bool isEditing;
//   const NoteEditorSheet({super.key, required this.initialTitle, required this.initialContent, required this.isEditing});
//   @override
//   State<NoteEditorSheet> createState() => _NoteEditorSheetState();
// }

// class _NoteEditorSheetState extends State<NoteEditorSheet> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   late final TextEditingController _titleCtrl = TextEditingController(text: widget.initialTitle);
//   late final TextEditingController _contentCtrl = TextEditingController(text: widget.initialContent);

//   @override
//   void dispose() {
//     _titleCtrl.dispose();
//     _contentCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final EdgeInsets viewInsets = MediaQuery.of(context).viewInsets;
//     return Padding(
//       padding: EdgeInsets.only(bottom: viewInsets.bottom),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Wrap(
//             runSpacing: 12,
//             children: <Widget>[
//               Text(widget.isEditing ? 'Notiz bearbeiten' : 'Neue Notiz', style: Theme.of(context).textTheme.titleLarge),
//               TextFormField(
//                 controller: _titleCtrl,
//                 decoration: const InputDecoration(labelText: 'Titel'),
//                 validator: (String? v) {
//                   if (v == null) return 'Pflichtfeld';
//                   if (v.trim().isEmpty) return 'Pflichtfeld';
//                   return null;
//                 },
//                 textInputAction: TextInputAction.next,
//               ),
//               TextFormField(
//                 controller: _contentCtrl,
//                 decoration: const InputDecoration(labelText: 'Inhalt'),
//                 maxLines: 8,
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 children: <Widget>[
//                   if (widget.isEditing)
//                     FilledButton.tonalIcon(
//                       onPressed: () {
//                         Navigator.of(context).pop(NoteEditorResult(title: _titleCtrl.text.trim(), content: _contentCtrl.text.trim(), isDelete: true));
//                       },
//                       icon: const Icon(Icons.delete),
//                       label: const Text('Löschen'),
//                     ),
//                   const Spacer(),
//                   TextButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                     },
//                     child: const Text('Abbrechen'),
//                   ),
//                   const SizedBox(width: 8),
//                   FilledButton.icon(
//                     onPressed: () {
//                       final bool ok = _formKey.currentState?.validate() ?? false;
//                       if (!ok) return;
//                       Navigator.of(context).pop(NoteEditorResult(title: _titleCtrl.text.trim(), content: _contentCtrl.text.trim(), isDelete: false));
//                     },
//                     icon: const Icon(Icons.check),
//                     label: Text(widget.isEditing ? 'Speichern' : 'Erstellen'),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
