import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/providers.dart';
import '../theme.dart';

/// Подсказки при первом заходе на экран: всплывают карточкой поверх низа экрана,
/// вёрстку не сдвигают, закрываются «Понятно» и больше не показываются.
/// Вернуть все — в настройках («Показать подсказки снова»).
const screenHints = <String, (IconData, String)>{
  'home': (
    LucideIcons.hand,
    'Нажми на героя — откроется инвентарь. Монеты и кнопка «Магазин» ведут в магазин, '
        'кружки недели — твои тренировки и дни отдыха',
  ),
  'workout': (
    LucideIcons.dumbbell,
    'Начни тренировку по плану — или «Без плана». Пульс с часов подтверждает подходы '
        'и даёт полный опыт. С друзьями рядом — «Тренировка вместе», +25%',
  ),
  'duels': (
    LucideIcons.swords,
    'Каждый день — новые соперники. Здоровье в бою равно силе героя, а в лестнице ты ещё '
        'и выбираешь действия на каждый раунд. Сила растёт только от тренировок — подтягивай '
        'отстающие части. В бою бывают события: креатин, предтрен, селфи у зеркала',
  ),
  'rating': (
    LucideIcons.trophy,
    'Лига — за активность, а не за силу: тренировки и победы за неделю. '
        'Лучшие поднимаются в лигу выше в понедельник',
  ),
  'profile': (
    LucideIcons.user,
    'Здесь всё о тебе: аккаунт, часы, друзья, магазин и инвентарь. Шестерёнка — настройки',
  ),
  // Первая встреча с механикой (п. 127, пункт 31): один раз, потом только по сбросу.
  'result': (
    LucideIcons.sparkles,
    'Опыт идёт в те части тела, что работали. Отстающая получает ×1,5, а пульс '
        'с часов делает опыт полным. Нажимай на строки — там подробности',
  ),
  'battle': (
    LucideIcons.swords,
    'Бой идёт сам: здоровье равно силе, чаще бьёт сильнейшая часть тела. '
        '«Пропустить» — сразу к итогу и разбору, что подтянуть',
  ),
  'auras': (
    LucideIcons.wandSparkles,
    'Аура — особый навык в дуэли. Надень одну и качай её отдельными короткими '
        'тренировками: на силу героя она не влияет, только на бой',
  ),
  'season': (
    LucideIcons.trophy,
    'Сезон длится несколько недель. Очки за любую активность открывают уровни '
        'и награды — они выдаются сами, ничего забирать не нужно',
  ),
  'friends': (
    LucideIcons.userPlus,
    'Найди друга по нику. С другом — дуэль раз в день, общая лига недели '
        'и «Тренировка вместе» с бонусом к опыту',
  ),
  'joint': (
    LucideIcons.users,
    'Начни сам или присоединись к другу: пока вы тренируетесь в одно время, '
        'опыт у обоих больше',
  ),
  'shop': (
    LucideIcons.shoppingBag,
    'Нажимай на вещи — они сразу примеряются на героя. Купить можно за монеты '
        'с тренировок; на силу одежда не влияет',
  ),
};

String _key(String id) => 'hint_seen_$id';

class ScreenHint extends ConsumerStatefulWidget {
  const ScreenHint({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  /// Снова показать все подсказки.
  static Future<void> resetAll(WidgetRef ref) async {
    final prefs = ref.read(prefsProvider);
    for (final id in screenHints.keys) {
      await prefs.remove(_key(id));
    }
  }

  @override
  ConsumerState<ScreenHint> createState() => _ScreenHintState();
}

class _ScreenHintState extends ConsumerState<ScreenHint> {
  late bool _visible = ref.read(prefsProvider).getBool(_key(widget.id)) != true;

  void _dismiss() {
    ref.read(prefsProvider).setBool(_key(widget.id), true);
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    final hint = screenHints[widget.id];
    final accent = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: AppMotion.enter,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: !_visible || hint == null
                  ? const SizedBox.shrink()
                  : Material(
                      key: const ValueKey('hint'),
                      color: AppColors.raised,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(hint.$1, size: 20, color: accent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    hint.$2,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _dismiss,
                                child: const Text('Понятно'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
