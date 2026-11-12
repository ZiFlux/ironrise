import 'dart:math';

import '../avatar/avatar_look.dart';
import 'shop.dart';

/// Колорит дуэлей: случайные события со спортзальным юмором и имена ботов.
/// Id и виды событий совпадают с server/src/game/duel-flavor.ts — сервер шлёт
/// только id, тексты здесь. Офлайн-бой (без аккаунта) использует тот же каталог.

enum DuelEventKind {
  /// Восстановил здоровье.
  heal,

  /// Этот удар ×1,5.
  boost,

  /// Пропустил ход.
  skip,
}

class DuelEventDef {
  const DuelEventDef(this.id, this.kind, this.weight, this._phrase);

  final String id;
  final DuelEventKind kind;
  final int weight;
  final String Function(String name, bool female) _phrase;

  /// «Стас принял креатин», «Света приняла креатин».
  String phrase(String name, {required bool female}) => _phrase(name, female);
}

String _g(bool female, String male, String fem) => female ? fem : male;

final duelEvents = <DuelEventDef>[
  DuelEventDef(
    'creatine',
    DuelEventKind.heal,
    3,
    (n, f) => '$n ${_g(f, 'принял', 'приняла')} креатин',
  ),
  DuelEventDef(
    'protein_shake',
    DuelEventKind.heal,
    3,
    (n, f) => '$n ${_g(f, 'выпил', 'выпила')} протеиновый коктейль',
  ),
  DuelEventDef(
    'buckwheat',
    DuelEventKind.heal,
    2,
    (n, f) => '$n ${_g(f, 'съел', 'съела')} гречку с курицей',
  ),
  DuelEventDef(
    'eight_hours_sleep',
    DuelEventKind.heal,
    1,
    (n, f) => '$n ${_g(f, 'вспомнил', 'вспомнила')}, что спит по 8 часов',
  ),
  DuelEventDef(
    'pre_workout',
    DuelEventKind.boost,
    3,
    (n, f) => '$n ${_g(f, 'выпил', 'выпила')} предтрен',
  ),
  DuelEventDef(
    'pump',
    DuelEventKind.boost,
    2,
    (n, f) => '$n ${_g(f, 'поймал', 'поймала')} пампинг',
  ),
  DuelEventDef(
    'gym_playlist',
    DuelEventKind.boost,
    2,
    (n, f) => '$n ${_g(f, 'врубил', 'врубила')} свой плейлист для зала',
  ),
  DuelEventDef(
    'coach_shouts',
    DuelEventKind.boost,
    1,
    (n, f) => 'Тренер орёт «Ещё раз!» — $n в ударе',
  ),
  DuelEventDef(
    'mirror_selfie',
    DuelEventKind.skip,
    2,
    (n, f) => '$n фоткается у зеркала',
  ),
  DuelEventDef(
    'bench_hunt',
    DuelEventKind.skip,
    2,
    (n, f) => '$n ищет свободную скамью',
  ),
  DuelEventDef(
    'forgot_towel',
    DuelEventKind.skip,
    1,
    (n, f) => '$n ${_g(f, 'забыл', 'забыла')} полотенце',
  ),
  DuelEventDef(
    'protein_debate',
    DuelEventKind.skip,
    1,
    (n, f) => '$n спорит в раздевалке, сколько нужно белка',
  ),
];

final _byId = {for (final e in duelEvents) e.id: e};

DuelEventDef? duelEventById(String id) => _byId[id];

DuelEventDef pickDuelEvent(Random rng) {
  final total = duelEvents.fold<int>(0, (s, e) => s + e.weight);
  var x = rng.nextInt(total);
  for (final e in duelEvents) {
    if (x < e.weight) return e;
    x -= e.weight;
  }
  return duelEvents.last;
}

const _maleNames = [
  'Стас',
  'Валера',
  'Богдан',
  'Гена',
  'Толян',
  'Вован',
  'Артур',
  'Лёха',
  'Дэн',
  'Серёга',
  'Михалыч',
  'Жорик',
];
const _femaleNames = [
  'Кристина',
  'Алёна',
  'Света',
  'Даша',
  'Вика',
  'Яна',
  'Марина',
  'Оля',
  'Карина',
  'Лиза',
];

/// Шаблоны прозвищ: (мужской, женский) — прилагательные согласуются с родом.
final _nicknames = <(String Function(String), String Function(String))>[
  ((n) => 'Протеиновый $n', (n) => 'Протеиновая $n'),
  ((n) => 'Железный $n', (n) => 'Железная $n'),
  ((n) => 'Креатиновый $n', (n) => 'Креатиновая $n'),
  ((n) => 'Сухой $n', (n) => 'Сухая $n'),
  ((n) => '$n с турника', (n) => '$n с турника'),
  ((n) => '$n без дня ног', (n) => '$n без дня ног'),
  ((n) => '$n на массе', (n) => '$n на сушке'),
  ((n) => 'Качок $n', (n) => 'Фитоняшка $n'),
  ((n) => 'Тренер $n', (n) => 'Тренер $n'),
  ((n) => '$n из качалки', (n) => '$n из качалки'),
  ((n) => '$n Двести-на-жим', (n) => '$n Сто-на-присед'),
  ((n) => 'Бицепс-$n', (n) => 'Пресс-$n'),
];

/// Разные имена ботов; [female] задаёт род для каждого.
List<String> botNames(List<bool> female, Random rng) {
  final used = <String>{};
  return [
    for (final f in female)
      () {
        for (var attempt = 0; ; attempt++) {
          final pool = f ? _femaleNames : _maleNames;
          final base = pool[rng.nextInt(pool.length)];
          final (m, w) = _nicknames[rng.nextInt(_nicknames.length)];
          final name = (f ? w : m)(base);
          if (used.add(name) || attempt > 20) return name;
        }
      }(),
  ];
}

/// Случайный образ бота — только из вещей магазина, как будто он их купил.
AvatarLook randomBotLook({required bool female, required Random rng}) {
  final sex = female ? AvatarSex.female : AvatarSex.male;
  var look = AvatarLook.starter(sex);
  for (final slot in ShopSlot.values) {
    if (slot == ShopSlot.accessory) continue;
    final items = ShopCatalog.forSlot(slot, sex);
    if (items.isNotEmpty) look = items[rng.nextInt(items.length)].apply(look);
  }
  for (final item in ShopCatalog.forSlot(ShopSlot.accessory, sex)) {
    if (rng.nextDouble() < 0.3) look = item.apply(look);
  }
  return look;
}
