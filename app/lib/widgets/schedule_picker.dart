import 'format.dart';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/training_format.dart';
import '../theme.dart';

/// Плитка выбора одного варианта из списка (цель, формат тренировок и т. п.).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.raised : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? accent : Colors.transparent),
        ),
        child: ListTile(
          onTap: onTap,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
          trailing: selected
              ? Icon(LucideIcons.check, size: 18, color: accent)
              : null,
        ),
      ),
    );
  }
}

/// Новые дни после нажатия на день недели. Сдвиг дней сохраняет формат,
/// если число тренировок не изменилось; иначе формат становится «Свой график».
({TrainingFormat format, Set<int> days}) toggleTrainingDay(
  TrainingFormat format,
  Set<int> days,
  int day,
  bool on,
) {
  // «Минимум»: выбираются дни загрузки, восстановление — следующий день само.
  if (format == TrainingFormat.minimum) {
    final load = loadDaysOf(format, days);
    on ? load.add(day) : load.remove(day);
    return (format: format, days: withRecoveryDays(load));
  }
  // Стиль от числа дней не зависит (TRAINING_SYSTEM.md 14): дни — любые.
  final next = {...days};
  on ? next.add(day) : next.remove(day);
  return (format: format, days: next);
}

/// Выбор формата и дней тренировок: в онбординге и при смене графика.
class SchedulePicker extends StatelessWidget {
  const SchedulePicker({
    super.key,
    required this.format,
    required this.days,
    required this.onChanged,
  });

  final TrainingFormat format;
  final Set<int> days;
  final void Function(TrainingFormat format, Set<int> days) onChanged;

  @override
  Widget build(BuildContext context) {
    final minimum = format == TrainingFormat.minimum;
    final recovery = recoveryDaysOf(format, days);
    final load = loadDaysOf(format, days);
    final tooFew = !scheduleValid(format, days);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in TrainingFormat.values)
          ChoiceTile(
            selected: format == f,
            title: f.label,
            subtitle: f.description,
            onTap: () => onChanged(f, f.defaultDays.toSet()),
          ),
        const SizedBox(height: 16),
        Text(
          minimum ? 'Дни загрузки' : 'Дни тренировок',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 7; i++)
              FilterChip(
                label: Text(
                  recovery.contains(i)
                      ? '${weekdayShort[i]} · восст.'
                      : weekdayShort[i],
                ),
                // У «Минимума» отмечаются дни загрузки; восстановление — следом само.
                selected: minimum ? load.contains(i) : days.contains(i),
                onSelected: (on) {
                  final next = toggleTrainingDay(format, days, i, on);
                  onChanged(next.format, next.days);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          tooFew
              ? minimum
                    ? 'Выбери 2 дня загрузки не подряд — после каждого будет день восстановления'
                    : days.length > maxTrainingDaysPerWeek
                    ? 'Оставьте хотя бы день отдыха в неделю'
                    : 'Выбери минимум $minTrainingDaysPerWeek дня'
              : minimum
              ? 'Загрузка: ${load.map((d) => weekdayShort[d]).join(', ')}, восстановление: '
                    '${recovery.map((d) => weekdayShort[d]).join(', ')}. '
                    'Восстановление — по желанию: без него серия держится до '
                    'до ${daysWord(maxRestDaysInRow(load.toList()))} отдыха подряд.'
              : 'Тренировок в неделю: ${days.length}. Отдыхать подряд можно до ${daysWord(maxRestDaysInRow(days.toList()))}.'
                    '${format == TrainingFormat.fullBody && hasAdjacentDays(days) ? ' Всё тело в соседние дни перекрыло бы мышцы — в такие недели программа даст верх/низ.' : ''}',
          style: TextStyle(
            color: tooFew
                ? Theme.of(context).colorScheme.error
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
