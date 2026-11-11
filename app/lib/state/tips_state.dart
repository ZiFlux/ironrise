import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_config.dart';
import '../game/tips.dart';
import '../net/api_client.dart';
import 'account_state.dart';
import 'program_state.dart';
import 'providers.dart';

const _tipKey = 'daily_tip_v1';

/// Сколько последних советов не повторять.
const _recentLimit = 10;

/// Совет на сегодня и ответ на его вопрос.
class DailyTip {
  const DailyTip({required this.day, required this.tip, this.answer, this.rewarded = false});

  final String day;
  final Tip tip;
  final int? answer;
  final bool rewarded;

  bool get answered => answer != null;
  bool get correct => answer == tip.question.correct;
}

class TipsNotifier extends Notifier<DailyTip?> {
  List<String> _recent = const [];

  @override
  DailyTip? build() {
    final hero = ref.watch(heroProvider);
    if (hero == null) return null;
    final today = _dayKey(DateTime.now());
    final saved = _load();
    _recent = saved.recent;
    if (saved.tip != null && saved.tip!.day == today) return saved.tip;

    final now = DateTime.now();
    final tip = TipPicker.pick(
      day: now,
      isTrainingDay: hero.trainingDays.contains(now.weekday - 1),
      planExerciseIds: [for (final e in ref.read(programProvider).today.exercises) e.exerciseId],
      lagging: hero.lagging.firstOrNull,
      recentTipIds: _recent,
    );
    _recent = [tip.id, ..._recent].take(_recentLimit).toList();
    final fresh = DailyTip(day: today, tip: tip);
    _save(fresh);
    return fresh;
  }

  /// Только для разработки: сразу показать следующий совет вместо сегодняшнего.
  void debugNext() {
    final current = state;
    if (current == null) return;
    final next = tipLibrary[(tipLibrary.indexOf(current.tip) + 1) % tipLibrary.length];
    final fresh = DailyTip(day: current.day, tip: next);
    state = fresh;
    _save(fresh);
  }

  /// Ответить на вопрос. За правильный ответ — монеты, раз в день.
  Future<void> answer(int option) async {
    final current = state;
    if (current == null || current.answered) return;
    var answered = DailyTip(day: current.day, tip: current.tip, answer: option);
    state = answered;
    if (answered.correct) {
      final rewarded = await _reward();
      answered = DailyTip(day: current.day, tip: current.tip, answer: option, rewarded: rewarded);
      state = answered;
    }
    _save(answered);
  }

  /// С аккаунтом монеты выдаёт сервер (он же следит за «раз в день»), без — телефон.
  Future<bool> _reward() async {
    if (!ref.read(accountProvider).signedIn) {
      await ref.read(heroProvider.notifier).addCoins(GameConfig.tipCoins);
      return true;
    }
    try {
      await ref.read(apiProvider).post('/v1/tips/reward', {});
      await ref.read(accountProvider.notifier).sync();
      return true;
    } on ApiException {
      // 409 — сегодня награда уже получена; без сети — просто без монет.
      return false;
    }
  }

  ({DailyTip? tip, List<String> recent}) _load() {
    final raw = ref.read(prefsProvider).getString(_tipKey);
    if (raw == null) return (tip: null, recent: const []);
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final tip = tipLibrary.where((t) => t.id == j['tipId']).firstOrNull;
      return (
        tip: tip == null
            ? null
            : DailyTip(day: j['day'], tip: tip, answer: j['answer'], rewarded: j['rewarded'] ?? false),
        recent: List<String>.from(j['recent'] ?? const []),
      );
    } catch (_) {
      return (tip: null, recent: const []);
    }
  }

  void _save(DailyTip tip) => ref.read(prefsProvider).setString(
    _tipKey,
    jsonEncode({
      'day': tip.day,
      'tipId': tip.tip.id,
      'answer': tip.answer,
      'rewarded': tip.rewarded,
      'recent': _recent,
    }),
  );

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final tipsProvider = NotifierProvider<TipsNotifier, DailyTip?>(TipsNotifier.new);
