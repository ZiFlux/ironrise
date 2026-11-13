/// Ники: те же правила, что на сервере (server/src/game/nickname.ts).
library;

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
  'Not enough coins' => 'Не хватает монет',
  _ when message.startsWith('Nickname can be changed') =>
    'Ник можно менять раз в $nicknameChangeDays дней',
  _ => null,
};
