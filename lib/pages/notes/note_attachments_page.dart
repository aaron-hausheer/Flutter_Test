import 'package:flutter/material.dart';
import '../../models/attachment.dart';
import '../../services/attachments_service.dart';

class NoteAttachmentsPage extends StatefulWidget {
  final int noteId;
  const NoteAttachmentsPage({super.key, required this.noteId});
  @override
  State<NoteAttachmentsPage> createState() => _NoteAttachmentsPageState();
}

class _NoteAttachmentsPageState extends State<NoteAttachmentsPage> {
  final AttachmentsService _svc = AttachmentsService();
  bool _loading = true;
  List<Attachment> _items = const <Attachment>[];
  final Map<String, String> _urls = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final List<Attachment> list = await _svc.listForNote(widget.noteId);
    final Map<String, String> u = <String, String>{};
    for (final Attachment a in list) {
      u[a.path] = await _svc.signedUrl(a.path);
    }
    if (!mounted) return;
    setState(() {
      _items = list;
      _urls
        ..clear()
        ..addAll(u);
      _loading = false;
    });
  }

  Future<void> _upload() async {
    await _svc.uploadPicker(widget.noteId);
    await _load();
  }

  Future<void> _delete(Attachment a) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Bild löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Abbrechen')),
          FilledButton.tonal(onPressed: () => Navigator.of(c).pop(true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.deleteAttachment(a);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final int count = _items.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Bilder')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _upload, icon: const Icon(Icons.add_a_photo), label: const Text('Hochladen')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: count == 0
            ? const Center(child: Text('Keine Bilder'))
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: count,
                itemBuilder: (BuildContext context, int i) {
                  final Attachment a = _items[i];
                  final String? url = _urls[a.path];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (url != null) Image.network(url, fit: BoxFit.cover),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Material(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                            child: IconButton(
                              onPressed: () => _delete(a),
                              icon: const Icon(Icons.delete, size: 18, color: Colors.white),
                              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
