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
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRestore;
  final VoidCallback onPurge;
  final List<String> previewImageUrls;

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
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onRestore,
    required this.onPurge,
    this.previewImageUrls = const <String>[],
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: <BoxShadow>[
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'Ohne Titel' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (selectionMode)
                    Checkbox(value: selected, onChanged: (_) => onLongPress())
                  else
                    IconButton(
                      onPressed: onToggleFavorite,
                      icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                      tooltip: 'Favorit',
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  content.isEmpty ? 'Ohne Inhalt' : content,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (previewImageUrls.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                SizedBox(
                  height: 54,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: previewImageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (BuildContext context, int i) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(previewImageUrls[i], width: 72, height: 54, fit: BoxFit.cover),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Text(footer, style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  if (inTrash)
                    Row(
                      children: <Widget>[
                        IconButton(onPressed: onRestore, icon: const Icon(Icons.restore), tooltip: 'Wiederherstellen'),
                        IconButton(onPressed: onPurge, icon: const Icon(Icons.delete_forever), tooltip: 'Endgültig löschen'),
                      ],
                    )
                  else
                    IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline), tooltip: 'In Papierkorb'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
