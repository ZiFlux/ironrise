import 'dart:math';

import 'package:flutter/material.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../widgets/logo_mark.dart';
import 'body_part.dart';

/// Аватарка профиля (REDESIGN, этап 1): портрет своего героя — голова и плечи —
/// в рамке. Рамки открываются достижениями; id достижений те же, что раньше у
/// аватарок-смайликов, поэтому проверка на сервере (server/src/game/showcase.ts)
/// не меняется. Без фото — никаких персональных данных на сервере.

/// За что открывается рамка-достижение.
enum AchievementKind { heroLevel, streak, workouts }

/// Как выглядит рамка.
enum FrameStyle { seal, ring, bronze, flame, steel, dragon, gold, crown }

class AvatarIcon {
  const AvatarIcon(this.id, this.label, this.style, {this.unlock});

  final String id;
  final String label;
  final FrameStyle style;

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
  AvatarIcon('hero', 'Печать', FrameStyle.seal),
  AvatarIcon('round', 'Круг', FrameStyle.ring),
  // Рамки за достижения (id совпадают с сервером).
  AvatarIcon(
    'medal',
    'Бронза',
    FrameStyle.bronze,
    unlock: (AchievementKind.streak, 7),
  ),
  AvatarIcon(
    'volcano',
    'Пламя',
    FrameStyle.flame,
    unlock: (AchievementKind.streak, 30),
  ),
  AvatarIcon(
    'rocket',
    'Сталь',
    FrameStyle.steel,
    unlock: (AchievementKind.workouts, 50),
  ),
  AvatarIcon(
    'dragon',
    'Дракон',
    FrameStyle.dragon,
    unlock: (AchievementKind.workouts, 100),
  ),
  AvatarIcon(
    'trophy',
    'Золото',
    FrameStyle.gold,
    unlock: (AchievementKind.heroLevel, 10),
  ),
  AvatarIcon(
    'crown',
    'Корона',
    FrameStyle.crown,
    unlock: (AchievementKind.heroLevel, 20),
  ),
];

/// Фоны за портретом — тёмные, тёплые, в палитре приложения.
const avatarBackgrounds = <Color>[
  Color(0xFF2A2025),
  Color(0xFF2B2338),
  Color(0xFF1E3330),
  Color(0xFF3A2422),
  Color(0xFF22303A),
  Color(0xFF3A3222),
];

/// Неизвестный id (прежние смайлики, вещи из новой версии) — «Печать».
AvatarIcon avatarIconById(String? id) =>
    avatarIcons.where((i) => i.id == id).firstOrNull ?? avatarIcons.first;

