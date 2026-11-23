import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'line_chart.dart';

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
            ? 'Вес записан. Сделай анализ тела на часах: Samsung Health → '
                  'Состав тела → Измерить (пальцы на кнопки, 15 секунд). '
                  'Процент жира, мышцы и вода подтянутся в IronRise сами.'
            : 'Вес записан. Чтобы IronRise видел процент жира, мышц и воды '
                  'с часов, подключи Health Connect: Профиль → Часы и телефон.',
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
              if (!context.mounted) return;
              Navigator.pop(context);
              if (found > 0) {
                showStatus('Состав тела получен');
              } else {
                await showBodyDiagnostics(context, ref);
              }
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
        // Вес — кривой за последние взвешивания (п. 105), когда их хотя бы два.
        if ([
              for (final m in log)
                if (m.weightKg != null) m,
            ]
            case final weights when weights.length >= 2) ...[
          const SizedBox(height: 12),
          LineChart(
            color: Theme.of(context).colorScheme.primary,
            height: 90,
            points: [
              for (final m in weights.take(20).toList().reversed)
                (
                  label: '${m.at.day}.${m.at.month.toString().padLeft(2, '0')}',
                  value: m.weightKg!,
                  tip: '${formatDate(m.at)}: ${formatKg(m.weightKg!)} кг',
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          s.analysedAt == null
              ? 'Состав тела — с часов: анализ тела в Samsung Health подтягивается сам'
              : 'Анализ тела от ${formatDate(s.analysedAt!)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: () => showWeighIn(context, ref),
              icon: const Icon(LucideIcons.scale, size: 16),
              label: const Text('Взвеситься'),
            ),
            // Анализ с часов не приходит — показать, чего не хватает.
            TextButton.icon(
              onPressed: () async {
                final found = await ref
                    .read(bodyLogProvider.notifier)
                    .importFromHealth();
                if (!context.mounted) return;
                if (found > 0) {
                  showStatus('Состав тела получен');
                } else {
                  await showBodyDiagnostics(context, ref);
                }
              },
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Забрать с часов'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Почему состав тела не пришёл: доступ и записи по каждому показателю и что
/// сделать — дать доступ IronRise или разрешить Samsung Health писать в Health Connect.
Future<void> showBodyDiagnostics(BuildContext context, WidgetRef ref) async {
  final health = ref.read(healthProvider.notifier);
  final access = await health.bodyAccess(
    since: DateTime.now().subtract(const Duration(days: 90)),
  );
  if (!context.mounted) return;
  const labels = {
    HealthDataType.BODY_FAT_PERCENTAGE: 'Процент жира',
    HealthDataType.WEIGHT: 'Вес',
    HealthDataType.BASAL_ENERGY_BURNED: 'Базовый обмен',
    HealthDataType.LEAN_BODY_MASS: 'Безжировая масса',
    HealthDataType.BODY_WATER_MASS: 'Вода',
  };
  final missing = access.where((a) => !a.granted).toList();
  final fat = access
      .where((a) => a.type == HealthDataType.BODY_FAT_PERCENTAGE)
      .firstOrNull;
  final noData = fat != null && fat.granted && fat.points.isEmpty;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      icon: const Icon(LucideIcons.scanLine),
      title: const Text('Состав тела пока не пришёл'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (access.isEmpty)
              const Text(
                'Health Connect не подключён. Подключи его: Профиль → Часы и телефон.',
              ),
            for (final a in access)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${labels[a.type] ?? a.type.name}: '
                  '${a.granted ? 'доступ есть, замеров за 90 дней — ${a.points.length}' : 'нет доступа'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: a.granted && a.points.isNotEmpty
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (missing.isNotEmpty)
              const Text(
                'У IronRise нет доступа к части показателей. Нажми «Дать доступ» '
                'и в Health Connect включи все пункты состава тела.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            if (noData)
              const Text(
                'Доступ есть, но замеров в Health Connect нет: Samsung Health их туда '
                'не передаёт. Открой Samsung Health → меню (три полоски) → Настройки → '
                'Health Connect и разреши Samsung Health запись: «Процент жира», '
                '«Вес» и «Базовый обмен». Затем сделай замер на часах: '
                'Samsung Health → Состав тела → Измерить. Через пару минут он '
                'появится здесь сам.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
      actions: [
        if (missing.isNotEmpty)
          TextButton(
            onPressed: () async {
              await health.requestBodyAccess();
              final found = await ref
                  .read(bodyLogProvider.notifier)
                  .importFromHealth();
              if (context.mounted) Navigator.pop(context);
              if (found > 0) showStatus('Состав тела получен');
            },
            child: const Text('Дать доступ'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
}
