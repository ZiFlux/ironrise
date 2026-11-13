import 'package:flutter/material.dart';

/// Готовые аватарки профиля: котики и шуточные. Эмодзи на цветном фоне —
/// без загрузки фото, поэтому никаких персональных данных на сервере.
/// За что открывается аватарка-достижение.
enum AchievementKind { heroLevel, streak, workouts }

class AvatarIcon {
  const AvatarIcon(this.id, this.emoji, this.label, {this.unlock});

  final String id;
  final String emoji;
  final String label;

  /// null — доступна сразу; иначе — достижение и порог.
  final (AchievementKind, int)? unlock;

  /// Что нужно сделать: «уровень героя 10», «серия 7 дней», «50 тренировок».
  String? get unlockText => switch (unlock) {
    null => null,
    (AchievementKind.heroLevel, final n) => 'уровень героя $n',
    (AchievementKind.streak, final n) => 'серия $n дней',
    (AchievementKind.workouts, final n) => '$n тренировок',
  };

  bool unlockedFor({
    required int heroLevel,
    required int streak,
    required int workouts,
  }) => switch (unlock) {
    null => true,
    (AchievementKind.heroLevel, final n) => heroLevel >= n,
    (AchievementKind.streak, final n) => streak >= n,
    (AchievementKind.workouts, final n) => workouts >= n,
  };
}

const avatarIcons = <AvatarIcon>[
  AvatarIcon('cat', '😺', 'Котик'),
  AvatarIcon('cat_smirk', '😼', 'Котик-качок'),
  AvatarIcon('cat_scream', '🙀', 'Котик на ногах'),
  AvatarIcon('cat_love', '😻', 'Котик после пампа'),
  AvatarIcon('lion', '🦁', 'Лев'),
  AvatarIcon('tiger', '🐯', 'Тигр'),
  AvatarIcon('bear', '🐻', 'Медведь'),
  AvatarIcon('gorilla', '🦍', 'Горилла'),
  AvatarIcon('chicken', '🐔', 'Курица (без ног)'),
  AvatarIcon('trex', '🦖', 'Т-рекс (без рук)'),
  AvatarIcon('frog', '🐸', 'Лягушка'),
  AvatarIcon('panda', '🐼', 'Панда'),
  AvatarIcon('moai', '🗿', 'Каменная грудь'),
  AvatarIcon('robot', '🤖', 'Робот'),
  AvatarIcon('muscle', '💪', 'Бицепс'),
  AvatarIcon('fire', '🔥', 'Огонь'),
  AvatarIcon('broccoli', '🥦', 'Брокколи'),
  AvatarIcon('drumstick', '🍗', 'Курогрудь'),
  AvatarIcon('egg', '🥚', 'Яйцо (белок)'),
  AvatarIcon('lightning', '⚡', 'Молния'),
  // Аватарки за достижения.
  AvatarIcon('medal', '🥇', 'Медаль', unlock: (AchievementKind.streak, 7)),
  AvatarIcon('volcano', '🌋', 'Вулкан', unlock: (AchievementKind.streak, 30)),
  AvatarIcon('rocket', '🚀', 'Ракета', unlock: (AchievementKind.workouts, 50)),
  AvatarIcon('dragon', '🐉', 'Дракон', unlock: (AchievementKind.workouts, 100)),
  AvatarIcon('trophy', '🏆', 'Кубок', unlock: (AchievementKind.heroLevel, 10)),
  AvatarIcon('crown', '👑', 'Корона', unlock: (AchievementKind.heroLevel, 20)),
];

/// Фоны аватарки.
const avatarBackgrounds = <Color>[
  Color(0xFF2B2F3A),
  Color(0xFF3A2B4A),
  Color(0xFF1E3A34),
  Color(0xFF4A2B2B),
  Color(0xFF2B3E4A),
  Color(0xFF4A402B),
];

AvatarIcon avatarIconById(String? id) =>
    avatarIcons.where((i) => i.id == id).firstOrNull ?? avatarIcons.first;

/// Круглая аватарка: эмодзи на фоне.
class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    super.key,
    required this.iconId,
    required this.background,
    this.size = 56,
  });

  final String? iconId;
  final int background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = avatarIconById(iconId);
    final bg = avatarBackgrounds[background % avatarBackgrounds.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color.lerp(bg, Colors.white, 0.18)!, bg],
          center: const Alignment(-0.3, -0.4),
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        icon.emoji,
        style: TextStyle(fontSize: size * 0.5, height: 1),
        semanticsLabel: icon.label,
      ),
    );
  }
}
