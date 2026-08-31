import 'package:flutter/material.dart';

/// Visible guidance that also works on touch devices without hovering.
class ScreenHint extends StatelessWidget {
  const ScreenHint({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.onPrimaryContainer, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(message,
                    style: TextStyle(color: colors.onPrimaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
