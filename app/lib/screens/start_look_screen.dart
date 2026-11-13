import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../game/body_part.dart';
import '../game/shop.dart';
import '../net/api_client.dart';
import '../state/account_state.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/status_toast.dart';

/// «Мой старт»: первые 14 дней игрок бесплатно собирает себя — пол, телосложение,
/// кожу, причёску и одежду. Потом образ фиксируется как «Старт» на экране прогресса.
class StartLookScreen extends ConsumerStatefulWidget {
  const StartLookScreen({super.key});

  @override
  ConsumerState<StartLookScreen> createState() => _StartLookScreenState();
}

enum _Section {
  sex('Пол'),
  build('Телосложение'),
  skin('Кожа'),
  hair('Причёска'),
  hairColor('Цвет волос'),
  top('Верх'),
  topColor('Цвет верха'),
  bottom('Низ'),
  bottomColor('Цвет низа'),
  sneakers('Обувь');

  const _Section(this.label);
  final String label;

  ShopSlot? get slot => switch (this) {
    sex || build => null,
    skin => ShopSlot.skin,
    hair => ShopSlot.hair,
    hairColor => ShopSlot.hairColor,
    top => ShopSlot.top,
    topColor => ShopSlot.topColor,
    bottom => ShopSlot.bottom,
    bottomColor => ShopSlot.bottomColor,
    sneakers => ShopSlot.sneakers,
  };
}

typedef _Option = ({
  String label,
  Color? swatch,
  IconData? icon,
  AvatarLook Function(AvatarLook) apply,
  bool Function(AvatarLook) selected,
});

class _StartLookScreenState extends ConsumerState<StartLookScreen> {
  _Section _section = _Section.build;
  AvatarLook? _draft;
  bool _busy = false;

  static final _firstDay = {for (final p in BodyPart.values) p: 1};

  static const _slotIcons = {
    ShopSlot.hair: LucideIcons.scissors,
    ShopSlot.top: LucideIcons.shirt,
    ShopSlot.bottom: LucideIcons.layers,
    ShopSlot.sneakers: LucideIcons.footprints,
  };

  List<_Option> _options(AvatarLook look) {
    final slot = _section.slot;
    if (slot != null) {
      return [
        for (final i in ShopCatalog.forSlot(slot, look.sex))
          if (ShopCatalog.inCreator(i))
            (
              label: i.name,
              swatch: i.swatch,
              icon: _slotIcons[i.slot],
              apply: i.apply,
              selected: i.isWorn,
            ),
      ];
    }
    if (_section == _Section.sex) {
      return [
        for (final (sex, label) in [
          (AvatarSex.male, 'Мужской'),
          (AvatarSex.female, 'Женский'),
        ])
          (
            label: label,
            swatch: null,
            icon: LucideIcons.user,
            // Причёска и верх у полов разные — берём стартовые, остальное сохраняем.
            apply: (l) => l.sex == sex
                ? l
                : AvatarLook(
                    sex: sex,
                    skin: l.skin,
                    hair: AvatarLook.starter(sex).hair,
                    hairColor: l.hairColor,
                    top: l.top == TopKind.tee || l.top == TopKind.tank
                        ? l.top
                        : AvatarLook.starter(sex).top,
                    topColor: l.topColor,
                    bottom: l.bottom,
                    bottomColor: l.bottomColor,
                    sneakersColor: l.sneakersColor,
                    build: l.build,
                  ),
            selected: (l) => l.sex == sex,
          ),
      ];
    }
    return [
      for (final b in BodyBuild.values)
        (
          label: b.label,
          swatch: null,
          icon: LucideIcons.personStanding,
          apply: (l) => l.copyWith(build: b),
          selected: (l) => l.build == b,
        ),
    ];
  }

  Future<void> _save(AvatarLook look, {required bool lock}) async {
    if (lock && !await _confirmLock()) return;
    setState(() => _busy = true);
    try {
      if (ref.read(accountProvider).signedIn) {
        final hero = await ref.read(apiProvider).put('/v1/me/start-look', {
          'appearance': look.toJson(),
          'lock': lock,
        });
        await ref.read(heroProvider.notifier).applyServer(hero);
      } else {
        await ref.read(heroProvider.notifier).saveStartLook(look, lock: lock);
      }
      if (!mounted) return;
      setState(() => _draft = null);
      showStatus(
        lock ? 'Старт зафиксирован — вещи остались у тебя' : 'Сохранено',
        kind: StatusKind.success,
      );
      if (lock) context.pop();
    } on ApiException catch (e) {
      showStatusError(e.message, network: e.isNetwork);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmLock() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Зафиксировать старт?'),
          content: const Text(
            'Этот образ станет точкой «Старт» на экране прогресса, и поменять '
            'его будет нельзя. Надетые вещи останутся у тебя, дальше образ '
            'меняется в инвентаре и магазине.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ещё подумаю'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Зафиксировать'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final open = hero.startLookOpen(now);
    final look = _draft ?? hero.look;
    final changed = _draft != null;
    final options = _options(look);
    final daysLeft = open
        ? (hero.startLookUntil!.difference(now).inHours / 24).ceil()
        : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Мой старт')),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                open
                    ? 'Собери себя таким, какой ты сейчас: это точка «Старт» '
                          'на экране прогресса. Одежда здесь бесплатная, '
                          'ещё ${_days(daysLeft)}.'
                    : 'Старт уже зафиксирован. Образ меняется в инвентаре и магазине.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: AvatarView(
                levels: _firstDay,
                look: open ? look : hero.firstDayLook,
                withLamp: true,
              ),
            ),
            if (open) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final s in _Section.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.label),
                          selected: s == _section,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _section = s),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(104),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Pressable(
                    scale: 0.94,
                    child: _OptionTile(
                      option: options[i],
                      selected: options[i].selected(look),
                      onTap: () =>
                          setState(() => _draft = options[i].apply(look)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: !changed || _busy
                            ? null
                            : () => _save(look, lock: false),
                        child: const Text('Сохранить'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : () => _save(look, lock: true),
                        child: const Text('Зафиксировать'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static String _days(int n) {
    final mod10 = n % 10, mod100 = n % 100;
    final word = mod10 == 1 && mod100 != 11
        ? 'день'
        : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
        ? 'дня'
        : 'дней';
    return '$n $word';
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _Option option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final swatch = option.swatch;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 84,
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : AppColors.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: swatch ?? AppColors.raised,
                  border: Border.all(color: AppColors.hairline),
                ),
                child: swatch == null
                    ? Icon(
                        option.icon ?? LucideIcons.shirt,
                        size: 18,
                        color: AppColors.textSecondary,
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                option.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? accent : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
