import 'package:flutter/material.dart';
import '../models/group.dart';

class NoteEditorResult {
  final String title;
  final String content;
  final bool isDelete;
  final int? groupId;
  const NoteEditorResult({required this.title, required this.content, required this.isDelete, required this.groupId});
}

class NoteEditorSheet extends StatefulWidget {
  final String initialTitle;
  final String initialContent;
  final bool isEditing;
  final List<Group> groups;
  final int? initialGroupId;

  const NoteEditorSheet({
    super.key,
    required this.initialTitle,
    required this.initialContent,
    required this.isEditing,
    required this.groups,
    required this.initialGroupId,
  });

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl = TextEditingController(text: widget.initialTitle);
  late final TextEditingController _contentCtrl = TextEditingController(text: widget.initialContent);
  int? _groupId;

  @override
  void initState() {
    super.initState();
    _groupId = widget.initialGroupId;
  }

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
              DropdownButtonFormField<int?>(
                value: _groupId,
                decoration: const InputDecoration(labelText: 'Gruppe'),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(value: null, child: Text('Keine')),
                  ...widget.groups.map((Group g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.name))),
                ],
                onChanged: (int? v) => setState(() => _groupId = v),
              ),
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
                        Navigator.of(context).pop(
                          const NoteEditorResult(title: '', content: '', isDelete: true, groupId: null),
                        );
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
                        NoteEditorResult(
                          title: _titleCtrl.text.trim(),
                          content: _contentCtrl.text.trim(),
                          isDelete: false,
                          groupId: _groupId,
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
