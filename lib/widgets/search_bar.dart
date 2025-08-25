import 'package:flutter/material.dart';

class SubmitSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onApply;
  const SubmitSearchBar({super.key, required this.controller, required this.focusNode, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Suchen...',
            prefixIcon: const Icon(Icons.search),
            suffixIconConstraints: const BoxConstraints(minWidth: 96),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  onPressed: () {
                    onApply(controller.text.trim());
                    focusNode.requestFocus();
                  },
                  icon: const Icon(Icons.check),
                  tooltip: 'Suche anwenden',
                ),
                if (hasText)
                  IconButton(
                    onPressed: () {
                      controller.clear();
                      onApply('');
                      focusNode.requestFocus();
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Zurücksetzen',
                  ),
              ],
            ),
          ),
          onSubmitted: (String _) {
            onApply(controller.text.trim());
            focusNode.requestFocus();
          },
          textInputAction: TextInputAction.search,
        );
      },
    );
  }
}
