import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/cardio.dart';
import 'account_state.dart';
import 'api_cache.dart';

/// Личная норма пульса вида кардио (server/src/game/cardio-norm.ts): первые
/// сессии — калибровка с нижней границы, дальше — 92% своего рабочего пульса
/// на этом виде, не выше общего порога зоны 2. Считает сервер.
class CardioNorm {
  const CardioNorm({
    required this.bound,
    required this.calibrating,
    required this.sessions,
  });

  final int bound;
  final bool calibrating;
  final int sessions;

  factory CardioNorm.fromJson(Map<String, dynamic> j) => CardioNorm(
    bound: (j['bound'] as num).toInt(),
    calibrating: j['calibrating'] as bool? ?? false,
    sessions: (j['sessions'] as num?)?.toInt() ?? 0,
  );
}

typedef CardioNorms = ({
  int calibrationSessions,
  Map<String, CardioNorm> norms,
});

/// Без аккаунта норм нет — общий порог (поток пустой, значения нет).
final cardioNormsProvider = StreamProvider<CardioNorms>((ref) {
  if (!ref.watch(accountProvider.select((a) => a.signedIn))) {
    return const Stream.empty();
  }
  return cachedGet(ref, '/v1/cardio/norms', (raw) {
    final j = raw as Map<String, dynamic>;
    return (
      calibrationSessions: (j['calibrationSessions'] as num?)?.toInt() ?? 2,
      norms: {
        for (final e in (j['norms'] as Map).entries)
          e.key as String: CardioNorm.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
    );
  });
});

/// Норма вида [activity], если сервер её уже посчитал.
CardioNorm? cardioNormOf(CardioNorms? norms, CardioActivity activity) =>
    norms?.norms[activity.name];
