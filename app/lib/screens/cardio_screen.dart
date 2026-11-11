import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/body_part.dart';
import '../game/cardio.dart';
import '../game/game_config.dart';
import '../state/cardio_state.dart';
import '../state/heart_rate_state.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/format.dart';

/// Кардио: таймер и живой пульс. Опыт идёт в часть тела «Кардио».
class CardioScreen extends ConsumerWidget {
  const CardioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cardioProvider);
    return session == null
        ? const _ChooseActivity()
        : _ActiveCardio(session: session);
  }
}

class _ChooseActivity extends ConsumerStatefulWidget {
  const _ChooseActivity();

  @override
  ConsumerState<_ChooseActivity> createState() => _ChooseActivityState();
}

class _ChooseActivityState extends ConsumerState<_ChooseActivity> {
  CardioActivity _activity = CardioActivity.run;

  @override
  Widget build(BuildContext context) {
    final pulse = ref.watch(heartRateProvider);
    final zone = _zoneFor(ref);
    return Scaffold(
      appBar: AppBar(title: const Text('Кардио')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Чем занимаешься?',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in CardioActivity.values)
                    ChoiceChip(
                      label: Text(a.label),
                      selected: a == _activity,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _activity = a),
                    ),
                ],
              ),
              const Spacer(),
              Icon(
                LucideIcons.heartPulse,
                size: 40,
                color: BodyPart.cardio.color,
              ),
              const SizedBox(height: 12),
              Text(
                'Опыт идёт за минуты с пульсом от $zone уд/мин (зона 2). '
                'Без датчика засчитывается половина времени',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (!pulse.isConnected) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go('/profile/heart-rate'),
                  icon: const Icon(LucideIcons.bluetooth, size: 16),
                  label: const Text('Подключить датчик пульса'),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: () =>
                    ref.read(cardioProvider.notifier).start(_activity),
                child: const Text('Старт'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveCardio extends ConsumerStatefulWidget {
  const _ActiveCardio({required this.session});

  final CardioSession session;

  @override
  ConsumerState<_ActiveCardio> createState() => _ActiveCardioState();
}

class _ActiveCardioState extends ConsumerState<_ActiveCardio> {
  late final Timer _ticker;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    final summary = await ref.read(cardioProvider.notifier).finish();
    if (!mounted) return;
    if (summary != null) context.go('/workout/result');
  }

  Future<void> _confirmCancel() async {
    final cancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Отменить кардио'),
        content: const Text('Время не сохранится'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Продолжить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
    if (cancel == true) ref.read(cardioProvider.notifier).cancel();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final now = DateTime.now();
    final elapsed = now.difference(session.startedAt);
    final pulse = ref.watch(heartRateProvider);
    final zone = _zoneFor(ref);
    final samples = ref
        .read(heartRateProvider.notifier)
        .samplesBetween(session.startedAt, now);
    final inZone = CardioScoring.timeInZone(samples, zone);
    final bpm = pulse.bpm;
    final accent = Theme.of(context).colorScheme.primary;

    final (zoneText, zoneColor) = switch (bpm) {
      null => (
        'Нет пульса — засчитается половина времени',
        AppColors.textMuted,
      ),
      final b when b >= zone => ('В зоне, так держать', accent),
      _ => ('Ниже зоны: добавь темп до $zone', AppColors.textSecondary),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(session.activity.label),
        actions: [
          IconButton(
            tooltip: 'Отменить кардио',
            onPressed: _confirmCancel,
            icon: const Icon(
              LucideIcons.x,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                formatClock(elapsed),
                textAlign: TextAlign.center,
                style: figureStyle(size: 64),
              ),
              if (elapsed.inMinutes >= GameConfig.cardioMaxMinutes)
                const Text(
                  'Больше 2 часов не засчитывается',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      icon: LucideIcons.heart,
                      iconColor: bpm == null
                          ? AppColors.textMuted
                          : BodyPart.cardio.color,
                      value: bpm?.toString() ?? '—',
                      label: 'уд/мин',
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      icon: LucideIcons.target,
                      iconColor: accent,
                      value: '${inZone.inMinutes}',
                      label: 'мин в зоне',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                zoneText,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: zoneColor),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _finishing ? null : _finish,
                child: const Text('Завершить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    excludeSemantics: true,
    child: Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 6),
        Text(value, style: figureStyle(size: 32)),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

/// Нижняя граница зоны 2 с учётом возраста и пульса покоя из профиля.
int _zoneFor(WidgetRef ref) {
  final hero = ref.watch(heroProvider);
  return hero == null
      ? CardioScoring.zoneLowerBound()
      : CardioScoring.zoneLowerBound(
          resting: hero.restingHeartRate,
          max: hero.maxHeartRate,
        );
}
