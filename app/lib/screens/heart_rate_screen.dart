import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/watch_guides.dart';
import '../state/heart_rate_state.dart';
import '../theme.dart';

/// Подключение датчика пульса по Bluetooth.
class HeartRateScreen extends ConsumerWidget {
  const HeartRateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulse = ref.watch(heartRateProvider);
    final controller = ref.read(heartRateProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Датчик пульса')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (pulse.isConnected)
            _ConnectedCard(state: pulse, onDisconnect: controller.disconnect)
          else
            const _HowToCard(),
          if (pulse.message != null) ...[
            const SizedBox(height: 12),
            Text(
              pulse.message!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (!pulse.isConnected) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: pulse.status == HeartRateStatus.scanning
                  ? controller.stopScan
                  : controller.startScan,
              icon: Icon(
                pulse.status == HeartRateStatus.scanning
                    ? LucideIcons.square
                    : LucideIcons.bluetooth,
                size: 18,
              ),
              label: Text(
                pulse.status == HeartRateStatus.scanning
                    ? 'Остановить поиск'
                    : 'Найти датчик',
              ),
            ),
            const SizedBox(height: 16),
            for (final device in pulse.found)
              _DeviceRow(
                device: device,
                connecting:
                    pulse.status == HeartRateStatus.connecting &&
                    pulse.sensorName == device.name,
                onTap: () => controller.connect(device),
              ),
            if (pulse.status == HeartRateStatus.scanning && pulse.found.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ],
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  const _HowToCard();

  static const _steps = [
    'Включи на часах трансляцию пульса — инструкция для твоей модели ниже',
    'Нажми «Найти датчик» и выбери устройство из списка',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Как подключить',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            for (final (i, step) in _steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              'С подключённым пульсом тренировка подтверждается и даёт полный опыт',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            const Text(
              'Твои часы',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            for (final g in watchGuides) _WatchGuideTile(guide: g),
            const SizedBox(height: 4),
            const Text(
              'Меню у моделей и прошивок может отличаться. Не получилось — напиши '
              'в канал бета-тестеров, добавим твою модель.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Инструкция для одной марки часов — раскрывается по нажатию (п. 125).
class _WatchGuideTile extends StatelessWidget {
  const _WatchGuideTile({required this.guide});

  final WatchGuide guide;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(guide.brand, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        [
          guide.models,
          guide.live ? 'пульс живьём' : 'пульс после тренировки',
          if (guide.tested) 'проверено',
        ].join(' · '),
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      children: [
        for (final (i, step) in guide.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({required this.state, required this.onDisconnect});

  final HeartRateState state;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final fromWatch = state.source == PulseSource.watch;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.sensorName ?? 'Датчик пульса',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fromWatch ? 'Тренировка идёт на часах' : 'Подключён',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (fromWatch)
                    const Text(
                      'Чтобы отключить, заверши тренировку на часах',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: onDisconnect,
                      child: const Text('Отключить'),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  state.bpm?.toString() ?? '—',
                  style: figureStyle(size: 40, color: accent),
                ),
                const SizedBox(height: 4),
                const Text(
                  'уд/мин',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.connecting,
    required this.onTap,
  });

  final SensorDevice device;
  final bool connecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: connecting ? null : onTap,
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.heartPulse,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(device.name, style: const TextStyle(fontSize: 15)),
            ),
            if (connecting)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                '${device.rssi} дБм',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
