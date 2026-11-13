import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/avatar_icons.dart';
import '../net/api_client.dart';
import '../state/account_state.dart';
import '../state/showcase_state.dart';
import '../theme.dart';
import 'status_toast.dart';

/// Напарник по серии (PLAN 4.8, п. 6): общая серия в неделях — каждому
/// нужно 2 тренировки в неделю, пропустил один — сгорает у обоих.
class StreakPair {
  const StreakPair({
    required this.partnerId,
    required this.nickname,
    required this.showcase,
    required this.status,
    required this.invitedByMe,
    this.weeks = 0,
    this.mine = 0,
    this.theirs = 0,
    this.need = 2,
  });

  final String partnerId;
  final String nickname;
  final Showcase showcase;
  final String status;
  final bool invitedByMe;
  final int weeks;
  final int mine;
  final int theirs;
  final int need;

  bool get active => status == 'active';

  static StreakPair? fromJson(Map<String, dynamic> j) {
    final p = j['pair'];
    if (p is! Map) return null;
    final week = Map<String, dynamic>.from(p['thisWeek'] as Map? ?? const {});
    return StreakPair(
      partnerId: p['partnerId'] as String,
      nickname: p['nickname'] as String,
      showcase: p['showcase'] is Map
          ? Showcase.fromJson(Map<String, dynamic>.from(p['showcase'] as Map))
          : const Showcase(),
      status: p['status'] as String,
      invitedByMe: p['invitedByMe'] == true,
      weeks: (p['weeks'] as num?)?.toInt() ?? 0,
      mine: (week['a'] as num?)?.toInt() ?? 0,
      theirs: (week['b'] as num?)?.toInt() ?? 0,
      need: (p['need'] as num?)?.toInt() ?? 2,
    );
  }
}

final pairProvider = FutureProvider.autoDispose<StreakPair?>((ref) async {
  if (!ref.watch(accountProvider).signedIn) return null;
  return StreakPair.fromJson(await ref.read(apiProvider).get('/v1/pair'));
});

/// Позвать друга в напарники.
Future<void> invitePartner(WidgetRef ref, String friendId, String name) async {
  try {
    await ref.read(apiProvider).post('/v1/pair/invite/$friendId', {});
    ref.invalidate(pairProvider);
    showStatus('Позвали $name в напарники', kind: StatusKind.success);
  } on ApiException catch (e) {
    showStatusError(
      e.status == 409 ? 'У кого-то из вас уже есть напарник' : e.message,
      network: e.isNetwork,
    );
  }
}

class PairCard extends ConsumerWidget {
  const PairCard({super.key});

  Future<void> _act(WidgetRef ref, Future<void> Function() f) async {
    try {
      await f();
      ref.invalidate(pairProvider);
    } on ApiException catch (e) {
      showStatusError(e.message, network: e.isNetwork);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(pairProvider).value;
    final api = ref.read(apiProvider);
    const flame = Color(0xFFFF8A3D);
    Widget body;
    if (pair == null) {
      body = const Row(
        children: [
          Icon(LucideIcons.handshake, color: flame),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Напарник по серии: общая серия на двоих — по 2 тренировки в неделю '
              'у каждого. Позови друга кнопкой 🤝 в списке ниже',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    } else if (!pair.active) {
      body = Row(
        children: [
          AvatarBadge(
            iconId: pair.showcase.icon,
            background: pair.showcase.background,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pair.invitedByMe
                  ? 'Ждём, что ${pair.nickname} согласится стать напарником'
                  : '${pair.nickname} зовёт тебя в напарники по серии',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (!pair.invitedByMe)
            TextButton(
              onPressed: () => _act(ref, () => api.post('/v1/pair/accept', {})),
              child: const Text('Принять'),
            ),
          IconButton(
            tooltip: pair.invitedByMe ? 'Отменить' : 'Отказаться',
            onPressed: () => _act(ref, () => api.delete('/v1/pair')),
            icon: const Icon(LucideIcons.x, size: 18),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarBadge(
                iconId: pair.showcase.icon,
                background: pair.showcase.background,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Общая серия с ${pair.nickname}: ${pair.weeks} нед. 🔥',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                onSelected: (_) => _act(ref, () => api.delete('/v1/pair')),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'leave', child: Text('Расстаться')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (who, n) in [
            ('Ты', pair.mine),
            (pair.nickname, pair.theirs),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      who,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (n / pair.need).clamp(0.0, 1.0),
                        minHeight: 6,
                        color: flame,
                        backgroundColor: AppColors.raised,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$n/${pair.need}',
                      textAlign: TextAlign.right,
                      style: figureStyle(
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Text(
            'На этой неделе. Пропустит один — общая серия сгорит у обоих',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(14), child: body),
    );
  }
}
