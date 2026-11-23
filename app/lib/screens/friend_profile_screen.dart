import '../widgets/format.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../avatar/body_frame.dart';
import '../avatar/posing_avatar.dart';
import '../game/avatar_icons.dart';
import '../game/body_part.dart';
import '../game/muscles.dart';
import '../game/progression.dart';
import '../state/account_state.dart';
import '../state/showcase_state.dart';
import '../theme.dart';
import '../widgets/level_plate.dart';

/// Витрина друга с сервера: герой, сила, серия, аватарка, итоги.
class FriendProfile {
  const FriendProfile({
    required this.nickname,
    required this.xp,
    required this.power,
    required this.streakDays,
    required this.look,
    required this.muscles,
    required this.showcase,
    required this.workouts,
    required this.duelWins,
    required this.since,
    required this.premium,
  });

  final String nickname;
  final Map<BodyPart, int> xp;
  final int power;
  final int streakDays;
  final AvatarLook look;
  final MusclePoints muscles;
  final Showcase showcase;
  final int workouts;
  final int duelWins;
  final DateTime since;
  final bool premium;

  Map<BodyPart, int> get levels => Progression.levels(xp);

  factory FriendProfile.fromJson(Map<String, dynamic> j) {
    final xp = Map<String, dynamic>.from(j['xp'] as Map? ?? const {});
    final stats = Map<String, dynamic>.from(j['stats'] as Map? ?? const {});
    AvatarLook look;
    try {
      look = AvatarLook.fromJson(
        Map<String, dynamic>.from(j['appearance'] as Map),
      );
    } catch (_) {
      look = AvatarLook.starter(AvatarSex.male);
    }
    return FriendProfile(
      nickname: j['nickname'] as String,
      xp: {
        for (final p in BodyPart.values) p: (xp[p.name] as num?)?.toInt() ?? 0,
      },
      power: (j['power'] as num?)?.toInt() ?? 0,
      streakDays: (j['streakDays'] as num?)?.toInt() ?? 0,
      look: look,
      muscles: MuscleMath.fromJson(
        (j['muscles'] as Map?)?.cast<String, dynamic>(),
      ),
      showcase: j['showcase'] is Map
          ? Showcase.fromJson(Map<String, dynamic>.from(j['showcase'] as Map))
          : const Showcase(),
      workouts: (stats['workouts'] as num?)?.toInt() ?? 0,
      duelWins: (stats['duelWins'] as num?)?.toInt() ?? 0,
      since:
          DateTime.tryParse(stats['since'] as String? ?? '') ?? DateTime.now(),
      premium: (j['premium'] as Map?)?['active'] == true,
    );
  }
}

final friendProfileProvider = FutureProvider.autoDispose
    .family<FriendProfile, String>((ref, id) async {
      final j = await ref.read(apiProvider).get('/v1/users/$id/profile');
      return FriendProfile.fromJson(j);
    });

class FriendProfileScreen extends ConsumerWidget {
  const FriendProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(friendProfileProvider(userId));
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль друга')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(friendProfileProvider(userId)),
            child: const Text('Не загрузилось — повторить'),
          ),
        ),
        data: (p) => _Body(profile: p),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile});

  final FriendProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final days = DateTime.now().difference(p.since).inDays + 1;
    final pose = p.showcase.pose;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            AvatarBadge(
              iconId: p.showcase.icon,
              background: p.showcase.background,
              size: 64,
              look: p.look,
              levels: p.levels,
              name: p.nickname,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (p.premium) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          LucideIcons.crown,
                          size: 16,
                          color: Color(0xFFD9B25A),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'сила ${p.power} · серия ${daysWord(p.streakDays)} · с IronRise ${daysWord(days)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: pose == null
              ? PosingAvatar(
                  levels: p.levels,
                  look: p.look,
                  muscles: p.muscles,
                  withLamp: true,
                )
              : AvatarView(
                  levels: p.levels,
                  look: p.look,
                  muscles: p.muscles,
                  withLamp: true,
                  pose: pose,
                  poseT: pose == AvatarPose.relaxed ? 0 : 1,
                ),
        ),
        const SizedBox(height: 12),
        for (final row in [
          BodyPart.values.take(3),
          BodyPart.values.skip(3),
        ]) ...[
          Row(
            children: [
              for (final (i, part) in row.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: LevelPlate(part: part, xp: p.xp[part] ?? 0),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (i, (value, label)) in [
              ('${p.workouts}', 'тренировок'),
              ('${p.duelWins}', 'побед в дуэлях'),
              ('${p.streakDays}', 'серия'),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(value, style: figureStyle(size: 20)),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
