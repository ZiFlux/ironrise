import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/body_part.dart';
import '../game/cardio.dart';
import '../game/exercise_catalog.dart';
import '../game/recovery.dart';
import '../state/cardio_state.dart';
import '../state/training_log.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/wellbeing_card.dart';

/// День восстановления «Минимума» (TRAINING_SYSTEM.md 13.6): опрос самочувствия,
/// затем 10–15 минут — кардио, растяжка того, что работало в загрузку, кор и дыхание.
/// Засчитывается как кардио «Восстановление»: продлевает серию, даёт немного опыта.
class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _done = <int>{};
  Timer? _ticker;
  bool _finishing = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Последняя силовая: что работало — то и растягиваем.
  LoggedWorkout? get _lastLoad => ref
      .read(trainingLogProvider)
      .where((w) => w.kind == WorkoutKind.strength)
      .firstOrNull;

  Set<BodyPart> _trainedParts(LoggedWorkout? w) => {
    for (final e in w?.exercises ?? const <LoggedExercise>[])
      if (ExerciseCatalog.tryById(e.id) case final ex?)
        for (final s in ex.shares.entries)
          if (s.value >= 0.2 && s.key != BodyPart.cardio) s.key,
  };

  void _start() {
    ref.read(cardioProvider.notifier).start(CardioActivity.recovery);
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    final summary = await ref.read(cardioProvider.notifier).finish();
    if (!mounted) return;
    if (summary != null) {
      context.go('/workout/result');
    } else {
      setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(cardioProvider);
    final active = session?.activity == CardioActivity.recovery;
    if (active && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    }
    final last = _lastLoad;
    final plan = recoveryPlan(_trainedParts(last));
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('День восстановления')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (!active) ...[
            Text(
              'Мышцы растут, пока восстанавливаются. Сегодня ~${recoveryMinutes(plan)} минут '
              'лёгкой активности: разгоняем кровь и растягиваем то, что работало в загрузку. '
              'Серия продлится, герой получит немного опыта.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Как ощущения после загрузки: болит — следующая загрузка бережёт это место.
            WellbeingCard(
              exerciseIds: [
                for (final e in last?.exercises ?? const <LoggedExercise>[])
                  e.id,
              ],
            ),
            const SizedBox(height: 16),
          ] else ...[
            Center(
              child: Text(
                formatClock(DateTime.now().difference(session!.startedAt)),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final (i, m) in plan.indexed)
            Card(
              child: CheckboxListTile(
                value: _done.contains(i),
                enabled: active,
                onChanged: (v) =>
                    setState(() => v == true ? _done.add(i) : _done.remove(i)),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(m.name),
                subtitle: Text(
                  m.how,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                secondary: Text(
                  m.seconds >= 120
                      ? '${m.seconds ~/ 60} мин'
                      : '${m.seconds} с',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (!active)
            FilledButton.icon(
              onPressed: session == null ? _start : null,
              icon: const Icon(LucideIcons.play, size: 18),
              label: Text(
                session == null
                    ? 'Начать восстановление'
                    : 'Сначала закончите кардио',
              ),
            )
          else
            FilledButton.icon(
              onPressed: _finishing ? null : _finish,
              icon: Icon(LucideIcons.check, size: 18, color: accent),
              label: Text(
                _done.length == plan.length
                    ? 'Готово'
                    : 'Закончить (${_done.length} из ${plan.length})',
              ),
            ),
        ],
      ),
    );
  }
}
