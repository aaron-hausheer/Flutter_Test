// lib/pages/notes/note_detail_page.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/note.dart';
import '../../models/group.dart';
import '../../models/tag.dart';

import '../../services/notes_service.dart';
import '../../services/groups_service.dart';
import '../../services/attachments_service.dart';
import '../../services/tags_service.dart';

class NoteDetailPage extends StatefulWidget {
  final Note note;
  const NoteDetailPage({super.key, required this.note});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  // Services
  final NotesService _notes = NotesService();
  final GroupsService _groups = GroupsService();
  final AttachmentsService _attachments = AttachmentsService();
  final TagsService _tags = TagsService();

  // Controllers
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.note.title);
  late final TextEditingController _contentCtrl =
      TextEditingController(text: widget.note.content);
  final TextEditingController _tagCtrl = TextEditingController();

  // State
  int? _groupId;
  bool _favorite = false;
  bool _saving = false;

  // Attachments
  List<AttachmentItem> _files = const <AttachmentItem>[];
  bool _loadingFiles = true;

  // Tags
  List<Tag> _allTags = const <Tag>[];
  Set<int> _selectedTagIds = <int>{};
  bool _busyAddTag = false;
  bool _loadingTags = true;

  @override
  void initState() {
    super.initState();
    _groupId = widget.note.groupId;
    _favorite = widget.note.isFavorite;
    _reloadFiles();
    _reloadTags();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  // -------------------- Attachments --------------------

  Future<void> _reloadFiles() async {
    setState(() => _loadingFiles = true);
    try {
      final List<AttachmentItem> list = await _attachments.list(widget.note.id);
      if (!mounted) return;
      setState(() {
        _files = list;
        _loadingFiles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFiles = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anhänge laden fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _pickAndUpload() async {
    try {
      final FilePickerResult? res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        withReadStream: true, // Desktop/Web sicher
        type: FileType.image,
      );
      if (res == null || res.files.isEmpty) return;

      await _attachments.uploadFiles(widget.note.id, res.files);
      await _reloadFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${res.files.length} Bild(er) hochgeladen')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _removeAttachment(AttachmentItem a) async {
    try {
      await _attachments.remove(a.id, a.path);
      await _reloadFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
      );
    }
  }

  void _openImage(String url) {
    showDialog<void>(
      context: context,
      builder: (BuildContext c) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(32),
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Icon(Icons.broken_image, size: 48)),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------- Tags --------------------

  Future<void> _reloadTags() async {
    setState(() => _loadingTags = true);
    try {
      final List<Tag> all = await _tags.fetchAllForCurrentUser();
      final List<Tag> noteTags = await _tags.tagsForNote(widget.note.id);
      if (!mounted) return;
      setState(() {
        _allTags = all
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _selectedTagIds = noteTags.map((t) => t.id).toSet();
        _loadingTags = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTags = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tags laden fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _toggleTag(Tag t, bool select) async {
    setState(() {
      if (select) {
        _selectedTagIds.add(t.id);
      } else {
        _selectedTagIds.remove(t.id);
      }
    });
    try {
      if (select) {
        await _tags.addTagToNote(widget.note.id, t.id);
      } else {
        await _tags.removeTagFromNote(widget.note.id, t.id);
      }
    } catch (e) {
      // Revert UI on failure
      setState(() {
        if (select) {
          _selectedTagIds.remove(t.id);
        } else {
          _selectedTagIds.add(t.id);
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tag-Änderung fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _addTagByName() async {
    final String name = _tagCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _busyAddTag = true);
    try {
      final Tag t = await _tags.createIfMissing(name);
      if (!_allTags.any((Tag e) => e.id == t.id)) {
        setState(() => _allTags = <Tag>[..._allTags, t]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
      }
      await _tags.addTagToNote(widget.note.id, t.id);
      if (!mounted) return;
      setState(() {
        _selectedTagIds.add(t.id);
        _tagCtrl.clear();
        _busyAddTag = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyAddTag = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tag hinzufügen fehlgeschlagen: $e')),
      );
    }
  }

  // -------------------- Core actions --------------------

  Future<List<Group>> _loadGroups() => _groups.fetchAllForCurrentUser();

  Future<void> _toggleFavorite() async {
    final bool next = !_favorite;
    setState(() => _favorite = next);
    try {
      await _notes.setFavorite(widget.note.id, next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _favorite = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _save() async {
    final String t = _titleCtrl.text.trim();
    final String c = _contentCtrl.text.trim();
    setState(() => _saving = true);
    try {
      await _notes.update(widget.note.id, t, c, groupId: _groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gespeichert')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _moveToTrash() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('In Papierkorb verschieben?'),
        content: const Text('Dies kann rückgängig gemacht werden.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Abbrechen')),
          FilledButton.tonal(onPressed: () => Navigator.of(c).pop(true), child: const Text('Verschieben')),
        ],
      ),
    );
    if (ok != true) return;
    await _notes.moveToTrash(widget.note.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _restore() async {
    await _notes.restore(widget.note.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wiederhergestellt')),
    );
  }

  Future<void> _purge() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Endgültig löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Abbrechen')),
          FilledButton.tonal(onPressed: () => Navigator.of(c).pop(true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    await _notes.purge(widget.note.id);
    if (mounted) Navigator.of(context).pop();
  }

  // -------------------- UI helpers --------------------

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
    final bool inTrash = widget.note.deletedAt != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notiz'),
        actions: <Widget>[
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(_favorite ? Icons.star : Icons.star_border),
            tooltip: _favorite ? 'Favorit entfernen' : 'Als Favorit markieren',
          ),
          if (!inTrash)
            IconButton(onPressed: _moveToTrash, icon: const Icon(Icons.delete_outline), tooltip: 'In Papierkorb')
          else ...<Widget>[
            IconButton(onPressed: _restore, icon: const Icon(Icons.restore), tooltip: 'Wiederherstellen'),
            IconButton(onPressed: _purge, icon: const Icon(Icons.delete_forever), tooltip: 'Endgültig löschen'),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (inTrash || _saving) ? null : _save,
        icon: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.check),
        label: const Text('Speichern'),
      ),
      body: FutureBuilder<List<Group>>(
        future: _loadGroups(),
        builder: (BuildContext context, AsyncSnapshot<List<Group>> snap) {
          final List<Group> groups = snap.data ?? const <Group>[];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: <Widget>[
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titel'),
                  textInputAction: TextInputAction.next,
                  readOnly: inTrash,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _groupId,
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(value: null, child: Text('Keine Gruppe')),
                    ...groups.map((Group g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.name))),
                  ],
                  onChanged: inTrash ? null : (int? v) => setState(() => _groupId = v),
                  decoration: const InputDecoration(labelText: 'Gruppe'),
                ),
                const SizedBox(height: 12),
                Text(_formatDate(widget.note.createdAt), style: Theme.of(context).textTheme.bodySmall),
                const Divider(height: 24),
                TextField(
                  controller: _contentCtrl,
                  decoration: const InputDecoration(labelText: 'Inhalt'),
                  maxLines: 12,
                  readOnly: inTrash,
                ),

                // -------------------- Tags section --------------------
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Text('Tags', style: Theme.of(context).textTheme.titleMedium),
                    if (_loadingTags) ...<Widget>[
                      const SizedBox(width: 8),
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (_allTags.isEmpty && !_loadingTags)
                  const Text('Keine Tags vorhanden')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allTags.map((Tag t) {
                      final bool sel = _selectedTagIds.contains(t.id);
                      return FilterChip(
                        selected: sel,
                        label: Text(t.name),
                        onSelected: inTrash ? null : (bool s) => _toggleTag(t, s),
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
                        onSubmitted: (_) => inTrash ? null : _addTagByName(),
                        enabled: !inTrash && !_busyAddTag,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: inTrash || _busyAddTag ? null : _addTagByName,
                      icon: _busyAddTag
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add),
                      label: const Text('Hinzufügen'),
                    ),
                  ],
                ),

                // -------------------- Attachments section --------------------
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    Text('Anhänge', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: inTrash ? null : _pickAndUpload,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Bilder hinzufügen'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loadingFiles)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                else if (_files.isEmpty)
                  const Text('Keine Bilder')
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _files.length,
                    itemBuilder: (BuildContext context, int i) {
                      final AttachmentItem a = _files[i];
                      return InkWell(
                        onTap: () => _openImage(a.url),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                a.url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Color(0x11000000),
                                  child: Center(child: Icon(Icons.broken_image)),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  onPressed: inTrash ? null : () => _removeAttachment(a),
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                  tooltip: 'Entfernen',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
