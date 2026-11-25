import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/body_frame.dart';
import '../net/api_client.dart';
import '../widgets/status_toast.dart';
import 'account_state.dart';
import 'providers.dart';

const _showcaseKey = 'showcase_v1';

/// Витрина профиля: аватарка, её фон и поза героя (null — сам меняет позы).
class Showcase {
  const Showcase({this.icon = 'cat', this.background = 0, this.pose});

  final String icon;
  final int background;
  final AvatarPose? pose;

  Showcase copyWith({
    String? icon,
    int? background,
    AvatarPose? pose,
    bool autoPose = false,
  }) => Showcase(
    icon: icon ?? this.icon,
    background: background ?? this.background,
    pose: autoPose ? null : pose ?? this.pose,
  );

  Map<String, dynamic> toJson() => {
    'icon': icon,
    'background': background,
    'pose': pose?.name,
  };

  factory Showcase.fromJson(Map<String, dynamic> j) => Showcase(
    icon: j['icon'] as String? ?? 'cat',
    background: (j['background'] as num?)?.toInt() ?? 0,
    pose: AvatarPose.values.asNameMap()[j['pose']],
  );
}

class ShowcaseNotifier extends Notifier<Showcase> {
  @override
  Showcase build() {
    final raw = ref.read(prefsProvider).getString(_showcaseKey);
    if (raw == null) return const Showcase();
    try {
      return Showcase.fromJson(jsonDecode(raw));
    } catch (_) {
      return const Showcase();
    }
  }

  /// Сохранить на телефоне и (с аккаунтом) на сервере — чтобы витрину видели друзья.
  Future<void> save(Showcase showcase) async {
    state = showcase;
    await ref
        .read(prefsProvider)
        .setString(_showcaseKey, jsonEncode(showcase.toJson()));
    if (!ref.read(accountProvider).signedIn) return;
    try {
      // Без сети — в очередь, уйдёт при синхронизации (п. 114).
      await ref
          .read(accountProvider.notifier)
          .sendOrQueue(
            'PUT',
            '/v1/me/showcase',
            showcase.toJson(),
            key: 'showcase',
          );
    } on ApiException catch (e) {
      // Сервер проверяет достижения сам (п. 84): если тренировки ещё не дошли до
      // сервера, аватарка-достижение откроется после синхронизации.
      if (e.status == 403) {
        showStatus(
          'Сервер ещё не засчитал это достижение — витрина обновится после синхронизации',
          kind: StatusKind.info,
        );
      }
      // Без сети или старый сервер — витрина останется на телефоне.
    }
  }

  /// С сервера (другой телефон) — без обратной отправки.
  Future<void> applyServer(Map<String, dynamic>? j) async {
    if (j == null) return;
    state = Showcase.fromJson(j);
    await ref
        .read(prefsProvider)
        .setString(_showcaseKey, jsonEncode(state.toJson()));
  }
}

final showcaseProvider = NotifierProvider<ShowcaseNotifier, Showcase>(
  ShowcaseNotifier.new,
);
