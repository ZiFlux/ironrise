import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../net/api_client.dart';
import '../state/account_state.dart';
import '../state/server_game.dart';
import '../theme.dart';

/// Друзья (экран 8): поиск по нику, заявки, список и кто на тебя нападал.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  Timer? _debounce;
  String _query = '';
  List<PlayerRef> _found = const [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    setState(() => _query = q.trim());
    if (_query.length < 2) {
      setState(() => _found = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(_query));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final list = await ref
          .read(apiProvider)
          .getList('/v1/users/search?nick=${Uri.encodeQueryComponent(q)}');
      if (!mounted || q != _query) return;
      setState(
        () => _found = [
          for (final p in list)
            (userId: p['userId'] as String, nickname: p['nickname'] as String),
        ],
      );
    } on ApiException catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Любое действие с друзьями: выполнить, обновить список, показать ошибку.
  Future<void> _act(Future<void> Function() action, {String? done}) async {
    try {
      await action();
      ref.invalidate(serverFriendsProvider);
      ref.invalidate(serverFriendsLeagueProvider);
      if (done != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } on ApiException catch (e) {
      _toast(e);
    }
  }

  void _toast(ApiException e) {
    if (!mounted) return;
    final text = switch (e.status) {
      0 => 'Нет связи с сервером',
      404 => 'Игрок не найден',
      409 => 'Вы уже друзья',
      _ => e.message,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiProvider);
    final data = ref.watch(serverFriendsProvider);
    final attacks = ref.watch(serverAttacksProvider).value ?? const [];
    final d = data.value;
    final known = {
      if (d != null) ...[
        for (final f in d.friends) f.id,
        for (final r in d.incoming) r.userId,
        for (final r in d.outgoing) r.userId,
      ],
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Друзья')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          TextField(
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Ник игрока',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
          for (final p in _found)
            _Row(
              title: p.nickname,
              trailing: known.contains(p.userId)
                  ? const Text(
                      'уже в списке',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    )
                  : TextButton(
                      onPressed: () => _act(
                        () => api.post('/v1/friends/requests', {
                          'nickname': p.nickname,
                        }),
                        done: 'Заявка отправлена',
                      ),
                      child: const Text('Добавить'),
                    ),
            ),
          if (_query.length >= 2 && !_searching && _found.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Никого не нашлось',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          if (data.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: TextButton(
                onPressed: () => ref.invalidate(serverFriendsProvider),
                child: const Text('Нет связи с сервером. Повторить'),
              ),
            ),
          if (d != null) ...[
            if (d.incoming.isNotEmpty) ...[
              const _Section('Хотят дружить'),
              for (final r in d.incoming)
                _Row(
                  title: r.nickname,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Отклонить',
                        onPressed: () =>
                            _act(() => api.delete('/v1/friends/${r.userId}')),
                        icon: const Icon(
                          LucideIcons.x,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _act(
                          () => api.post(
                            '/v1/friends/requests/${r.userId}/accept',
                            {},
                          ),
                          done: '${r.nickname} теперь в друзьях',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(96, 36),
                        ),
                        child: const Text('Принять'),
                      ),
                    ],
                  ),
                ),
            ],
            const _Section('Друзья'),
            if (d.friends.isEmpty)
              const Text(
                'Пока никого. Найди друга по нику: заявка придёт ему в приложение',
                style: TextStyle(color: AppColors.textMuted),
              ),
            for (final f in d.friends)
              _Row(
                title: f.name,
                subtitle: 'сила ${f.power}',
                trailing: IconButton(
                  tooltip: 'Удалить из друзей',
                  onPressed: () => _confirmRemove(
                    f.name,
                    () => api.delete('/v1/friends/${f.id}'),
                  ),
                  icon: const Icon(
                    LucideIcons.userMinus,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            if (d.outgoing.isNotEmpty) ...[
              const _Section('Ждут ответа'),
              for (final r in d.outgoing)
                _Row(
                  title: r.nickname,
                  trailing: TextButton(
                    onPressed: () =>
                        _act(() => api.delete('/v1/friends/${r.userId}')),
                    child: const Text('Отменить'),
                  ),
                ),
            ],
          ],
          if (attacks.isNotEmpty) ...[
            const _Section('На тебя нападали за неделю'),
            for (final a in attacks)
              _Row(
                title: a.attacker,
                subtitle:
                    '${a.at.day}.${a.at.month.toString().padLeft(2, '0')}',
                trailing: Text(
                  a.attackerWon ? 'победил' : 'ты отбился',
                  style: TextStyle(
                    fontSize: 13,
                    color: a.attackerWon
                        ? AppColors.textMuted
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    String name,
    Future<void> Function() remove,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Удалить $name из друзей?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) await _act(remove);
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.hairline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}
