import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_state.dart';

/// Совместная тренировка (ТЗ 3.2) — состояние с сервера: src/joint/joint.service.ts.
class JointSession {
  const JointSession({
    required this.code,
    required this.codeUntil,
    required this.endsAt,
    required this.isHost,
    required this.members,
  });

  factory JointSession.fromJson(Map<String, dynamic> j) => JointSession(
    code: j['code'] as String?,
    codeUntil: DateTime.parse(j['codeUntil'] as String).toLocal(),
    endsAt: DateTime.parse(j['endsAt'] as String).toLocal(),
    isHost: j['isHost'] == true,
    members: [
      for (final m in j['members'] as List)
        (
          nickname: (m as Map)['nickname'] as String,
          isHost: m['isHost'] == true,
        ),
    ],
  );

  /// Код для подключения; null — время подключения вышло.
  final String? code;
  final DateTime codeUntil;
  final DateTime endsAt;
  final bool isHost;
  final List<({String nickname, bool isHost})> members;

  /// Бонус работает, когда в сессии есть хотя бы ещё один человек.
  bool get bonusActive => members.length >= 2 && endsAt.isAfter(DateTime.now());

  List<String> partnersOf(String me) => [
    for (final m in members)
      if (m.nickname != me) m.nickname,
  ];
}

class JointNotifier extends AsyncNotifier<JointSession?> {
  @override
  Future<JointSession?> build() async {
    if (!ref.watch(accountProvider.select((a) => a.signedIn))) return null;
    return _parse(await ref.read(apiProvider).get('/v1/joint'));
  }

  static JointSession? _parse(Map<String, dynamic> j) {
    final s = j['session'];
    return s == null
        ? null
        : JointSession.fromJson(Map<String, dynamic>.from(s as Map));
  }

  Future<void> reload() async {
    final j = await ref.read(apiProvider).get('/v1/joint');
    state = AsyncData(_parse(j));
  }

  /// Создать (или выдать новый код к своей) сессии.
  Future<void> create() async {
    final j = await ref.read(apiProvider).post('/v1/joint', {});
    state = AsyncData(JointSession.fromJson(j));
  }

  Future<void> join(String code) async {
    final j = await ref.read(apiProvider).post('/v1/joint/join', {
      'code': code,
    });
    state = AsyncData(JointSession.fromJson(j));
  }

  Future<void> leave() async {
    await ref.read(apiProvider).delete('/v1/joint');
    state = const AsyncData(null);
  }
}

final jointProvider = AsyncNotifierProvider<JointNotifier, JointSession?>(
  JointNotifier.new,
);
