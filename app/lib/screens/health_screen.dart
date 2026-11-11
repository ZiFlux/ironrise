import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/health_state.dart';
import '../theme.dart';
import '../widgets/format.dart';

/// Часы и здоровье: подключение Health Connect и инструкции для разных часов.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider);
    final notifier = ref.read(healthProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Часы и здоровье')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: switch (health.status) {
                HealthStatus.connected => _Connected(health: health),
                HealthStatus.needsInstall => _Action(
                  icon: LucideIcons.download,
                  title: 'Health Connect не установлен',
                  text:
                      'Это приложение Google, через которое часы передают шаги и пульс. '
                      'На Android 14 и новее оно встроено в систему, на старых — ставится из Google Play',
                  button: 'Установить Health Connect',
                  onPressed: notifier.installHealthConnect,
                ),
                _ => _Action(
                  icon: LucideIcons.watch,
                  title: 'Часы не подключены',
                  text:
                      'Шаги, расстояние и пульс берутся из Health Connect — туда пишут '
                      'почти все часы. Тренировки с пульсом засчитываются полностью',
                  button: 'Подключить Health Connect',
                  onPressed: () async {
                    final ok = await notifier.connect();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Доступ не выдан. Его можно включить в настройках Health Connect',
                          ),
                        ),
                      );
                    }
                  },
                ),
              },
            ),
          ),
          if (health.connected) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: notifier.refresh,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Обновить'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: notifier.disconnect,
                    child: const Text('Отключить'),
                  ),
                ),
              ],
            ),
          ],
          const _Guide(
            title: 'Galaxy Watch',
            steps: [
              'Откройте Samsung Health на телефоне',
              '⋮ → Настройки → Health Connect',
              'Разрешите Samsung Health записывать шаги, расстояние и пульс',
              'Вернитесь сюда и нажмите «Подключить Health Connect»',
            ],
            note:
                'Samsung Health передаёт данные с задержкой в несколько минут. Пульс за тренировку '
                'подтянется при синхронизации, и сервер пересчитает опыт. Живой пульс на экране '
                'тренировки — через датчик по Bluetooth (Профиль → Датчик пульса)',
          ),
          const _Guide(
            title: 'Другие часы',
            steps: [
              'Pixel Watch, Fitbit — приложение Fitbit → Health Connect',
              'Xiaomi, Redmi — Mi Fitness → Профиль → Health Connect',
              'Amazfit — Zepp → Профиль → Health Connect',
              'Garmin — Garmin Connect → Настройки → Health Connect',
            ],
            note:
                'Если приложения часов нет в списке Health Connect, его данные сюда не попадут. '
                'Тогда подойдёт трансляция пульса по Bluetooth, если её поддерживают часы',
          ),
        ],
      ),
    );
  }
}

class _Connected extends StatelessWidget {
  const _Connected({required this.health});

  final HealthState health;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final km = (health.metersToday ?? 0) / 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.circleCheck, size: 18, color: accent),
            const SizedBox(width: 8),
            const Text(
              'Health Connect подключён',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Figure(
                value: health.stepsToday == null
                    ? '—'
                    : formatThousands(health.stepsToday!),
                label: 'шагов сегодня',
              ),
            ),
            Expanded(
              child: _Figure(
                value: km.toStringAsFixed(1).replaceAll('.', ','),
                label: 'км сегодня',
              ),
            ),
          ],
        ),
        if (health.stepsToday == 0) ...[
          const SizedBox(height: 12),
          const Text(
            'Пока ноль: проверьте, что приложение часов пишет данные в Health Connect (инструкция ниже)',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: figureStyle(size: 26)),
      Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
      ),
    ],
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.text,
    required this.button,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String text;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      FilledButton(onPressed: onPressed, child: Text(button)),
    ],
  );
}

class _Guide extends StatelessWidget {
  const _Guide({required this.title, required this.steps, required this.note});

  final String title;
  final List<String> steps;
  final String note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                Expanded(child: Text(s, style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          note,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}
