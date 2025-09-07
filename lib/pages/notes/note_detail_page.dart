import 'package:flutter/material.dart';
import '../../models/note.dart';
import '../../models/attachment.dart';
import '../../services/attachments_service.dart';

class NoteDetailPage extends StatefulWidget {
  final Note note;
  const NoteDetailPage({super.key, required this.note});
  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
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
    final List<Attachment> list = await _svc.listForNote(widget.note.id);
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notiz')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            SelectableText(widget.note.title.isEmpty ? 'Ohne Titel' : widget.note.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(_formatDate(widget.note.createdAt), style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 24),
            SelectableText(widget.note.content.isEmpty ? 'Ohne Inhalt' : widget.note.content, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            if (_items.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: _items.length,
                itemBuilder: (BuildContext context, int i) {
                  final Attachment a = _items[i];
                  final String? url = _urls[a.path];
                  if (url == null) {
                    return const SizedBox.shrink();
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, fit: BoxFit.cover),
                  );
                },
              )
            else
              const Text('Keine Bilder'),
          ],
        ),
      ),
    );
  }
}
