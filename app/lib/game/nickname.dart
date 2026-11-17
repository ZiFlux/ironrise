/// Ники: те же правила, что на сервере (server/src/game/nickname.ts).
library;

import 'banwords_data.dart';

/// Смена ника — раз в 30 дней (первая — сразу); раньше — за монеты.
const nicknameChangeDays = 30;
const nicknameChangeCoins = 300;

final _allowed = RegExp(r'^[\p{L}\d_ ]+$', unicode: true);

/// Пробелы по краям убираются, подряд идущие — сжимаются в один.
String normalizeNickname(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// null — ник подходит; иначе — что не так, для подсказки под полем.
String? nicknameProblem(String raw) {
  final n = normalizeNickname(raw);
  if (n.length < 3) return 'Не короче 3 знаков';
  if (n.length > 20) return 'Не длиннее 20 знаков';
  if (!_allowed.hasMatch(n)) return 'Только буквы, цифры, пробел и _';
  if (isReservedNickname(n)) return 'Этот ник занят проектом';
  if (isOffensiveNickname(n)) return 'Без мата, оскорблений и политики';
  return null;
}

// Латиница и цифры, похожие на кириллицу (после нижнего регистра).
const _lookalikeFrom = 'ёaceopxykmhtb0';
const _lookalikeTo = 'еасеорхукмнтво';

/// Ключ уникальности: регистр, пробелы, «_» и похожие буквы не различаются.
String nicknameKey(String nickname) {
  final out = StringBuffer();
  for (final ch in nickname.toLowerCase().split('')) {
    if (ch == ' ' || ch == '_') continue;
    final i = _lookalikeFrom.indexOf(ch);
    out.write(i >= 0 ? _lookalikeTo[i] : ch);
  }
  return out.toString();
}

final _reserved = [
  'ironrise',
  'айронрайз',
  'admin',
  'админ',
  'administrator',
  'администратор',
  'moderator',
  'модератор',
  'support',
  'поддержка',
  'system',
  'система',
  'official',
  'официальный',
  'разработчик',
  'developer',
].map(nicknameKey).toList();

bool isReservedNickname(String nickname) {
  final key = nicknameKey(nickname);
  return _reserved.any(key.contains);
}

/// Текст ошибки сервера при смене ника или регистрации — по-русски.
String? nicknameServerError(String message) => switch (message) {
  'Nickname is taken' => 'Этот ник уже занят',
  'Nickname is reserved' => 'Этот ник занят проектом',
  'Nickname is not allowed' =>
    'Такой ник нельзя: без мата, оскорблений и политики',
  'Not enough coins' => 'Не хватает монет',
  _ when message.startsWith('Nickname can be changed') =>
    'Ник можно менять раз в $nicknameChangeDays дней',
  _ => null,
};

// ── Фильтр ников: мат, оскорбления, разжигание, политика ──────────────────
// Список — shared/banwords.json; логика — как в server/src/game/nickname.ts.

String _squeeze(String s) =>
    s.replaceAllMapped(RegExp(r'(.)\1+', unicode: true), (m) => m[1]!);

String _mapChars(String s, Map<String, String> table) => s.runes.map((r) {
  final ch = String.fromCharCode(r);
  return table[ch] ?? ch;
}).join();

String _translit(String s) {
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final hit = banTranslitToCyr
        .where((p) => s.startsWith(p.$1, i))
        .firstOrNull;
    if (hit != null) {
      out.write(hit.$2);
      i += hit.$1.length;
    } else {
      out.write(s[i]);
      i += 1;
    }
  }
  return out.toString();
}

String _cutAllowed(String s, List<String> allow) =>
    allow.fold(s, (acc, a) => acc.split(a).join('·'));

({List<String> cyr, String lat}) _formsOf(String word) {
  final base = _squeeze(_mapChars(word.toLowerCase(), banDiacritics));
  final look = _squeeze(_mapChars(base, banLookalikeToCyr));
  final tr = _squeeze(_translit(base));
  final lat = _squeeze(_mapChars(base, banToLatin));
  return (
    cyr: [look, tr].map((f) => _cutAllowed(f, banCyrAllow)).toList(),
    lat: _cutAllowed(lat, banLatinAllow),
  );
}

/// Слова ника: по пробелам, «_» и смене регистра («ПетяСука» → «Петя», «Сука»).
List<String> _nicknameWords(String nickname) => nickname
    .replaceAllMapped(
      RegExp(r'(\p{Ll})(\p{Lu})', unicode: true),
      (m) => '${m[1]} ${m[2]}',
    )
    .split(RegExp(r'[\s_]+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// Мат, оскорбления, разжигание или политика — такой ник нельзя.
bool isOffensiveNickname(String nickname) {
  final words = _nicknameWords(nickname);
  final all = _formsOf(words.join());
  if (all.cyr.any((f) => banCyrAnywhere.any(f.contains))) return true;
  if (banLatinAnywhere.any(all.lat.contains)) return true;
  return words.any((w) {
    final f = _formsOf(w);
    return f.cyr.any(
          (c) => banCyrWords.contains(c) || banCyrWordStart.any(c.startsWith),
        ) ||
        banLatinWords.contains(f.lat) ||
        banLatinWordStart.any(f.lat.startsWith);
  });
}
