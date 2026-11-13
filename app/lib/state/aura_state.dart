import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/aura.dart';
import 'account_state.dart';

/// Прогресс одной ауры: тренировок, уровень (0 — не открыта), до следующего.
typedef AuraProgress = ({AuraKind kind, int sessions, int level, int? toNext});

/// Ауры с сервера: выбранная, лимит тренировок недели и прогресс каждой.
class AuraInfo {
  const AuraInfo({
    required this.equipped,
    required this.sessionsThisWeek,
    required this.perWeek,
    required this.auras,
  });

  factory AuraInfo.fromJson(Map<String, dynamic> j) => AuraInfo(
    equipped: AuraKind.values.asNameMap()[j['equipped']],
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
  final int sessionsThisWeek;
  final int perWeek;
  final List<AuraProgress> auras;

  bool get canTrain => sessionsThisWeek < perWeek;
}

class AuraNotifier extends AsyncNotifier<AuraInfo> {
  @override
  Future<AuraInfo> build() async =>
      AuraInfo.fromJson(await ref.read(apiProvider).get('/v1/auras'));

  /// Тренировка ауры пройдена: +1 к прогрессу (сервер следит за лимитом).
  Future<void> train(AuraKind kind) async {
    final j = await ref
        .read(apiProvider)
        .post('/v1/auras/${kind.name}/train', const {});
    state = AsyncData(AuraInfo.fromJson(j));
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
