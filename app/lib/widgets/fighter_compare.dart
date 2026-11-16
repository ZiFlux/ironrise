import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/body_part.dart';
import '../game/duel.dart';
import '../theme.dart';

/// Сравнение с соперником по частям тела (п. 127): чем он сильнее и чем слабее.
/// [friendId] — у друга кнопка «Профиль».
Future<void> showFighterCompare(
  BuildContext context, {
  required Fighter me,
  required Fighter rival,
  String? friendId,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: AppColors.surface,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            rival.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Сила ${rival.power} против твоих ${me.power}. Здоровье в бою равно '
            'силе, а чаще и мощнее бьёт та часть тела, что прокачана лучше.',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: SizedBox()),
              SizedBox(
                width: 56,
                child: Text(
                  'ты',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  'соперник',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          for (final part in BodyPart.values)
            _CompareRow(
              part: part,
              mine: me.levels[part] ?? 0,
              theirs: rival.levels[part] ?? 0,
            ),
          if (friendId != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheet);
                context.push('/friend/$friendId');
              },
              icon: const Icon(LucideIcons.user, size: 18),
              label: const Text('Профиль'),
            ),
          ],
        ],
      ),
    ),
  ),
);

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.part,
    required this.mine,
    required this.theirs,
  });

  final BodyPart part;
  final int mine;
  final int theirs;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final better = mine > theirs;
    final worse = mine < theirs;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: part.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(part.label, style: const TextStyle(fontSize: 15)),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$mine',
              textAlign: TextAlign.end,
              style: figureStyle(
                size: 15,
                color: better ? accent : AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$theirs',
              textAlign: TextAlign.end,
              style: figureStyle(
                size: 15,
                color: worse
                    ? const Color(0xFFFF6B5E)
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
