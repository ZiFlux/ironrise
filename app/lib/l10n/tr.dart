import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'en.dart';

/// Языки интерфейса. Исходный текст — русский: он же ключ перевода.
enum AppLanguage {
  ru('Русский'),
  en('English');

  const AppLanguage(this.label);

  /// Название языка на нём самом — так его ищут в списке.
  final String label;

  Locale get locale => Locale(name);
}

/// Языки, для которых по умолчанию берём русский: близкие и где его знают.
const _russianFirst = {'ru', 'uk', 'be', 'kk', 'ky', 'uz', 'tg', 'hy', 'az'};

/// Язык системы → язык приложения.
AppLanguage languageForSystem(String code) =>
    _russianFirst.contains(code) ? AppLanguage.ru : AppLanguage.en;

/// Текущий язык для [tr]. Меняется только через [languageProvider].
AppLanguage _current = AppLanguage.ru;

AppLanguage get currentLanguage => _current;

/// Перевести русский текст. Подстановки — `{имя}`:
/// `tr('Осталось {n} дн.', {'n': 3})`. Перевода нет — остаётся русский,
/// чтобы недопереведённый экран не ломался.
String tr(String ru, [Map<String, Object?> args = const {}]) {
  var text = switch (_current) {
    AppLanguage.ru => ru,
    AppLanguage.en => en[ru] ?? ru,
  };
  args.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
  return text;
}

/// Число с правильной формой слова: `trPlural(n, 'день', 'дня', 'дней', 'day', 'days')`.
String trPlural(
  int n,
  String one,
  String few,
  String many,
  String enOne,
  String enMany,
) {
  if (_current == AppLanguage.en) return '$n ${n == 1 ? enOne : enMany}';
  final m10 = n % 10, m100 = n % 100;
  final word = m10 == 1 && m100 != 11
      ? one
      : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)
      ? few
      : many;
  return '$n $word';
}

const _languageKey = 'language';

/// Выбор языка: null — как в системе.
class LanguageNotifier extends Notifier<AppLanguage?> {
  @override
  AppLanguage? build() {
    final saved = ref.read(prefsProvider).getString(_languageKey);
    final chosen = AppLanguage.values.where((l) => l.name == saved).firstOrNull;
    _current = chosen ?? systemLanguage();
    return chosen;
  }

  Future<void> select(AppLanguage? language) async {
    final prefs = ref.read(prefsProvider);
    language == null
        ? await prefs.remove(_languageKey)
        : await prefs.setString(_languageKey, language.name);
    _current = language ?? systemLanguage();
    state = language;
  }
}

AppLanguage systemLanguage() => languageForSystem(
  WidgetsBinding.instance.platformDispatcher.locale.languageCode,
);

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage?>(
  LanguageNotifier.new,
);

/// Действующий язык (выбранный или системный) — от него перестраивается приложение.
final effectiveLanguageProvider = Provider<AppLanguage>(
  (ref) => ref.watch(languageProvider) ?? systemLanguage(),
);
