import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/achievements.dart';
import '../state/providers.dart';
import '../theme.dart';

/// Шаг гайда: на что указать ([target] — id у [GuideTarget]) и что сказать.
class GuideStep {
  const GuideStep(this.target, this.title, this.text);

  final String target;
  final String title;
  final String text;
}

/// Гайды вкладок. Шаг, чей элемент сейчас не на экране (например, без аккаунта),
/// пропускается — гайд показывает только то, что видно.
const tabGuides = <String, List<GuideStep>>{
  'home': [
    GuideStep(
      'home.avatar',
      'Твой герой',
      'Растёт от тренировок: каждая часть тела — от своих упражнений. '
          'Нажми на героя, чтобы открыть инвентарь',
    ),
    GuideStep(
      'home.header',
      'Уровень и монеты',
      'Монеты — за тренировки, серию и победы. Тратятся в магазине на одежду',
    ),
    GuideStep(
      'home.week',
      'Неделя',
      'Кружки — дни по графику: тренировки и отдых. Серия растёт, пока ты не пропускаешь тренировки',
    ),
    GuideStep(
      'home.plan',
      'Тренировка на сегодня',
      'План под твой уровень: упражнения, подходы и веса. Одна силовая и одно кардио в день',
    ),
  ],
  'workout': [
    GuideStep(
      'workout.plan',
      'План',
      'Упражнения и подходы на сегодня. Нажми на упражнение — техника и мышцы',
    ),
    GuideStep(
      'workout.start',
      'Начать',
      'Запускает тренировку: записывай подходы, пульс с часов подтвердит их',
    ),
    GuideStep(
      'workout.stats',
      'Статистика',
      'Прогресс, нагрузка на мышцы за неделю, прогноз и вес с составом тела',
    ),
  ],
  'duels': [
    GuideStep(
      'duels.list',
      'Соперники дня',
      'Многое решает сила героя, а в лестнице — ещё и твой выбор действий. Тренируй отстающие части — побеждать станет проще',
    ),
    GuideStep(
      'duels.friends',
      'Друзья',
      'Добавь друзей — бросай им вызов и смотри их прогресс',
    ),
    GuideStep(
      'gate.register',
      'Нужен аккаунт',
      'Дуэли и рейтинг считает сервер — зарегистрируйся, это минута',
    ),
  ],
  'rating': [
    GuideStep(
      'rating.league',
      'Лига недели',
      'Очки за тренировки и победы, а не за силу. Лучшие поднимаются в лигу выше',
    ),
    GuideStep(
      'gate.register',
      'Нужен аккаунт',
      'Лиги с живыми игроками — после регистрации',
    ),
  ],
  'profile': [
    GuideStep(
      'profile.showcase',
      'Настроить витрину',
      'Поза героя, аватарка и что показывать друзьям',
    ),
    GuideStep(
      'profile.settings',
      'Настройки',
      'График, уровень, напоминания, календарь и конфиденциальность',
    ),
  ],
};

String _doneKey(String tab) => 'guide_done_$tab';
String _completedKey(String tab) => 'guide_completed_$tab';

/// Элементы, на которые может указать гайд.
final _targets = <String, GlobalKey>{};

/// Отметка элемента для гайда.
class GuideTarget extends StatefulWidget {
  const GuideTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<GuideTarget> createState() => _GuideTargetState();
}

