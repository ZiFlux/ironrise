import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/nickname.dart';
import '../net/api_client.dart';
import '../state/account_state.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'format.dart';

/// Сменить ник. С аккаунтом — через сервер: раз в 30 дней, раньше — за монеты;
/// без аккаунта ник только на телефоне и меняется свободно.
Future<void> showNicknameDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _NicknameDialog());

class _NicknameDialog extends ConsumerStatefulWidget {
  const _NicknameDialog();

  @override
  ConsumerState<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends ConsumerState<_NicknameDialog> {
  late final _field = TextEditingController(
    text: ref.read(heroProvider)?.nickname ?? '',
  );
  String? _serverError;
  bool _busy = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save({required bool paid}) async {
    final nickname = normalizeNickname(_field.text);
    setState(() {
      _busy = true;
      _serverError = null;
    });
    try {
      // Нотификатор — до await: диалог могут закрыть во время запроса (п. 137).
      final heroes = ref.read(heroProvider.notifier);
      if (ref.read(accountProvider).signedIn) {
        final me = await ref.read(apiProvider).put('/v1/me/nickname', {
          'nickname': nickname,
          if (paid) 'paid': true,
        });
        await heroes.applyServer(me);
      } else {
        await heroes.renameLocally(nickname);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(
        () => _serverError = e.isNetwork
            ? 'Нет связи с сервером'
            : nicknameServerError(e.message) ?? e.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final signedIn = ref.watch(accountProvider).signedIn;
    final next = signedIn ? hero.nextNicknameChangeAt : null;
    final waiting = next != null && next.isAfter(DateTime.now());
    final nickname = normalizeNickname(_field.text);
    final problem = nickname == hero.nickname ? '' : nicknameProblem(nickname);
    // Только регистр или пробелы — сервер меняет бесплатно и без ожидания.
    final cosmetic = nicknameKey(nickname) == nicknameKey(hero.nickname);
    final paid = waiting && !cosmetic;
    final canPay = hero.coins >= nicknameChangeCoins;

    return AlertDialog(
      title: const Text('Ник'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _field,
            autofocus: true,
            maxLength: 20,
            onChanged: (_) => setState(() => _serverError = null),
            decoration: InputDecoration(
              errorText: _serverError ?? (problem == '' ? null : problem),
            ),
          ),
          Text(
            !signedIn
                ? 'Без аккаунта ник хранится только на телефоне.'
                : waiting
                ? 'Бесплатно — с ${formatDate(next)}. '
                      'Сейчас — за $nicknameChangeCoins монет (у тебя ${hero.coins}).'
                : 'Менять ник можно раз в $nicknameChangeDays дней. '
                      'Прежний ник ещё $nicknameChangeDays дней останется за вами.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy || problem != null || (paid && !canPay)
              ? null
              : () => _save(paid: paid),
          child: Text(paid ? 'За $nicknameChangeCoins монет' : 'Сохранить'),
        ),
      ],
    );
  }
}
