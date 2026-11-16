import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/anti_fraud.dart';
import '../game/aura.dart';
import '../net/api_client.dart';
import 'account_state.dart';

/// Прогресс одной ауры: тренировок, уровень (0 — не открыта), до следующего.
typedef AuraProgress = ({AuraKind kind, int sessions, int level, int? toNext});

/// Ауры с сервера: выбранная, лимит тренировок недели и прогресс каждой.
class AuraInfo {
  const AuraInfo({
    required this.equipped,
    this.trainedToday = false,
    required this.sessionsThisWeek,
    required this.perWeek,
    required this.auras,
    this.ready = true,
    this.daysLeft = 0,
    this.workoutsLeft = 0,
  });

  factory AuraInfo.fromJson(Map<String, dynamic> j) => AuraInfo(
    equipped: AuraKind.values.asNameMap()[j['equipped']],
    trainedToday: j['trainedToday'] == true,
    // Старый сервер блокировку не присылает — тогда ауры открыты.
    ready: (j['unlock'] as Map?)?['ready'] != false,
    daysLeft: ((j['unlock'] as Map?)?['daysLeft'] as num?)?.toInt() ?? 0,
    workoutsLeft:
        ((j['unlock'] as Map?)?['workoutsLeft'] as num?)?.toInt() ?? 0,
    sessionsThisWeek: (j['sessionsThisWeek'] as num).toInt(),
    perWeek: (j['perWeek'] as num).toInt(),
    auras: [
      for (final a in j['auras'] as List)
        if (AuraKind.values.asNameMap()[a['kind']] case final kind?)
          (
            kind: kind,
            sessions: (a['sessions'] as num).toInt(),
            level: (a['level'] as num).toInt(),
            toNext: (a['toNext'] as num?)?.toInt(),
          ),
    ],
  );

  final AuraKind? equipped;

  /// Сегодня тренировка ауры уже была: следующая — завтра.
  final bool trainedToday;
  final int sessionsThisWeek;
  final int perWeek;
  final List<AuraProgress> auras;

  /// Ауры открываются после недели тренировок с пульсом: по ним — личная норма.
  final bool ready;
  final int daysLeft;
  final int workoutsLeft;

  bool get canTrain => ready && !trainedToday && sessionsThisWeek < perWeek;
}

class AuraNotifier extends AsyncNotifier<AuraInfo> {
  @override
  Future<AuraInfo> build() async =>
      AuraInfo.fromJson(await ref.read(apiProvider).get('/v1/auras'));

  /// Тренировка ауры пройдена: +1 к прогрессу. Сервер проверяет лимит
  /// (раз в день, два в неделю) и пульс с часов за время тренировки.
  /// Нет сети — тренировка встаёт в очередь и уйдёт сама (п. 114): возвращает false.
  Future<bool> train(
    AuraKind kind, {
    required DateTime startedAt,
    required DateTime finishedAt,
    required List<PulseSample> pulse,
  }) async {
    try {
      final j = await ref.read(apiProvider).post(
        '/v1/auras/${kind.name}/train',
        {
          'startedAt': startedAt.toUtc().toIso8601String(),
          'finishedAt': finishedAt.toUtc().toIso8601String(),
          'pulse': [
            for (final s in pulse)
              {'at': s.at.toUtc().toIso8601String(), 'bpm': s.bpm},
          ],
        },
      );
      state = AsyncData(AuraInfo.fromJson(j));
      return true;
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      await ref
          .read(accountProvider.notifier)
          .enqueueAura(
            kind.name,
            startedAt: startedAt,
            finishedAt: finishedAt,
            pulse: pulse,
          );
      return false;
    }
  }

  Future<void> equip(AuraKind? kind) async {
    final j = await ref
        .read(apiProvider)
        .put('/v1/auras/equip/${kind?.name ?? 'none'}', const {});
    state = AsyncData(AuraInfo.fromJson(j));
  }
}

final auraProvider = AsyncNotifierProvider<AuraNotifier, AuraInfo>(
  AuraNotifier.new,
);
