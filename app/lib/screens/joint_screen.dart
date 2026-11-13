import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/game_config.dart';
import '../net/api_client.dart';
import '../state/account_state.dart';
import '../state/joint_state.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/every_second.dart';
import '../widgets/sign_up_card.dart';
import '../widgets/status_toast.dart';

final _bonusPercent = (GameConfig.jointBonus * 100).round();

/// Совместная тренировка: один показывает код, остальные рядом его вводят.
class JointScreen extends ConsumerStatefulWidget {
  const JointScreen({super.key});

  @override
  ConsumerState<JointScreen> createState() => _JointScreenState();
}

class _JointScreenState extends ConsumerState<JointScreen> {
  final _code = TextEditingController();
  Timer? _poll;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Пока открыт экран — видно, кто подключился.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (ref.read(jointProvider).value != null) {
        ref.read(jointProvider.notifier).reload().catchError((_) {});
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      setState(
        () => _error = switch (e.status) {
          0 => 'Сервер недоступен. Проверьте сеть',
          404 => 'Код не найден или уже не действует',
          409 => 'В тренировке уже 5 человек',
          400 => 'Это ваш собственный код',
          _ => e.message,
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(accountProvider.select((a) => a.signedIn));
    final joint = ref.watch(jointProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Тренировка вместе')),
      body: !signedIn
          ? const _NeedAccount()
          : joint.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(jointProvider),
                  child: const Text('Не удалось загрузить. Повторить'),
                ),
              ),
              data: (s) => s == null ? _start() : _session(context, s),
            ),
    );
  }

  Widget _start() {
    final notifier = ref.read(jointProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _Explainer(),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : () => _run(notifier.create),
          icon: const Icon(LucideIcons.qrCode, size: 18),
          label: const Text('Показать код друзьям'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Или введите код с телефона друга',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '6 цифр',
                  counterText: '',
                ),
                onSubmitted: (_) => _join(),
              ),
            ),
            const SizedBox(width: 8),
            // В теме кнопки растягиваются на всю ширину — в строке с полем
            // это бесконечная ширина, поэтому минимальный размер задаём явно.
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _busy ? null : _join,
              child: const Text('Подключиться'),
            ),
          ],
        ),
        if (_error != null) _ErrorText(_error!),
      ],
    );
  }

  void _join() {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Код — 6 цифр');
      return;
    }
    _run(() => ref.read(jointProvider.notifier).join(code));
  }

  Widget _session(BuildContext context, JointSession s) {
    final accent = Theme.of(context).colorScheme.primary;
    final me = ref.watch(heroProvider)?.nickname ?? '';
    final notifier = ref.read(jointProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (s.isHost)
          EverySecond(
            builder: (_) {
              final left = s.codeUntil.difference(DateTime.now());
              if (s.code == null || left.isNegative) {
                return OutlinedButton(
                  onPressed: _busy ? null : () => _run(notifier.create),
                  child: const Text('Новый код для подключения'),
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Код для друзей рядом',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        child: Text(
                          '${s.code!.substring(0, 3)} ${s.code!.substring(3)}',
                          style: figureStyle(size: 44)
                              .copyWith(color: accent, letterSpacing: 4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Действует ещё ${left.inMinutes + 1} мин',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              s.bonusActive ? LucideIcons.flame : LucideIcons.hourglass,
              size: 18,
              color: s.bonusActive ? accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.bonusActive
                    ? 'Бонус +$_bonusPercent% активен до ${_hm(s.endsAt)}'
                    : 'Ждём друзей — бонус включится, когда подключится хотя бы один',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: s.bonusActive ? accent : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final m in s.members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              m.isHost ? LucideIcons.crown : LucideIcons.user,
              size: 20,
            ),
            title: Text(m.nickname == me ? '${m.nickname} (вы)' : m.nickname),
            trailing: m.nickname == me
                ? null
                : IconButton(
                    tooltip: 'Добавить в друзья',
                    icon: const Icon(LucideIcons.userPlus, size: 20),
                    onPressed: () => _addFriend(m.nickname),
                  ),
          ),
        if (_error != null) _ErrorText(_error!),
        const SizedBox(height: 16),
        if (s.bonusActive)
          FilledButton(
            onPressed: () => context.go('/workout'),
            child: const Text('К тренировке'),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => _run(notifier.leave),
          child: const Text('Выйти из совместной тренировки'),
        ),
      ],
    );
  }

  Future<void> _addFriend(String nickname) async {
    try {
      final r = await ref.read(apiProvider).post('/v1/friends/requests', {
        'nickname': nickname,
      });
      showStatus(
        r['status'] == 'accepted'
            ? '$nickname теперь в друзьях'
            : 'Заявка отправлена: $nickname',
        kind: StatusKind.success,
      );
    } on ApiException catch (e) {
      showStatusError(
        e.status == 409 ? 'Уже в друзьях' : e.message,
        network: e.isNetwork,
      );
    }
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.users, size: 32, color: accent),
        const SizedBox(height: 12),
        Text(
          'Вместе — на $_bonusPercent% сильнее',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          'Пришли в зал с друзьями? Один показывает код, остальные вводят его, '
          'и все тренировки в ближайшие ${GameConfig.jointSessionHours} часа '
          'дают каждому +$_bonusPercent% опыта и монет. До 5 человек.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _NeedAccount extends StatelessWidget {
  const _NeedAccount();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: [
      const _Explainer(),
      const SizedBox(height: 24),
      const Text(
        'Совместные тренировки работают через сервер — нужен аккаунт.',
        style: TextStyle(fontSize: 14),
      ),
      const SizedBox(height: 16),
      const SignUpCard(),
    ],
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13),
    ),
  );
}
