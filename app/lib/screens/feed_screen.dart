import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/avatar_icons.dart';
import '../game/body_part.dart';
import '../game/shop.dart';
import '../net/api_client.dart';
import '../state/account_state.dart';
import '../state/showcase_state.dart';
import '../theme.dart';
import '../widgets/status_toast.dart';

/// Событие ленты друзей (PLAN 4.8, п. 7). Без пульса и тренировок по дням.
class FeedItem {
  const FeedItem({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.showcase,
    required this.kind,
    required this.data,
    required this.at,
    required this.fists,
    required this.myFist,
    required this.mine,
  });

  final String id;
  final String userId;
  final String nickname;
  final Showcase showcase;
  final String kind;
  final Map<String, dynamic> data;
  final DateTime at;
  final int fists;
  final bool myFist;
  final bool mine;

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
    id: j['id'] as String,
    userId: j['userId'] as String,
    nickname: j['nickname'] as String,
    showcase: j['showcase'] is Map
        ? Showcase.fromJson(Map<String, dynamic>.from(j['showcase'] as Map))
        : const Showcase(),
    kind: j['kind'] as String,
    data: Map<String, dynamic>.from(j['data'] as Map? ?? const {}),
    at: DateTime.parse(j['at'] as String).toLocal(),
    fists: (j['fists'] as num).toInt(),
    myFist: j['myFist'] == true,
    mine: j['mine'] == true,
  );

  /// «прокачал спину до 7», «держит серию 14 дней»…
  String get text {
    switch (kind) {
      case 'level_up':
        final part = BodyPart.values.asNameMap()[data['part']];
        return 'качает${part == null ? '' : ' ${_whom[part]}'}: уже уровень ${data['level']}';
      case 'streak':
        return 'держит серию ${data['days']} дней 🔥';
      case 'comeback':
        return 'снова тренируется после паузы';
      case 'hero_level':
        final item = ShopCatalog.all
            .where((i) => i.id == data['item'])
            .firstOrNull;
        return 'герой достиг уровня ${data['level']}'
            '${item == null ? '' : ' — подарок: ${item.name.toLowerCase()}'}';
      default:
        return 'есть новости';
    }
  }
}

final feedProvider = FutureProvider.autoDispose<List<FeedItem>>((ref) async {
  final list = await ref.read(apiProvider).getList('/v1/feed');
  return [
    for (final j in list)
      FeedItem.fromJson(Map<String, dynamic>.from(j as Map)),
  ];
});

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(accountProvider).signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Лента друзей')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Лента работает с аккаунтом: войди, добавь друзей — '
              'здесь будут их уровни, серии и возвращения',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }
    final feed = ref.watch(feedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Лента друзей')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(feedProvider.future),
        child: feed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(feedProvider),
                  child: const Text('Не загрузилось — повторить'),
                ),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(32),
                  children: const [
                    SizedBox(height: 80),
                    Text(
                      'Пока тихо. Новые уровни, серии и возвращения друзей '
                      'появятся здесь — подбадривай их кулаком 👊',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _FeedRow(item: items[i]),
                ),
        ),
      ),
    );
  }
}

class _FeedRow extends ConsumerStatefulWidget {
  const _FeedRow({required this.item});

  final FeedItem item;

  @override
  ConsumerState<_FeedRow> createState() => _FeedRowState();
}

class _FeedRowState extends ConsumerState<_FeedRow> {
  late bool _mine = widget.item.myFist;
  late int _count = widget.item.fists;

  Future<void> _toggle() async {
    // Сразу показываем, сервер подтверждает.
    setState(() {
      _mine = !_mine;
      _count += _mine ? 1 : -1;
    });
    try {
      await ref.read(apiProvider).post('/v1/feed/${widget.item.id}/fist', {});
    } on ApiException catch (e) {
      setState(() {
        _mine = !_mine;
        _count += _mine ? 1 : -1;
      });
      showStatusError(e.message, network: e.isNetwork);
    }
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes} мин';
    if (d.inHours < 24) return '${d.inHours} ч';
    return '${d.inDays} дн.';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          AvatarBadge(
            iconId: item.showcase.icon,
            background: item.showcase.background,
            size: 40,
            name: item.nickname,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: item.mine ? 'Ты ' : '${item.nickname} ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: item.text),
                  TextSpan(
                    text: ' · ${_ago(item.at)}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (!item.mine)
            TextButton(
              onPressed: _toggle,
              style: TextButton.styleFrom(
                foregroundColor: _mine ? accent : AppColors.textMuted,
              ),
              child: Text('👊 ${_count > 0 ? _count : ''}'),
            )
          else if (_count > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '👊 $_count',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// «прокачал спину»: части тела в винительном падеже.
const _whom = {
  BodyPart.chest: 'грудь',
  BodyPart.back: 'спину',
  BodyPart.arms: 'руки',
  BodyPart.legs: 'ноги',
  BodyPart.core: 'пресс',
  BodyPart.cardio: 'кардио',
};

/// Иконка ленты для меню.
const feedIcon = LucideIcons.newspaper;
