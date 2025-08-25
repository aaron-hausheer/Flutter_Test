import 'package:flutter/material.dart';
import '../models/group.dart';

class GroupFilterBar extends StatelessWidget {
  final List<Group> groups;
  final int? selectedGroupId;
  final void Function(int?) onSelected;
  final VoidCallback onCreateTap;

  const GroupFilterBar({super.key, required this.groups, required this.selectedGroupId, required this.onSelected, required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('Alle'),
              selected: selectedGroupId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...groups.map((Group g) {
            final bool sel = selectedGroupId == g.id;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(g.name),
                selected: sel,
                onSelected: (_) => onSelected(g.id),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              label: const Text('Neue Gruppe'),
              onPressed: onCreateTap,
            ),
          ),
        ],
      ),
    );
  }
}
