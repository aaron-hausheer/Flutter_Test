import 'package:flutter/material.dart';

class StickyNoteTile extends StatelessWidget {
  final String title;
  final String content;
  final String footer;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final Color tileColor;

  const StickyNoteTile({
    super.key,
    required this.title,
    required this.content,
    required this.footer,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onOpen,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.tileColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Transform.rotate(
        angle: selectionMode ? 0 : (((title.hashCode % 5) - 2) * 0.0025),
        child: Container(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title.isEmpty ? 'Ohne Titel' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      content.isEmpty ? 'Ohne Inhalt' : content,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    footer,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: selectionMode
                    ? Checkbox(value: selected, onChanged: (_) => onTap())
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.black54),
                        onSelected: (String v) {
                          if (v == 'open') onOpen();
                          if (v == 'edit') onEdit();
                          if (v == 'dup') onDuplicate();
                          if (v == 'del') onDelete();
                        },
                        itemBuilder: (BuildContext c) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(value: 'open', child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Öffnen'))),
                          const PopupMenuItem<String>(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Bearbeiten'))),
                          const PopupMenuItem<String>(value: 'dup', child: ListTile(leading: Icon(Icons.copy), title: Text('Duplizieren'))),
                          const PopupMenuItem<String>(value: 'del', child: ListTile(leading: Icon(Icons.delete), title: Text('Löschen'))),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
