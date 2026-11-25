import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_config.dart';
import '../game/tips.dart';
import '../net/api_client.dart';
import 'account_state.dart';
import 'program_state.dart';
import 'providers.dart';

const _tipKey = 'daily_tips_v2';

/// Сколько последних советов не повторять: ≈ 2 недели по 3–5 советов в день.
/// Библиотека больше (≈ 110), так что подбор по делу всё равно есть из чего.
const _recentLimit = 75;

/// Советы дня: в день тренировки — 3 (время уходит на зал), в день отдыха — 5
/// (есть время почитать), по каждому вопрос.
const tipsOnTrainingDay = 3;
const tipsOnRestDay = 5;

/// Монеты за опрос: за каждый верный ответ и бонус, если верны все (как на сервере).
int tipQuizCoins(int correct, int total) =>
    correct * GameConfig.tipCoinsPerAnswer +
    (correct == total ? GameConfig.tipQuizBonus : 0);

/// Подборка советов на сегодня и ответы на вопросы.
class DailyTips {
  const DailyTips({
    required this.day,
    required this.tips,
    this.answers = const {},
    this.coins,
  });

  final String day;
  final List<Tip> tips;

  /// id совета → выбранный вариант.
  final Map<String, int> answers;

  /// Монеты за опрос; null — ещё не все ответы или награда не получена.
  final int? coins;

  bool answered(Tip tip) => answers.containsKey(tip.id);
  bool correct(Tip tip) => answers[tip.id] == tip.question.correct;
  int get answeredCount => tips.where(answered).length;
  int get correctCount => tips.where(correct).length;
  bool get done => answeredCount == tips.length;

  /// Сколько можно получить за все верные ответы.
  int get maxCoins => tipQuizCoins(tips.length, tips.length);

  DailyTips copyWith({Map<String, int>? answers, int? coins}) => DailyTips(
    day: day,
    tips: tips,
    answers: answers ?? this.answers,
    coins: coins ?? this.coins,
  );
}

class TipsNotifier extends Notifier<DailyTips?> {
  List<String> _recent = const [];

  @override
  DailyTips? build() {
    final hero = ref.watch(heroProvider);
    if (hero == null) return null;
    final today = _dayKey(DateTime.now());
    final saved = _load();
    _recent = saved.recent;
    if (saved.tips != null && saved.tips!.day == today) return saved.tips;
    final fresh = _pick(DateTime.now());
    _save(fresh);
    return fresh;
  }

  DailyTips _pick(DateTime now) {
    final hero = ref.read(heroProvider)!;
    final training = hero.isLoadDay(now);
    final tips = TipPicker.pickSet(
      day: now,
      isTrainingDay: training,
      planExerciseIds: [
        for (final e in ref.read(todayPlanProvider).day.exercises) e.exerciseId,
      ],
      lagging: hero.lagging.firstOrNull,
      recentTipIds: _recent,
      count: training ? tipsOnTrainingDay : tipsOnRestDay,
    );
    _recent = [
      for (final t in tips) t.id,
      ..._recent,
    ].take(_recentLimit).toList();
    return DailyTips(day: _dayKey(now), tips: tips);
  }

  /// Только для разработки: новая подборка вместо сегодняшней.
  void debugNext() {
    final fresh = _pick(DateTime.now());
    state = fresh;
    _save(fresh);
  }

  /// Ответить на вопрос совета. Когда отвечены все — награда за опрос, раз в день.
  Future<void> answer(Tip tip, int option) async {
    final current = state;
    if (current == null || current.answered(tip)) return;
    var next = current.copyWith(answers: {...current.answers, tip.id: option});
    state = next;
    if (next.done) {
      final coins = await _reward(next.correctCount, next.tips.length);
      next = next.copyWith(coins: coins);
      state = next;
    }
    _save(next);
  }

  /// С аккаунтом монеты выдаёт сервер (он же следит за «раз в день»), без — телефон.
  Future<int> _reward(int correct, int total) async {
    final coins = tipQuizCoins(correct, total);
    if (!ref.read(accountProvider).signedIn) {
      if (coins > 0) await ref.read(heroProvider.notifier).addCoins(coins);
      return coins;
    }
    try {
      // Без сети награда встаёт в очередь: монеты придут при синхронизации
      // (сервер сам следит за «раз в день»).
      final account = ref.read(accountProvider.notifier);
      final r = await account.sendOrQueue('POST', '/v1/tips/reward', {
        'correct': correct,
        'total': total,
      });
      if (r == null) return coins;
      await account.sync();
      return (r['coins'] as num?)?.toInt() ?? coins;
    } on ApiException {
      // 409 — сегодня награда уже получена.
      return 0;
    }
  }

  ({DailyTips? tips, List<String> recent}) _load() {
    final raw = ref.read(prefsProvider).getString(_tipKey);
    if (raw == null) return (tips: null, recent: const []);
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final tips = [
        for (final id in List<String>.from(j['tipIds'] ?? const []))
          ?tipLibrary.where((t) => t.id == id).firstOrNull,
      ];
      return (
        tips: tips.isEmpty
            ? null
            : DailyTips(
                day: j['day'],
                tips: tips,
                answers: Map<String, int>.from(j['answers'] ?? const {}),
                coins: j['coins'],
              ),
        recent: List<String>.from(j['recent'] ?? const []),
      );
    } catch (_) {
      return (tips: null, recent: const []);
    }
  }

  void _save(DailyTips tips) => ref
      .read(prefsProvider)
      .setString(
        _tipKey,
        jsonEncode({
          'day': tips.day,
          'tipIds': [for (final t in tips.tips) t.id],
          'answers': tips.answers,
          'coins': tips.coins,
          'recent': _recent,
        }),
      );

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final tipsProvider = NotifierProvider<TipsNotifier, DailyTips?>(
  TipsNotifier.new,
);
