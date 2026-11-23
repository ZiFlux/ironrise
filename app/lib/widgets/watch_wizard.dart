import '../l10n/tr.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/watch_detect.dart';
import '../game/watch_guides.dart';
import '../state/heart_rate_state.dart';
import '../state/watch_discovery.dart';
import '../theme.dart';
import 'status_toast.dart';

/// Мастер «Найти мои часы» (п. 152): смотрит, что уже подключено к телефону,
/// и ведёт к пульсу кратчайшим путём для этой марки.
class WatchWizard extends ConsumerWidget {
  const WatchWizard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(watchDiscoveryProvider);
    final notifier = ref.read(watchDiscoveryProvider.notifier);
    final accent = Theme.of(context).colorScheme.primary;

    if (!d.done) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.radar, size: 20, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('Найти мои часы'),
                      style: TextStyle(fontFamily: displayFont, fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  'Посмотрим, какие часы уже подключены к телефону, и подскажем, как получить с них пульс',
                ),
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: d.searching ? null : notifier.search,
                icon: d.searching
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.search, size: 18),
                label: Text(d.searching ? tr('Ищем…') : tr('Найти')),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                d.watches.isEmpty
                    ? tr('Часов рядом не нашли')
                    : d.watches.length == 1
                    ? tr('Нашли часы')
                    : tr('Нашли {length} устройства', {
                        'length': d.watches.length,
                      }),
                style: const TextStyle(fontFamily: displayFont, fontSize: 18),
              ),
            ),
            TextButton.icon(
              onPressed: d.searching ? null : notifier.search,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text(tr('Ещё раз')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final w in d.watches) ...[
          _FoundWatch(watch: w, discovery: d),
          const SizedBox(height: 8),
        ],
        if (d.watches.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                [
                  tr(
                    'Включи Bluetooth на часах и проверь, что они подключены к телефону в своём приложении.',
                  ),
                  if (d.brandsByApp.isNotEmpty)
                    tr(
                      'Есть приложение для {p1} — инструкция ниже, в «Датчик пульса».',
                      {
                        'p1': d.brandsByApp
                            .map((id) => watchGuideById(id)?.brand ?? id)
                            .join(', '),
                      },
                    ),
                  tr(
                    'Нет часов — подойдёт нагрудный датчик или Health Connect.',
                  ),
                ].join(' '),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        if (d.noPermission) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                LucideIcons.info,
                size: 16,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(
                    'Без разрешения «Устройства поблизости» видны только часы Wear OS',
                  ),
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              TextButton(
                onPressed: notifier.search,
                child: Text(tr('Разрешить')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Карточка найденных часов: что это и одна главная кнопка.
class _FoundWatch extends ConsumerWidget {
  const _FoundWatch({required this.watch, required this.discovery});

  final DetectedWatch watch;
  final WatchDiscovery discovery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = watchGuideById(watch.guideId);
    final hr = ref.watch(heartRateProvider);
    final notifier = ref.read(watchDiscoveryProvider.notifier);
    final waiting = discovery.waitingFor?.name == watch.name;
    final live =
        hr.isConnected &&
        (watch.isWearOs
            ? hr.source == PulseSource.watch
            : hr.source == PulseSource.bluetooth);

    final (String status, bool ok) = switch (watch) {
      _ when live => (
        tr('Передаёт пульс: {p1} уд/мин', {'p1': hr.bpm ?? '—'}),
        true,
      ),
      DetectedWatch(isWearOs: true) when discovery.watchApp => (
        tr('IronRise на часах стоит — пульс пойдёт сам с началом тренировки'),
        true,
      ),
      DetectedWatch(isWearOs: true) => (
        tr('Поставь IronRise на часы — пульс будет передаваться сам'),
        false,
      ),
      _ when guide?.live ?? false => (
        tr('Включи на часах трансляцию пульса — и мы подключимся'),
        false,
      ),
      _ => (tr('Пульс придёт через Health Connect после тренировки'), false),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ok ? LucideIcons.circleCheck : LucideIcons.watch,
                  size: 20,
                  color: ok
                      ? AppColors.success
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        watch.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (guide != null)
                        Text(
                          guide.brand,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (!ok) ...[
              // Шаги — только там, где пользователю что-то включать на часах.
              if (guide != null && !watch.isWearOs) ...[
                const SizedBox(height: 10),
                for (final (i, step) in guide.steps.indexed)
                  if (!step.contains('«Найти датчик»'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              '${i + 1}',
                              style: figureStyle(
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
              const SizedBox(height: 12),
              if (watch.isWearOs) ...[
                FilledButton.icon(
                  onPressed: () async {
                    final opened = await notifier.installOnWatch(watch);
                    showStatus(
                      opened
                          ? tr('На часах открылся магазин — нажми «Установить»')
                          : tr(
                              'Не получилось. Открой Play Маркет на часах и найди IronRise',
                            ),
                      kind: opened ? StatusKind.success : StatusKind.info,
                      duration: const Duration(seconds: 5),
                    );
                  },
                  icon: const Icon(LucideIcons.download, size: 18),
                  label: Text(tr('Поставить на часы')),
                ),
                TextButton(
                  onPressed: () => context.push('/profile/health'),
                  child: Text(tr('Без приложения — через Health Connect')),
                ),
              ] else if (guide?.live ?? false)
                FilledButton.icon(
                  onPressed: waiting
                      ? null
                      : () => notifier.waitForBroadcast(watch),
                  icon: waiting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.radio, size: 18),
                  label: Text(
                    waiting
                        ? tr('Ждём сигнал от часов…')
                        : tr('Готово — подключить'),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: () => context.push('/profile/health'),
                  icon: const Icon(LucideIcons.activity, size: 18),
                  label: Text(tr('Подключить Health Connect')),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