/// Аватарка: портрет героя ([look] и [levels]) в рамке, а где облика нет
/// (лента, напарник) — первая буква ника ([name]) в той же рамке.
class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    super.key,
    required this.iconId,
    required this.background,
    this.size = 56,
    this.look,
    this.levels,
    this.name,
  });

  final String? iconId;
  final int background;
  final double size;
  final AvatarLook? look;
  final Map<BodyPart, num>? levels;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final icon = avatarIconById(iconId);
    final bg = avatarBackgrounds[background % avatarBackgrounds.length];
    final accent = Theme.of(context).colorScheme.primary;
    final inner = size * 0.84;
    final look = this.look;
    Widget face;
    if (look != null) {
      // Голова и плечи: холст аватара 200×400, показываем верх 120×120 по центру.
      final scale = inner / 120;
      face = ClipOval(
        child: SizedBox.square(
          dimension: inner,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -40 * scale,
                top: -2 * scale,
                width: 200 * scale,
                height: 400 * scale,
                child: AvatarView(
                  levels: levels ?? {for (final p in BodyPart.values) p: 5},
                  look: look,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final letter = (name ?? '').trim().isEmpty
          ? '?'
          : name!.trim().characters.first.toUpperCase();
      face = SizedBox.square(
        dimension: inner,
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: 'RussoOne',
              fontSize: inner * 0.42,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: 'Аватарка, рамка «${icon.label}»',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color.lerp(bg, Colors.white, 0.12)!, bg],
                  center: const Alignment(0, -0.5),
                ),
              ),
            ),
            face,
            Positioned.fill(
              child: CustomPaint(
                painter: _FramePainter(style: icon.style, accent: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.style, required this.accent});

  final FrameStyle style;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final w = size.width * 0.07;
    Paint ring(List<Color> colors) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..shader = SweepGradient(colors: [...colors, colors.first])
          .createShader(Rect.fromCircle(center: c, radius: r));
    final rr = r - w / 2;
    switch (style) {
      case FrameStyle.seal:
        // Шестигранник знака IronRise цветом стиля.
        final u = size.width / 64;
        canvas.drawPath(
          LogoPainter.hexagon(u),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.8
            ..strokeJoin = StrokeJoin.round
            ..color = accent,
        );
      case FrameStyle.ring:
        canvas.drawCircle(
          c,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.6
            ..color = Colors.white.withValues(alpha: 0.18),
        );
      case FrameStyle.bronze:
        canvas.drawCircle(
          c,
          rr,
          ring(const [Color(0xFFB8733A), Color(0xFFF0B27A), Color(0xFF8A5226)]),
        );
      case FrameStyle.flame:
        canvas.drawCircle(
          c,
          rr,
          ring(const [Color(0xFFFF5A1F), Color(0xFFFFC23D), Color(0xFFE5484D)]),
        );
        // Языки пламени снаружи по кругу.
        final flame = Paint()..color = const Color(0xFFFF8A3D);
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4 - pi / 2;
          final base = c + Offset(cos(a), sin(a)) * r;
          final tip = c + Offset(cos(a), sin(a)) * (r + size.width * 0.07);
          final n = Offset(-sin(a), cos(a)) * size.width * 0.035;
          canvas.drawPath(
            Path()
              ..moveTo(base.dx + n.dx, base.dy + n.dy)
              ..lineTo(tip.dx, tip.dy)
              ..lineTo(base.dx - n.dx, base.dy - n.dy)
              ..close(),
            flame,
          );
        }
      case FrameStyle.steel:
        canvas.drawCircle(
          c,
          rr,
          ring(const [Color(0xFF8FA6BC), Color(0xFFE6EDF3), Color(0xFF5B6B7A)]),
        );
        canvas.drawCircle(
          c,
          rr - w * 1.1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFFB8C4D0),
        );
      case FrameStyle.dragon:
        canvas.drawCircle(
          c,
          rr,
          ring(const [Color(0xFF1E8A6E), Color(0xFFD9B25A), Color(0xFF0F5C4A)]),
        );
        // Шипы-чешуйки.
        final spike = Paint()..color = const Color(0xFFD9B25A);
        for (var i = 0; i < 12; i++) {
          final a = i * pi / 6;
          final base = c + Offset(cos(a), sin(a)) * r;
          final tip = c + Offset(cos(a), sin(a)) * (r + size.width * 0.05);
          final n = Offset(-sin(a), cos(a)) * size.width * 0.025;
          canvas.drawPath(
            Path()
              ..moveTo(base.dx + n.dx, base.dy + n.dy)
              ..lineTo(tip.dx, tip.dy)
              ..lineTo(base.dx - n.dx, base.dy - n.dy)
              ..close(),
            spike,
          );
        }
      case FrameStyle.gold:
        canvas.drawCircle(
          c,
          rr,
          ring(const [Color(0xFFD9B25A), Color(0xFFFFF0B8), Color(0xFFA67C2E)]),
        );
      case FrameStyle.crown:
        canvas.drawCircle(
          c,
          rr,
          ring(const [Color(0xFFD9B25A), Color(0xFFFFF0B8), Color(0xFFA67C2E)]),
        );
        // Маленькая корона сверху.
        final cw = size.width * 0.34;
        final ch = size.width * 0.16;
        final top = c.dy - r - ch * 0.45;
        final crown = Path()
          ..moveTo(c.dx - cw / 2, top + ch)
          ..lineTo(c.dx - cw / 2, top + ch * 0.3)
          ..lineTo(c.dx - cw / 4, top + ch * 0.6)
          ..lineTo(c.dx, top)
          ..lineTo(c.dx + cw / 4, top + ch * 0.6)
          ..lineTo(c.dx + cw / 2, top + ch * 0.3)
          ..lineTo(c.dx + cw / 2, top + ch)
          ..close();
        canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD166));
        canvas.drawPath(
          crown,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFFA67C2E),
        );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.style != style || old.accent != accent;
}
