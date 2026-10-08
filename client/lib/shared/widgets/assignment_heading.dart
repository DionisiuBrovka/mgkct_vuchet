import 'package:flutter/material.dart';

class AssignmentHeading extends StatelessWidget {
  const AssignmentHeading(
      {super.key, required this.subject, required this.group});

  final String subject, group;

  static const _groupColors = [
    (Color(0xFFE3F4EA), Color(0xFF205B38)),
    (Color(0xFFFFEBDD), Color(0xFF884317)),
    (Color(0xFFEDE5FA), Color(0xFF644092)),
    (Color(0xFFDFF3F3), Color(0xFF155D61)),
    (Color(0xFFFBE3EE), Color(0xFF8A3156)),
    (Color(0xFFFFF1CB), Color(0xFF73540A)),
  ];

  @override
  Widget build(BuildContext context) {
    final index = group.trim().toLowerCase().runes.fold<int>(
        0, (value, rune) => (value * 31 + rune) % _groupColors.length);
    final colors = _groupColors[index];
    return Wrap(spacing: 12, runSpacing: 10, children: [
      _badge(context, subject, Icons.menu_book_rounded, const Color(0xFFE4EEFC),
          const Color(0xFF194D8C)),
      _badge(
          context, 'Группа $group', Icons.groups_rounded, colors.$1, colors.$2),
    ]);
  }

  Widget _badge(BuildContext context, String text, IconData icon,
          Color background, Color foreground) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 21, color: foreground),
          const SizedBox(width: 9),
          Flexible(
              child: Text(text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground, fontWeight: FontWeight.w700))),
        ]),
      );
}
