import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../state/health_state.dart';
import '../state/heart_rate_state.dart';
import '../state/providers.dart';
import '../theme.dart';

/// Версия приложения на телефоне («1.1.0»).
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// Одна строка о подключённых устройствах — для меню профиля и настроек.
String devicesSummary(WidgetRef ref) {
  final pulse = ref.watch(heartRateProvider);
  final health = ref.watch(healthProvider).connected;
  if (pulse.isConnected && pulse.source == PulseSource.watch) {
    return 'Часы передают пульс';
  }
  if (pulse.isConnected) return 'Датчик пульса подключён';
  if (health) return 'Health Connect подключён';
  return 'Ничего не подключено — опыт без часов ×0,5';
}

/// Телефон и часы в одном месте: приложение на часах, Health Connect
/// и Bluetooth-датчик пульса — со статусом и переходом к настройке.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider);
    final pulse = ref.watch(heartRateProvider);
    final tester = ref.watch(heroProvider)?.premium.isTester ?? false;
    final watchLive = pulse.isConnected && pulse.source == PulseSource.watch;
    final bleLive = pulse.isConnected && pulse.source == PulseSource.bluetooth;
    final anyConnected = health.connected || pulse.isConnected;
    final watchVersion = ref.watch(watchVersionProvider);
    final appVersion = ref.watch(appVersionProvider).value;
    // Пульс передают любые часы: протокол обратно совместим. Разница версий —
    // только повод обновиться ради нового (эффекты аур), а не поломка.
    final caps = ref.watch(watchCapsProvider);
    final differs =
        watchVersion != null &&
        appVersion != null &&
        watchVersion != appVersion;

    return Scaffold(
      appBar: AppBar(title: const Text('Часы и телефон')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _Intro(anyConnected: anyConnected, tester: tester),
          const SizedBox(height: 16),
          _DeviceCard(
            icon: LucideIcons.watch,
            title: 'IronRise на часах',
            status: watchLive
                ? 'Передаёт пульс: ${pulse.bpm ?? '—'} уд/мин'
                : 'Wear OS: Galaxy Watch и другие',
            ok: watchLive,
            text: [
              'Поставьте IronRise на часы. Когда начнёте тренировку на телефоне, '
                  'часы сами начнут передавать пульс — ничего нажимать не нужно.',
              if (watchVersion != null) 'На часах версия $watchVersion.',
              if (differs && (caps?.protocol ?? 1) < watchProtocol)
                'Пульс работает. Обновите IronRise на часах — появятся эффекты аур.'
              else if (differs)
                'На телефоне $appVersion — всё совместимо.',
            ].join(' '),
          ),
          const SizedBox(height: 12),
          _DeviceCard(
            icon: LucideIcons.activity,
            title: 'Health Connect',
            status: health.connected ? 'Подключён' : 'Не подключён',
            ok: health.connected,
            text:
                'Шаги, кардио и пульс из Samsung Health и других часов. '
                'Пульс подтягивается и после тренировки.',
            action: health.connected ? 'Открыть' : 'Подключить',
            onTap: () => context.push('/profile/health'),
          ),
          const SizedBox(height: 12),
          _DeviceCard(
            icon: LucideIcons.heartPulse,
            title: 'Датчик пульса по Bluetooth',
            status: bleLive
                ? '${pulse.sensorName ?? 'Датчик'}: ${pulse.bpm ?? '—'} уд/мин'
                : 'Нагрудный датчик или часы в режиме трансляции',
            ok: bleLive,
            text:
                'Пульс в реальном времени прямо во время подходов. Huawei, Garmin, '
                'Polar, COROS, Amazfit и нагрудные датчики — инструкция для вашей модели внутри.',
            action: bleLive ? 'Открыть' : 'Найти датчик',
            onTap: () => context.push('/profile/heart-rate'),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.anyConnected, required this.tester});

  final bool anyConnected;
  final bool tester;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          anyConnected ? LucideIcons.shieldCheck : LucideIcons.info,
          size: 20,
          color: anyConnected ? accent : AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tester
                ? 'Пульс подтверждает тренировки. У вас, как у бета-тестера, '
                      'тренировки без часов засчитываются полностью'
                : 'Пульс подтверждает тренировки: без часов опыт засчитывается ×0,5',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.ok,
    required this.text,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool ok;
  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: ok ? accent : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 13,
                          color: ok ? accent : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(onPressed: onTap, child: Text(action!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
