import 'package:flutter/material.dart';

import '../game/body_part.dart';
import '../game/progression.dart';
import '../theme.dart';

/// Строка параметра тела: иконка, название, уровень и шкала опыта.
class PartBar extends StatelessWidget {
  const PartBar({super.key, required this.part, required this.xp, this.lagging = false});

  final BodyPart part;
  final int xp;
  final bool lagging;

  @override
  Widget build(BuildContext context) {
    final level = Progression.levelFromXp(xp);
    final progress = Progression.levelProgress(xp);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(part.icon, color: part.color, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(part.label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 500),
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  color: part.color,
                  backgroundColor: AppColors.surfaceHigh,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              'ур. $level',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: lagging ? part.color : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
