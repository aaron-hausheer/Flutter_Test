import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/tag.dart';
import '../services/tags_service.dart';

class NoteEditorResult {
  final String title;
  final String content;
  final bool isDelete;
  final int? groupId;
  final List<int> tagIds;
  final List<PlatformFile> images;
  const NoteEditorResult({
    required this.title,
    required this.content,
    required this.isDelete,
    required this.groupId,
    required this.tagIds,
    required this.images,
  });
}

class NoteEditorSheet extends StatefulWidget {
  final String initialTitle;
  final String initialContent;
  final bool isEditing;
  final List<Group> groups;
  final int? initialGroupId;
  final List<Tag> availableTags;
  final List<int> initialTagIds;

  const NoteEditorSheet({
    super.key,
    required this.initialTitle,
    required this.initialContent,
    required this.isEditing,
    required this.groups,
    required this.initialGroupId,
    required this.availableTags,
    required this.initialTagIds,
  });

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl = TextEditingController(text: widget.initialTitle);
  late final TextEditingController _contentCtrl = TextEditingController(text: widget.initialContent);
  final TextEditingController _tagCtrl = TextEditingController();

  int? _groupId;
  late List<Tag> _allTags = widget.availableTags;
  late final Set<int> _selectedTagIds = widget.initialTagIds.toSet();
  bool _busyAddTag = false;

  List<PlatformFile> _picked = <PlatformFile>[];

  @override
  void initState() {
    super.initState();
    _groupId = widget.initialGroupId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _addTagByName() async {
    final String name = _tagCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _busyAddTag = true);
    final TagsService svc = TagsService();
    final Tag t = await svc.createIfMissing(name);
    final List<Tag> next = List<Tag>.from(_allTags);
    final bool exists = next.any((Tag e) => e.id == t.id);
    if (!exists) next.add(t);
    setState(() {
      _allTags = next..sort((Tag a, Tag b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _selectedTagIds.add(t.id);
      _tagCtrl.clear();
      _busyAddTag = false;
    });
  }

  Future<void> _pickImages() async {
    final FilePickerResult? res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image, withData: true);
    if (res == null) return;
    final List<PlatformFile> files = res.files.where((PlatformFile f) => f.bytes != null && f.bytes!.isNotEmpty).toList();
    if (files.isEmpty) return;
    setState(() {
      _picked = <PlatformFile>[..._picked, ...files];
    });
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
          child: SingleChildScrollView(
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
                DropdownButtonFormField<int>(
                  value: _groupId,
                  items: <DropdownMenuItem<int>>[
                    const DropdownMenuItem<int>(value: null, child: Text('Keine Gruppe')),
                    ...widget.groups.map((Group g) => DropdownMenuItem<int>(value: g.id, child: Text(g.name))),
                  ],
                  onChanged: (int? v) => setState(() => _groupId = v),
                  decoration: const InputDecoration(labelText: 'Gruppe'),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Tags'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allTags.map((Tag t) {
                        final bool sel = _selectedTagIds.contains(t.id);
                        return FilterChip(
                          selected: sel,
                          label: Text(t.name),
                          onSelected: (bool s) {
                            setState(() {
                              if (s) {
                                _selectedTagIds.add(t.id);
                              } else {
                                _selectedTagIds.remove(t.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _tagCtrl,
                            decoration: const InputDecoration(labelText: 'Neuen Tag hinzufügen'),
                            onSubmitted: (_) => _addTagByName(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _busyAddTag ? null : _addTagByName,
                          icon: _busyAddTag ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
                          label: const Text('Hinzufügen'),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Bilder'),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        FilledButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_a_photo), label: const Text('Bilder hinzufügen')),
                        const SizedBox(width: 12),
                        if (_picked.isNotEmpty) Text('${_picked.length} ausgewählt'),
                      ],
                    ),
                    if (_picked.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List<Widget>.generate(_picked.length, (int i) {
                            final PlatformFile f = _picked[i];
                            final Uint8List bytes = f.bytes!;
                            return Stack(
                              alignment: Alignment.topRight,
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(bytes, height: 72, width: 72, fit: BoxFit.cover),
                                ),
                                Material(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _picked = <PlatformFile>[
                                          ..._picked.take(i),
                                          ..._picked.skip(i + 1),
                                        ];
                                      });
                                    },
                                    child: const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    if (widget.isEditing)
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.of(context).pop(
                            NoteEditorResult(
                              title: '',
                              content: '',
                              isDelete: true,
                              groupId: null,
                              tagIds: <int>[],
                              images: <PlatformFile>[],
                            ),
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
                            tagIds: _selectedTagIds.toList(),
                            images: _picked,
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
      ),
    );
  }
}
