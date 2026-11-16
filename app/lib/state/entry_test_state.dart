import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/entry_test.dart';
import 'account_state.dart';
import 'providers.dart';

const _testsKey = 'entry_tests_v1';
const _skippedKey = 'entry_test_skipped_at';

/// Ответил «да» на вопрос о здоровье в онбординге — входную тренировку не предлагаем.
const healthRiskKey = 'health_risk';

/// Входные тренировки игрока (п. 116): первая и повторные раз в 4 недели, новые первыми.
class EntryTestNotifier extends Notifier<List<EntryTestResult>> {
  @override
  List<EntryTestResult> build() {
    final raw = ref.read(prefsProvider).getString(_testsKey);
    if (raw == null) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          EntryTestResult.fromJson(Map<String, dynamic>.from(j as Map)),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Не предлагаем при риске по здоровью (ответ «да» в онбординге).
  bool get allowed =>
      !(ref.read(prefsProvider).getBool(healthRiskKey) ?? false);

  /// Первую ещё не проходил — предлагаем настойчиво (TRAINING_SYSTEM.md 13.6).
  bool get firstDue => allowed && state.isEmpty;

  /// Повторная — через 4 недели после последней.
  bool retestDue(DateTime now) =>
      allowed &&
      state.isNotEmpty &&
      now.difference(state.first.at) >= entryRetestAfter;

  /// Отложил: напомним через день.
  bool snoozed(DateTime now) {
    final raw = ref.read(prefsProvider).getString(_skippedKey);
    final at = raw == null ? null : DateTime.tryParse(raw);
    return at != null && now.difference(at) < const Duration(days: 1);
  }

  Future<void> skip() => ref
      .read(prefsProvider)
      .setString(_skippedKey, DateTime.now().toIso8601String());

  /// Сохранить результат: уровень и отжимания/подтягивания — в героя (от них
  /// зависят план и ступени упражнений), результаты — на сервер для статистики и монет.
  Future<void> save(EntryTestResult result) async {
    final hero = ref.read(heroProvider);
    final level = entryLevel(result, hero?.body.sex);
    state = [result, ...state];
    await ref
        .read(prefsProvider)
        .setString(_testsKey, jsonEncode([for (final r in state) r.toJson()]));
    await ref.read(prefsProvider).remove(_skippedKey);
    if (hero != null) {
      await ref
          .read(heroProvider.notifier)
          .save(
            hero.copyWith(
              body: hero.body.copyWith(
                entryLevel: level.name,
                pushUps: result.kneePushUps ? null : result.pushUps,
                pullUps: result.pullUps,
              ),
            ),
          );
    }
    await ref.read(accountProvider.notifier).enqueueEntryTest({
      'clientId': newClientId(),
      'at': result.at.toUtc().toIso8601String(),
      'level': level.name,
      'results': result.resultsJson(),
    });
  }
}

final entryTestProvider =
    NotifierProvider<EntryTestNotifier, List<EntryTestResult>>(
      EntryTestNotifier.new,
    );
