import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

const _favoritesKey = 'favorite_exercises_v1';

/// Избранные упражнения: наверху списка и в отдельном фильтре, чтобы не искать.
class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {
    ...?ref.read(prefsProvider).getStringList(_favoritesKey),
  };

  Future<void> toggle(String exerciseId) async {
    state = state.contains(exerciseId)
        ? ({...state}..remove(exerciseId))
        : {...state, exerciseId};
    await ref
        .read(prefsProvider)
        .setStringList(_favoritesKey, state.toList()..sort());
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);
