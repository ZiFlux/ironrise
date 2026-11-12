import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../legal/privacy_policy.dart';
import '../net/api_client.dart';
import 'account_state.dart';
import 'providers.dart';

const _consentKey = 'health_consent_v1';

/// Согласие на обработку данных о пульсе — данных о здоровье (152-ФЗ, ст. 10).
/// Без него пульс не собирается и не уходит на сервер, тренировки
/// засчитываются как без часов.
class HealthConsent {
  const HealthConsent({this.granted, this.at, this.policyVersion});

  /// null — ещё не спрашивали.
  final bool? granted;
  final DateTime? at;
  final String? policyVersion;

  bool get allowsPulse => granted == true;
  bool get asked => granted != null;

  Map<String, dynamic> toJson() => {
    'granted': granted,
    'at': at?.toIso8601String(),
    'policyVersion': policyVersion,
  };

  factory HealthConsent.fromJson(Map<String, dynamic> j) => HealthConsent(
    granted: j['granted'] as bool?,
    at: j['at'] == null ? null : DateTime.parse(j['at'] as String),
    policyVersion: j['policyVersion'] as String?,
  );
}

class HealthConsentNotifier extends Notifier<HealthConsent> {
  @override
  HealthConsent build() {
    final raw = ref.read(prefsProvider).getString(_consentKey);
    if (raw == null) return const HealthConsent();
    try {
      return HealthConsent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const HealthConsent();
    }
  }

  /// Дать или отозвать согласие. С аккаунтом — сразу сообщаем серверу:
  /// без согласия он не принимает пульс.
  Future<void> set(bool granted) async {
    state = HealthConsent(
      granted: granted,
      at: DateTime.now(),
      policyVersion: privacyPolicyUpdated,
    );
    await ref
        .read(prefsProvider)
        .setString(_consentKey, jsonEncode(state.toJson()));
    await pushToServer();
  }

  /// Отправить согласие на сервер (после входа или изменения). Нет сети — не страшно:
  /// повторим при следующем входе или изменении, а без согласия на сервере пульс просто не учтётся.
  Future<void> pushToServer() async {
    if (!state.asked || !ref.read(accountProvider).signedIn) return;
    try {
      await ref.read(apiProvider).put('/v1/me/consent', {
        'health': state.allowsPulse,
        'policyVersion': state.policyVersion ?? privacyPolicyUpdated,
      });
    } on ApiException {
      // Старый сервер без этого метода или нет связи.
    }
  }
}

final healthConsentProvider =
    NotifierProvider<HealthConsentNotifier, HealthConsent>(
      HealthConsentNotifier.new,
    );
