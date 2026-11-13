import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';
import 'providers.dart';

const _accentKey = 'accent_v1';

class AccentNotifier extends Notifier<AccentOption> {
  @override
  AccentOption build() {
    final saved = ref.read(prefsProvider).getString(_accentKey);
    return AccentOption.values.asNameMap()[saved] ?? AccentOption.lime;
  }

  Future<void> select(AccentOption option) async {
    state = option;
    await ref.read(prefsProvider).setString(_accentKey, option.name);
  }
}

final accentProvider = NotifierProvider<AccentNotifier, AccentOption>(
  AccentNotifier.new,
);
