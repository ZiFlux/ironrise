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

/// Игровые ники ботов: латиницей (п. 46) и русские с каламбурами (п. 74). Совпадает с server/src/game/duel-flavor.ts.
const botHandlesMale = <String>[
  'xX_IronWolf_Xx',
  'BenchGod',
  'PumpKing99',
  'Gym_Rat_007',
  'NoDaysOff',
  'BeastMode_ON',
  'Lift4Life',
  'DeadliftDan',
  'ProteinShake',
  'Swole_Patrol',
  'Max_Rep',
  'IronMike_RU',
  'Rack_Attack',
  'Dumbb3ll',
  'Vova_Pump',
  'Big_Biceps',
  'Squat_Lord',
  'Kettle_Bear',
  'Grind_Time',
  'Spotter_42',
  // Русские ники с каламбурами про качалку (п. 74 бэклога).
  'Дядя_Жим',
  'Креатинович',
  'Протеин_Батоныч',
  'Бицепс_Бицепсович',
  'Гриф_Грифыч',
  'Сгущёнка_на_массу',
  'Масса_Петрович',
  'Становой_Вася',
  'Пампинг_Паша',
  'Блинчик_20кг',
  'Шейкер_Шейкерыч',
  'Жим_до_пенсии',
  'Ноги_с_понедельника',
  'Кардио_не_моё',
  'Трапеция_Плюс',
  'Скамейкин',
  'Гантель_Иваныч',
  'Отказ_Отказович',
  'Качок_с_района',
  'Сушка_навсегда',
];
const botHandlesFemale = <String>[
  'SquatQueen',
  'Glute_Goddess',
  'Fit_Lisa',
  'Iron_Mary',
  'PlankPrincess',
  'Cardio_Kat',
  'Lunge_Lady',
  'Strong_Ann',
  'Booty_Builder',
  'Pilates_Pro',
  'Yoga_Rage',
  'Kettle_Kira',
  'Run_Yana',
  'Power_Vika',
  'Muscle_Masha',
  'Fit_Freak_x',
  'Lift_Lena',
  'Stretch_Sveta',
  'Hip_Thrust_Hero',
  'Sweaty_Sonya',
  'Фитоняша_Катя',
  'Приседашка',
  'Растяжкина',
  'Кардио_Королева',
  'Скакалка_Света',
  'Планка_Петровна',
  'Резинка_и_Ягодицы',
  'Мисс_Выпад',
  'Гантелька_Маша',
  'Смузи_и_Становая',
  'Леди_Бёрпи',
  'Марафонша_Юля',
  'Ягодичный_Мостик',
  'Шпагат_к_лету',
  'Белок_и_Блёстки',
];

/// Разные ники ботов; занятый — с номером, как в играх (BenchGod_27).
List<String> botNames(List<bool> female, Random rng) {
  final used = <String>{};
  return [
    for (final f in female)
      () {
        final pool = f ? botHandlesFemale : botHandlesMale;
        for (var attempt = 0; ; attempt++) {
          final base = pool[rng.nextInt(pool.length)];
          final name = attempt < 10 ? base : '${base}_${10 + rng.nextInt(90)}';
          if (used.add(name)) return name;
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
