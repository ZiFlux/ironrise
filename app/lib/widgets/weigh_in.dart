import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/body_log.dart';
import '../state/health_state.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'format.dart';
import 'status_toast.dart';

/// Взвешивание: вес вручную, затем — если свежего анализа тела нет — подсказка
/// сделать его на часах. Состав тела приложение потом забирает само.
Future<void> showWeighIn(BuildContext context, WidgetRef ref) async {
  final last = ref.read(heroProvider)?.body.weightKg;
  final controller = TextEditingController(
    text: last == null ? '' : formatKg(last),
  );
  final kg = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Взвешивание'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: const InputDecoration(
          hintText: 'Вес, кг',
          helperText: 'Утром, натощак — так замеры сравнимы',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () {
            final v = double.tryParse(controller.text.replaceAll(',', '.'));
            if (v != null && v >= 30 && v <= 300) Navigator.pop(context, v);
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  if (kg == null) return;
  final log = ref.read(bodyLogProvider.notifier);
  await log.addWeight(kg);
  await log.importFromHealth();
  final analysed = bodySnapshot(ref.read(bodyLogProvider)).analysedAt;
  final freshAnalysis =
      analysed != null && DateTime.now().difference(analysed).inDays < 3;
  if (freshAnalysis || !context.mounted) {
    showStatus('Вес записан: ${formatKg(kg)} кг');
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => const _AnalysisHint(),
  );
}

/// Подсказка: сделать анализ тела на часах — данные подтянутся сами.
class _AnalysisHint extends ConsumerWidget {
  const _AnalysisHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider).connected;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      icon: const Icon(LucideIcons.scanLine),
      title: const Text('Анализ тела на часах'),
      content: Text(
        health
            ? 'Вес записан. Сделайте анализ тела на часах: Samsung Health → '
                  'Состав тела → Измерить (пальцы на кнопки, 15 секунд). '
                  'Процент жира, мышцы и вода подтянутся в IronRise сами.'
            : 'Вес записан. Чтобы IronRise видел процент жира, мышц и воды '
                  'с часов, подключите Health Connect: Профиль → Часы и телефон.',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        if (health)
          TextButton(
            onPressed: () async {
              // Кто подключил Health Connect раньше — доступа к составу тела ещё нет.
              await ref.read(healthProvider.notifier).requestBodyAccess();
              final found = await ref
                  .read(bodyLogProvider.notifier)
                  .importFromHealth();
              if (context.mounted) Navigator.pop(context);
              showStatus(
                found > 0
                    ? 'Состав тела получен'
                    : 'Анализа пока нет — подтянется после замера',
              );
            },
            child: const Text('Проверить сейчас'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

/// Блок «Тело» на экране статистики: вес и состав тела, изменение за месяц.
class BodySummary extends ConsumerWidget {
  const BodySummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(bodyLogProvider);
    final s = bodySnapshot(log);
    final change = weightChange(log, DateTime.now());
    String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)} %';
    final tiles = [
      (
        'Вес',
        s.weightKg == null ? '—' : '${formatKg(s.weightKg!)} кг',
        change == null
            ? null
            : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} за 30 дн.',
      ),
      ('Жир', pct(s.fatPct), null),
      ('Безжировая', pct(s.leanPct), 'мышцы, кости'),
      ('Вода', pct(s.waterPct), null),
      ('Обмен', s.bmrKcal == null ? '—' : '${s.bmrKcal!.round()} ккал', null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value, note) in tiles)
              Container(
                width: 104,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(value, style: figureStyle(size: 16)),
                    if (note != null)
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          s.analysedAt == null
              ? 'Состав тела — с часов: анализ тела в Samsung Health подтягивается сам'
              : 'Анализ тела от ${formatDate(s.analysedAt!)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => showWeighIn(context, ref),
            icon: const Icon(LucideIcons.scale, size: 16),
            label: const Text('Взвеситься'),
          ),
        ),
      ],
    );
  }
}
