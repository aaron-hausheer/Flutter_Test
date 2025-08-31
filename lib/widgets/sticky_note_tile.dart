import 'package:flutter/material.dart';

class StickyNoteTile extends StatelessWidget {
  final String title;
  final String content;
  final String footer;
  final bool selectionMode;
  final bool selected;
  final Color tileColor;
  final bool isFavorite;
  final bool inTrash;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  const StickyNoteTile({
    super.key,
    required this.title,
    required this.content,
    required this.footer,
    required this.selectionMode,
    required this.selected,
    required this.tileColor,
    required this.isFavorite,
    required this.inTrash,
    required this.onTap,
    required this.onLongPress,
    required this.onOpen,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onRestore,
    required this.onPurge,
  });

  @override
  Widget build(BuildContext context) {
    final Brightness b = ThemeData.estimateBrightnessForColor(tileColor);
    final Color fg = b == Brightness.dark ? Colors.white : Colors.black87;
    final TextStyle titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(color: fg, fontWeight: FontWeight.w600);
    final TextStyle bodyStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(color: fg.withOpacity(0.95));
    final TextStyle footStyle = Theme.of(context).textTheme.bodySmall!.copyWith(color: fg.withOpacity(0.9));

    return Material(
      color: tileColor,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(title.isEmpty ? 'Ohne Titel' : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle)),
                  if (!inTrash)
                    IconButton(
                      onPressed: onToggleFavorite,
                      icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: fg),
                      tooltip: isFavorite ? 'Favorit entfernen' : 'Als Favorit markieren',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: Text(content.isEmpty ? 'Ohne Inhalt' : content, maxLines: 8, overflow: TextOverflow.ellipsis, style: bodyStyle)),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(child: Text(footer, style: footStyle)),
                  PopupMenuButton<String>(
                    tooltip: 'Aktionen',
                    icon: Icon(Icons.more_horiz, color: fg),
                    itemBuilder: (BuildContext c) {
                      if (inTrash) {
                        return <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(value: 'restore', child: ListTile(leading: Icon(Icons.restore), title: Text('Wiederherstellen'))),
                          const PopupMenuItem<String>(value: 'purge', child: ListTile(leading: Icon(Icons.delete_forever), title: Text('Endgültig löschen'))),
                        ];
                      }
                      return <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(value: 'open', child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Öffnen'))),
                        const PopupMenuItem<String>(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Bearbeiten'))),
                        const PopupMenuItem<String>(value: 'dup', child: ListTile(leading: Icon(Icons.copy), title: Text('Duplizieren'))),
                        const PopupMenuItem<String>(value: 'del', child: ListTile(leading: Icon(Icons.delete), title: Text('In Papierkorb'))),
                      ];
                    },
                    onSelected: (String v) {
                      if (v == 'open') onOpen();
                      if (v == 'edit') onEdit();
                      if (v == 'dup') onDuplicate();
                      if (v == 'del') onDelete();
                      if (v == 'restore') onRestore();
                      if (v == 'purge') onPurge();
                    },
                  ),
                ],
              ),
              if (selectionMode)
                Align(
                  alignment: Alignment.topLeft,
                  child: Checkbox(value: selected, onChanged: (_) => onTap()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
