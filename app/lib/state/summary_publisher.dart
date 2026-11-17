import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/hero_milestones.dart';
import '../game/progression.dart';
import 'account_state.dart';
import 'aura_state.dart';
import 'hero.dart';
import 'program_state.dart';
import 'providers.dart';
import 'training_log.dart';

/// Канал сводки для виджета на телефоне и плитки на часах (MainActivity.kt).
const _summary = MethodChannel('ironrise/summary');

/// Сводка: серия, что сегодня и уровень героя.
typedef Summary = ({int streak, String today, String level});

Summary summaryOf(
  HeroProfile hero,
  List<LoggedWorkout> log,
  String planTitle,
  DateTime now,
) {
  final strength = doneToday(log, WorkoutKind.strength, now);
  final cardio = doneToday(log, WorkoutKind.cardio, now);
  final trainingDay = hero.isLoadDay(now);
  final today = switch ((strength, cardio)) {
    (true, true) => 'На сегодня всё — отдых',
    (true, false) => 'Силовая сделана',
    _ when trainingDay => 'Сегодня: $planTitle',
    _ => 'Сегодня отдых',
  };
  return (
    streak: hero.currentStreak(now),
    today: today,
    level: 'Герой ${heroLevel(Progression.levels(hero.xp))} ур.',
  );
}

/// Следит за героем, планом и журналом и отправляет сводку на виджет и часы,
/// только когда она изменилась.
final summaryPublisherProvider = Provider<void>((ref) {
  if (!Platform.isAndroid) return;
  Summary? last;
  String? lastAura;
  String? lastAuraState;
  void publish() {
    final hero = ref.read(heroProvider);
    if (hero == null) return;
    final s = summaryOf(
      hero,
      ref.read(trainingLogProvider),
      ref.read(todayPlanProvider).day.title,
      DateTime.now(),
    );
    // Надетая аура — для эффекта на часах (неизвестную часы просто не рисуют).
    // Без аккаунта аур нет — и сервер не трогаем.
    final aura = ref.read(accountProvider).signedIn
        ? ref.read(auraProvider).value?.equipped?.name ?? ''
        : '';
    // «Горит / тухнет» (п. 83): тренировалась ли надетая аура на этой неделе.
    final info = ref.read(auraProvider).value;
    final auraState = aura.isEmpty || info == null
        ? ''
        : (info.sessionsThisWeek > 0 ? 'on' : 'fading');
    if (s == last && aura == lastAura && auraState == lastAuraState) return;
    last = s;
    lastAura = aura;
    lastAuraState = auraState;
    _summary
        .invokeMethod<bool>('publish', {
          'streak': s.streak,
          'today': s.today,
          'level': s.level,
          'aura': aura,
          'auraState': auraState,
        })
        .catchError((_) => false);
  }

  ref.listen(heroProvider, (_, _) => publish());
  ref.listen(trainingLogProvider, (_, _) => publish());
  ref.listen(todayPlanProvider, (_, _) => publish());
  if (ref.read(accountProvider).signedIn) {
    ref.listen(auraProvider, (_, _) => publish());
  }
  Future.microtask(publish);
});
