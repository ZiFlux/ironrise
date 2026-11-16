import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../net/api_client.dart';
import '../net/push.dart';
import '../state/account_state.dart';
import '../state/server_game.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/status_toast.dart';

/// Меню уведомлений: заявки, нападения, напоминания о серии.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markRead(WidgetRef ref, [List<String>? ids]) async {
    try {
      await ref.read(apiProvider).post('/v1/notifications/read', {'ids': ?ids});
    } on ApiException {
      // Нет сети — отметим в следующий раз.
    }
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationsProvider);
    final unread = feed.value?.unread ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (unread > 0)
            IconButton(
              tooltip: 'Прочитать все',
              onPressed: () => _markRead(ref),
              icon: const Icon(LucideIcons.checkCheck, size: 20),
            ),
          IconButton(
            tooltip: 'Настройки уведомлений',
            onPressed: () => context.push('/notifications/settings'),
            icon: const Icon(LucideIcons.settings2, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(notificationsProvider),
            child: const Text('Нет связи с сервером. Повторить'),
          ),
        ),
        data: (d) => d.items.isEmpty
            ? const _Empty()
            : RefreshIndicator(
                onRefresh: () => ref.refresh(notificationsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: d.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = d.items[i];
                    return FadeSlideIn(
                      index: i,
                      child: _Tile(
                        n: n,
                        onTap: () {
                          if (!n.read) _markRead(ref, [n.id]);
                          context.go(n.path);
                        },
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.bell, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Пока пусто',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            'Здесь появятся заявки в друзья, нападения и напоминания о серии',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.n, required this.onTap});

  final AppNotification n;
  final VoidCallback onTap;

  static const _icons = {
    'friend_request': LucideIcons.userPlus,
    'friend_accepted': LucideIcons.users,
    'attacked': LucideIcons.swords,
    'streak_risk': LucideIcons.flame,
    'daily_tip': LucideIcons.lightbulb,
    'duels_refreshed': LucideIcons.swords,
    'training_reminder': LucideIcons.alarmClock,
  };

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _icons[n.type] ?? LucideIcons.bell,
              size: 18,
              color: n.read ? AppColors.textMuted : accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ago(n.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (!n.read)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «только что», «5 мин назад», «3 ч назад», «вчера», «12.11».
String _ago(DateTime t, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.inMinutes < 1) return 'только что';
  if (d.inMinutes < 60) return '${d.inMinutes} мин назад';
  if (d.inHours < 24 && t.day == n.day) return '${d.inHours} ч назад';
  final yesterday = DateTime(n.year, n.month, n.day - 1);
  final isYesterday =
      t.year == yesterday.year &&
      t.month == yesterday.month &&
      t.day == yesterday.day;
  if (isYesterday) return 'вчера';
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}';
}

/// Настройки уведомлений: какие пуши слать и во сколько напоминать о серии.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState
    extends ConsumerState<NotificationSettingsScreen> {
  Map<String, dynamic>? _settings;
  String? _error;

  static const _toggles = [
    ('friend_request', 'Заявки в друзья', 'Кто-то хочет добавить тебя'),
    ('friend_accepted', 'Новые друзья', 'Твою заявку приняли'),
    ('attacked', 'Нападения', 'Друг вызвал тебя на дуэль'),
    ('streak_risk', 'Серия под угрозой', 'Если сегодня последний день отдыха'),
    ('daily_tip', 'Совет дня', 'Утром: новый совет и монеты за ответ'),
    ('duels_refreshed', 'Новые соперники', 'Днём: в дуэлях обновились боты'),
    (
      'training_reminder',
      'Время тренировки',
      'За час до привычного времени, в день по графику',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(apiProvider).get('/v1/me/notification-settings');
      if (mounted) setState(() => _settings = s);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isNetwork ? 'Нет связи с сервером' : e.message);
    }
  }

  Future<void> _set(String key, Object value) async {
    final previous = _settings!;
    setState(() => _settings = {...previous, key: value});
    try {
      await ref
          .read(apiProvider)
          .put('/v1/me/notification-settings', _settings!);
    } on ApiException {
      if (!mounted) return;
      setState(() => _settings = previous);
      showStatus(
        'Не сохранилось: нет связи с сервером',
        kind: StatusKind.offline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки уведомлений')),
      body: s == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _load();
                      },
                      child: Text('$_error. Повторить'),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              children: [
                if (!pushConfigured)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Text(
                      'В этой сборке пуши выключены: события будут только в ленте уведомлений',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                for (final (key, title, subtitle) in _toggles)
                  SwitchListTile(
                    value: s[key] == true,
                    onChanged: (v) => _set(key, v),
                    title: Text(title),
                    subtitle: Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ListTile(
                  enabled: s['streak_risk'] == true,
                  title: const Text('Время напоминания о серии'),
                  subtitle: const Text(
                    'По твоему часовому поясу',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  trailing: DropdownButton<int>(
                    value: (s['streakReminderHour'] as num).toInt(),
                    underline: const SizedBox.shrink(),
                    onChanged: s['streak_risk'] == true
                        ? (h) => _set('streakReminderHour', h!)
                        : null,
                    items: [
                      for (var h = 6; h <= 23; h++)
                        DropdownMenuItem(
                          value: h,
                          child: Text('${h.toString().padLeft(2, '0')}:00'),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  enabled:
                      s['daily_tip'] == true || s['duels_refreshed'] == true,
                  title: const Text('Утренние уведомления'),
                  subtitle: const Text(
                    'Совет дня — в это время, новые соперники — через 4 часа',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  trailing: DropdownButton<int>(
                    value: ((s['morningHour'] as num?) ?? 9).toInt(),
                    underline: const SizedBox.shrink(),
                    onChanged:
                        s['daily_tip'] == true || s['duels_refreshed'] == true
                        ? (h) => _set('morningHour', h!)
                        : null,
                    items: [
                      for (var h = 6; h <= 12; h++)
                        DropdownMenuItem(
                          value: h,
                          child: Text('${h.toString().padLeft(2, '0')}:00'),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
                  child: Text(
                    'Если пуши не приходят совсем, проверьте, что уведомления IronRise разрешены '
                    'в настройках Android',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
    );
  }
}
