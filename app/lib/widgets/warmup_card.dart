import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/exercise_catalog.dart';
import '../game/exercise_guide.dart';
import '../game/warmup.dart';
import '../theme.dart';
import 'format.dart';

/// «5 мин», «45 с», «10 раз».
String warmupAmount(WarmupMove m) {
  if (!m.seconds) return '${m.amount} раз';
  return m.amount >= 120 ? '${m.amount ~/ 60} мин' : '${m.amount} с';
}

WarmupMove? warmupById(String id) =>
    ExerciseCatalog.warmups.where((m) => m.id == id).firstOrNull;

/// Карточка движения разминки: дозировка, части тела, техника.
Future<void> showWarmupDetails(BuildContext context, WarmupMove m) {
  final guide = exerciseGuides[m.id];
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.name,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              '${warmupAmount(m)} · ${m.targets.map((p) => p.label.toLowerCase()).join(', ')}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            if (guide != null) ...[
              const SizedBox(height: 16),
              for (final (i, step) in guide.steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text('${i + 1}', style: figureStyle(size: 14)),
                      ),
                      Expanded(
                        child: Text(step, style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              Text(
                guide.mistake,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Разминка в начале тренировки: отметки по нажатию, свёрнута, когда всё сделано.
class WarmupCard extends StatefulWidget {
  const WarmupCard({
    super.key,
    required this.moveIds,
    required this.done,
    required this.onToggle,
  });

  final List<String> moveIds;
  final Set<String> done;
  final ValueChanged<String> onToggle;

  @override
  State<WarmupCard> createState() => _WarmupCardState();
}

class _WarmupCardState extends State<WarmupCard> {
  late bool _open = !widget.moveIds.every(widget.done.contains);

  @override
  Widget build(BuildContext context) {
    final moves = [for (final id in widget.moveIds) ?warmupById(id)];
    final doneCount = moves.where((m) => widget.done.contains(m.id)).length;
    final accent = Theme.of(context).colorScheme.primary;
    final finished = doneCount == moves.length;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Icon(
                    finished ? LucideIcons.circleCheck : LucideIcons.flame,
                    size: 20,
                    color: finished ? accent : const Color(0xFFFF9F43),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Разминка · ~${formatMinutes(Warmup.duration(moves))}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '$doneCount из ${moves.length}',
                    style: figureStyle(size: 13, color: AppColors.textMuted),
                  ),
                  Icon(
                    _open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            for (final m in moves)
              InkWell(
                onTap: () {
                  widget.onToggle(m.id);
                  // Последнее отмеченное — сворачиваем, дальше основная часть.
                  final willFinish =
                      !widget.done.contains(m.id) &&
                      doneCount + 1 == moves.length;
                  if (willFinish) setState(() => _open = false);
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.only(left: 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.hairline)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.done.contains(m.id)
                            ? LucideIcons.squareCheck
                            : LucideIcons.square,
                        size: 20,
                        color: widget.done.contains(m.id)
                            ? accent
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          m.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.done.contains(m.id)
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        warmupAmount(m),
                        style: figureStyle(
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Как делать',
                        onPressed: () => showWarmupDetails(context, m),
                        icon: const Icon(
                          LucideIcons.info,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Строка для плана дня: «Разминка ~6 мин: велотренажёр и 4 движения».
String warmupSummary(List<WarmupMove> moves) {
  if (moves.isEmpty) return '';
  final cardio = moves.where((m) => m.isCardio).firstOrNull;
  final rest = moves.length - (cardio == null ? 0 : 1);
  final head = cardio == null
      ? ''
      : '${cardio.name.split(',').first.toLowerCase()} и ';
  return 'Разминка ~${formatMinutes(Warmup.duration(moves))}: $head$rest движ.';
}