class _GuideTargetState extends State<GuideTarget> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _targets[widget.id] = _key;
  }

  @override
  void dispose() {
    if (_targets[widget.id] == _key) _targets.remove(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

/// Гайд вкладки: при первом заходе по шагам подсвечивает элементы. За все
/// пройденные вкладки — кроссовки «Первый шаг».
class TabGuide extends ConsumerStatefulWidget {
  const TabGuide({super.key, required this.tab, required this.child});

  final String tab;
  final Widget child;

  /// Пройти гайды заново (настройки → «Показать подсказки снова»).
  static Future<void> resetAll(WidgetRef ref) async {
    final prefs = ref.read(prefsProvider);
    for (final tab in tabGuides.keys) {
      await prefs.remove(_doneKey(tab));
    }
  }

  @override
  ConsumerState<TabGuide> createState() => _TabGuideState();
}

class _TabGuideState extends ConsumerState<TabGuide> {
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    // Ждём, пока экран появится (анимации входа), потом смотрим, что видно.
    Future.delayed(const Duration(milliseconds: 700), _maybeStart);
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  void _maybeStart() {
    if (!mounted || _entry != null) return;
    final prefs = ref.read(prefsProvider);
    if (prefs.getBool(_doneKey(widget.tab)) == true) return;
    final steps = [
      for (final s in tabGuides[widget.tab] ?? const <GuideStep>[])
        if (_rectOf(s.target) != null) s,
    ];
    if (steps.isEmpty) return;
    _entry = OverlayEntry(
      builder: (_) => _GuideOverlay(steps: steps, onDone: _finish),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  Future<void> _finish(bool completed) async {
    _entry?.remove();
    _entry = null;
    // Всё нужное из ref — до await: подсказку закрывают и уходя с вкладки (п. 137).
    final prefs = ref.read(prefsProvider);
    final achievements = ref.read(achievementsProvider.notifier);
    await prefs.setBool(_doneKey(widget.tab), true);
    if (completed) await prefs.setBool(_completedKey(widget.tab), true);
    final all = tabGuides.keys.every(
      (t) => prefs.getBool(_completedKey(t)) == true,
    );
    if (all) await achievements.claim(Achievement.guide);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Где элемент на экране; null — его нет или он за краем.
Rect? _rectOf(String id) {
  final box = _targets[id]?.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  final screen =
      PlatformDispatcher.instance.views.first.physicalSize /
      PlatformDispatcher.instance.views.first.devicePixelRatio;
  if (rect.isEmpty || rect.bottom <= 0 || rect.top >= screen.height) {
    return null;
  }
  return rect;
}

class _GuideOverlay extends StatefulWidget {
  const _GuideOverlay({required this.steps, required this.onDone});

  final List<GuideStep> steps;
  final void Function(bool completed) onDone;

  @override
  State<_GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<_GuideOverlay> {
  int _index = 0;

  void _next() {
    if (_index + 1 >= widget.steps.length) {
      widget.onDone(true);
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final size = MediaQuery.sizeOf(context);
    final target = _rectOf(step.target);
    // Элемент пропал (экран перестроился) — без окна, карточка по центру.
    final hole =
        target?.inflate(6) ??
        Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);
    final below = hole.center.dy < size.height / 2;
    final accent = Theme.of(context).colorScheme.primary;
    final last = _index + 1 == widget.steps.length;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Во время гайда экран не нажимается — ни размытая часть, ни окно:
          // листают только кнопки карточки, и гайд не сломать случайным тапом.
          const Positioned.fill(child: AbsorbPointer(child: SizedBox.expand())),
          // Всё, кроме окна, — затемнено и размыто.
          Positioned.fill(
            child: IgnorePointer(
              child: ClipPath(
                clipper: _HoleClipper(
                  RRect.fromRectAndRadius(hole, const Radius.circular(14)),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.6)),
                ),
              ),
            ),
          ),
          if (target != null)
            Positioned.fromRect(
              rect: hole,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent, width: 2),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            top: below ? hole.bottom + 6 : null,
            bottom: below ? null : size.height - hole.top + 6,
            child: _Bubble(
              arrowX: (hole.center.dx - 16).clamp(20.0, size.width - 52),
              arrowUp: below,
              title: step.title,
              text: step.text,
              counter: '${_index + 1}/${widget.steps.length}',
              actionLabel: last ? 'Понятно' : 'Далее',
              onNext: _next,
              onSkip: () => widget.onDone(false),
            ),
          ),
        ],
      ),
    );
  }
}

/// Вся область, кроме скруглённого окна.
class _HoleClipper extends CustomClipper<Path> {
  const _HoleClipper(this.hole);

  final RRect hole;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(hole);

  @override
  bool shouldReclip(_HoleClipper old) => old.hole != hole;
}

/// Карточка подсказки со стрелкой к элементу.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.arrowX,
    required this.arrowUp,
    required this.title,
    required this.text,
    required this.counter,
    required this.actionLabel,
    required this.onNext,
    required this.onSkip,
  });

  final double arrowX;
  final bool arrowUp;
  final String title;
  final String text;
  final String counter;
  final String actionLabel;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final arrow = Padding(
      padding: EdgeInsets.only(left: arrowX),
      child: CustomPaint(
        size: const Size(16, 9),
        painter: _ArrowPainter(up: arrowUp),
      ),
    );
    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Крупный шрифт или узкий экран — кнопки переносятся, а не вылезают.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(onPressed: onSkip, child: const Text('Пропустить')),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    counter,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: onNext, child: Text(actionLabel)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: arrowUp ? [arrow, card] : [card, arrow],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.up});

  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final path = up
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(path..close(), Paint()..color = AppColors.raised);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.up != up;
}
