/// Отдельное согласие на отправку ответов о самочувствии (п. 81). Ответы о боли —
/// данные о здоровье (152-ФЗ, ст. 10). Без согласия подстройка плана всё равно
/// работает — на телефоне; на сервер ничего не уходит.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/wellbeing.dart';
import '../net/api_client.dart';
import 'account_state.dart';
import 'providers.dart';

const _key = 'wellbeing_consent_v1';

/// null — ещё не спрашивали, true / false — ответ.
class WellbeingConsentNotifier extends Notifier<bool?> {
  @override
  bool? build() => ref.read(prefsProvider).getBool(_key);

  /// Дать или отозвать. Отзыв на сервере удаляет все сохранённые ответы.
  Future<void> set(bool granted) async {
    state = granted;
    await ref.read(prefsProvider).setBool(_key, granted);
    if (!ref.read(accountProvider).signedIn) return;
    try {
      // Без сети — в очередь: отзыв согласия дойдёт до сервера при синхронизации.
      await ref.read(accountProvider.notifier).sendOrQueue(
        'PUT',
        '/v1/me/consent/wellbeing',
        {'granted': granted},
        key: 'wellbeingConsent',
      );
    } on ApiException {
      // Нет сети или старый сервер: без согласия на сервере ответ просто не примут.
    }
  }

  /// Отправить ответ, если согласие дано и есть аккаунт. Ошибки не мешают тренировке.
  Future<void> report({
    required Feeling feeling,
    PainZone? zone,
    PainKind? kind,
    List<String> exercises = const [],
  }) async {
    if (state != true || !ref.read(accountProvider).signedIn) return;
    try {
      // Ответ из зала без сети не теряется — уйдёт при синхронизации.
      await ref.read(accountProvider.notifier).sendOrQueue(
        'POST',
        '/v1/wellbeing',
        {
          'feeling': feeling.name,
          'zone': ?zone?.name,
          'painKind': ?kind?.name,
          'exercises': exercises.take(12).toList(),
        },
      );
    } on ApiException {
      // Не отправилось — не страшно: план на телефоне уже подстроен.
    }
  }
}

final wellbeingConsentProvider =
    NotifierProvider<WellbeingConsentNotifier, bool?>(
      WellbeingConsentNotifier.new,
    );
