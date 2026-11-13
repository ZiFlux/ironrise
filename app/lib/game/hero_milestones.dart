import 'body_part.dart';
import 'progression.dart';

/// Вехи героя (PLAN 4.8, п. 9): средний уровень 5, 10, 20 — вещь в подарок,
/// с 5-го открывается поза победы, с 10-го и 20-го — аватарки.
/// Совпадает с server/src/game/social-progress.ts.
class HeroMilestone {
  const HeroMilestone(this.level, this.item, this.perk);

  final int level;

  /// Вещь из ShopCatalog в подарок.
  final String item;

  /// Что ещё открывается — для подписи.
  final String perk;
}

const heroMilestones = <HeroMilestone>[
  HeroMilestone(5, 'acc_headband', 'поза победы'),
  HeroMilestone(10, 'acc_wristbands', 'аватарка «Кубок»'),
  HeroMilestone(20, 'acc_belt', 'аватарка «Корона»'),
];

/// Уровень героя — средний по частям тела, вниз.
int heroLevel(Map<BodyPart, num> levels) => Progression.averageLevel({
  for (final e in levels.entries) e.key: e.value.toInt(),
}).floor();

/// Вехи, пройденные при росте уровня с [before] до [after].
List<HeroMilestone> heroMilestonesBetween(int before, int after) => [
  for (final m in heroMilestones)
    if (m.level > before && m.level <= after) m,
];

/// С какого уровня героя открыта поза победы.
const victoryPoseLevel = 5;
