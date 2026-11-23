import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/health_state.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/status_toast.dart';

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
                      showStatus(
                        'Доступ не выдан. Его можно включить в настройках Health Connect',
                        kind: StatusKind.error,
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
          if (health.connected) const _Sources(),
          const Padding(
            padding: EdgeInsets.only(top: 24, bottom: 8),
            child: Text(
              'Подключить приложение',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          const Text(
            'Приложения часов и браслетов передают данные в Health Connect, '
            'а IronRise берёт их оттуда. Включи передачу в своём приложении:',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          for (final app in _apps) _AppGuide(app: app),
          const SizedBox(height: 12),
          const Text(
            'Живой пульс на экране тренировки — через датчик по Bluetooth или часы Wear OS '
            '(Профиль → Устройства). Через Health Connect пульс приходит с задержкой, '
            'и сервер пересчитывает опыт после синхронизации',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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

typedef _App = ({String name, String devices, List<String> steps});

const _apps = <_App>[
  (
    name: 'Samsung Health',
    devices: 'Galaxy Watch, Galaxy Fit',
    steps: [
      'Открой Samsung Health',
      '⋮ → Настройки → Health Connect',
      'Разреши запись шагов, расстояния и пульса',
    ],
  ),
  (
    name: 'Mi Fitness',
    devices: 'Xiaomi, Redmi',
    steps: [
      'Открой Mi Fitness',
      'Профиль → Подключения → Health Connect',
      'Включи передачу пульса и шагов',
    ],
  ),
  (
    name: 'Zepp',
    devices: 'Amazfit',
    steps: [
      'Открой Zepp',
      'Профиль → Добавить аккаунты → Health Connect',
      'Разреши пульс, шаги и тренировки',
    ],
  ),
  (
    name: 'Huawei Health',
    devices: 'Huawei, Honor',
    steps: [
      'Обнови Huawei Health до последней версии',
      'Я → Настройки → Общий доступ к данным → Health Connect',
      'Если пункта нет — версия Huawei Health не поддерживает Health Connect',
    ],
  ),
  (
    name: 'Google Fit',
    devices: 'Wear OS, телефон',
    steps: [
      'Открой Google Fit',
      'Профиль → ⚙ → Синхронизация с Health Connect',
      'Включи синхронизацию',
    ],
  ),
  (
    name: 'Fitbit',
    devices: 'Fitbit, Pixel Watch',
    steps: [
      'Открой Fitbit',
      'Аккаунт → Health Connect',
      'Разреши пульс и шаги',
    ],
  ),
  (
    name: 'Garmin Connect',
    devices: 'Garmin',
    steps: [
      'Открой Garmin Connect',
      'Ещё → Настройки → Health Connect',
      'Включи передачу данных',
    ],
  ),
  (
    name: 'Polar Flow',
    devices: 'Polar',
    steps: [
      'Открой Polar Flow',
      'Ещё → Общие настройки → Health Connect',
      'Разреши передачу пульса и тренировок',
    ],
  ),
  (
    name: 'Suunto',
    devices: 'Suunto',
    steps: [
      'Открой Suunto',
      'Профиль → Партнёрские сервисы → Health Connect',
      'Включи передачу',
    ],
  ),
];

class _AppGuide extends StatelessWidget {
  const _AppGuide({required this.app});

  final _App app;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      shape: const Border(),
      title: Text(app.name, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        app.devices,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        for (final (i, step) in app.steps.indexed)
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
                Expanded(
                  child: Text(step, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Потом вернитесь сюда — приложение появится в «Откуда приходят данные»',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      ],
    ),
  );
}

/// Какие приложения реально пишут пульс и шаги за неделю.
class _Sources extends ConsumerStatefulWidget {
  const _Sources();

  @override
  ConsumerState<_Sources> createState() => _SourcesState();
}

class _SourcesState extends ConsumerState<_Sources> {
  late Future<List<HealthSource>> _sources = _load();

  Future<List<HealthSource>> _load() =>
      ref.read(healthProvider.notifier).sources();

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes} мин назад';
    if (d.inHours < 24) return '${d.inHours} ч назад';
    return '${d.inDays} дн. назад';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Откуда приходят данные',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                tooltip: 'Проверить снова',
                onPressed: () => setState(() => _sources = _load()),
                icon: const Icon(LucideIcons.refreshCw, size: 18),
              ),
            ],
          ),
          FutureBuilder(
            future: _sources,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }
              final list = snap.data ?? const <HealthSource>[];
              if (list.isEmpty) {
                return const Text(
                  'За неделю никто не передал пульс и шаги. Включи передачу '
                  'в приложении часов — инструкции ниже',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                );
              }
              return Card(
                child: Column(
                  children: [
                    for (final s in list)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          LucideIcons.circleCheck,
                          size: 18,
                          color: accent,
                        ),
                        title: Text(
                          s.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          [
                            if (s.hasPulse) 'пульс',
                            if (s.hasSteps) 'шаги',
                            _ago(s.lastAt),
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
