import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../game/shop.dart';
import '../net/api_client.dart';
import '../state/account_state.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/motion.dart';

/// Инвентарь и магазин (экран 11): примерка на аватаре.
/// Инвентарь — только свои вещи; магазин — всё, что продаётся, с покупкой за монеты.
class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key, this.shop = false});

  /// true — магазин, false — инвентарь.
  final bool shop;

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  ShopSlot _slot = ShopSlot.hair;
  AvatarLook? _preview;

  static bool _same(AvatarLook a, AvatarLook b) =>
      jsonEncode(a.toJson()) == jsonEncode(b.toJson());

  void _tap(ShopItem item, AvatarLook current) {
    final takeOff = item.takeOff;
    setState(() {
      _preview = takeOff != null && item.isWorn(current)
          ? takeOff(current)
          : item.apply(current);
    });
  }

  Future<void> _confirm(List<ShopItem> cart, AvatarLook look) async {
    final ok = ref.read(accountProvider).signedIn
        ? await _confirmOnServer(cart, look)
        : await ref.read(heroProvider.notifier).buyAndWear(cart, look);
    if (!mounted || ok == null) return;
    _toast(
      ok
          ? (cart.isEmpty ? 'Образ сохранён' : 'Куплено и надето')
          : 'Не хватает монет',
    );
    if (ok) setState(() => _preview = null);
  }

  /// С аккаунтом монеты списывает сервер. null — ошибка уже показана.
  Future<bool?> _confirmOnServer(List<ShopItem> cart, AvatarLook look) async {
    final api = ref.read(apiProvider);
    try {
      final hero = cart.isEmpty
          ? await api.put('/v1/me/appearance', {'appearance': look.toJson()})
          : await api.post('/v1/shop/buy', {
              'itemIds': [for (final i in cart) i.id],
              'appearance': look.toJson(),
            });
      await ref.read(heroProvider.notifier).applyServer(hero);
      return true;
    } on ApiException catch (e) {
      if (e.status == 409) return false;
      _toast(e.isNetwork ? 'Нет связи с сервером' : e.message);
      return null;
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final look = _preview ?? hero.look;
    final cart = ShopCatalog.unpaid(look, hero.ownedItems);
    final total = cart.fold<int>(0, (s, i) => s + i.price);
    final changed = !_same(look, hero.look);
    bool owns(ShopItem i) => i.isFree || hero.ownedItems.contains(i.id);
    final shop = widget.shop;
    // В магазине — то, что продаётся (и эксклюзивы как витрина), в инвентаре — своё.
    final items = [
      for (final i in ShopCatalog.forSlot(_slot, look.sex))
        if (shop ? !i.isFree : owns(i)) i,
    ];
    final needsPremium = cart.any((i) => i.premium) && !hero.premium.active;
    final testerLocked = cart.any((i) => i.testerOnly);

    return Scaffold(
      appBar: AppBar(
        title: Text(shop ? 'Магазин' : 'Инвентарь'),
        actions: [
          if (shop)
            IconButton(
              tooltip: 'Премиум',
              onPressed: () => context.go('/shop/premium'),
              icon: Icon(
                LucideIcons.crown,
                size: 20,
                color: hero.premium.active ? _gold : null,
              ),
            )
          else
            IconButton(
              tooltip: 'Магазин',
              onPressed: () => context.go('/shop'),
              icon: const Icon(LucideIcons.shoppingBag, size: 20),
            ),
          _Coins(coins: hero.coins),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AvatarView(
                levels: hero.avatarLevels,
                look: look,
                withLamp: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final slot in ShopSlot.values)
                    if (!shop || slot != ShopSlot.skin)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(slot.label),
                          selected: slot == _slot,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _slot = slot),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              // Крупный системный шрифт — плитки выше, иначе подпись не влезет.
              height: MediaQuery.textScalerOf(context).scale(112),
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        shop
                            ? 'Здесь всё бесплатное — оно уже в инвентаре'
                            : 'Пока ничего — загляните в магазин',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Pressable(
                        scale: 0.94,
                        child: _ItemTile(
                          item: items[i],
                          worn: items[i].isWorn(look),
                          owned: owns(items[i]),
                          locked: items[i].premium && !hero.premium.active,
                          onTap: () => _tap(items[i], look),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  if (changed)
                    TextButton(
                      onPressed: () => setState(() => _preview = null),
                      child: const Text('Сбросить'),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          !changed ||
                              total > hero.coins ||
                              needsPremium ||
                              testerLocked
                          ? (needsPremium
                                ? () => context.go('/shop/premium')
                                : null)
                          : () => _confirm(cart, look),
                      child: Text(switch ((changed, cart.isEmpty)) {
                        (false, _) => 'Это твой образ',
                        (true, true) => 'Сохранить образ',
                        (true, false) when testerLocked =>
                          'Только для бета-тестеров',
                        (true, false) when needsPremium =>
                          'Нужен премиум — подробнее',
                        (true, false) when total > hero.coins =>
                          'Не хватает ${total - hero.coins} монет',
                        (true, false) => 'Купить за $total',
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _gold = Color(0xFFD9B25A);

class _Coins extends StatelessWidget {
  const _Coins({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(LucideIcons.coins, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: 6),
      Text('$coins', style: figureStyle(size: 16)),
    ],
  );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.worn,
    required this.owned,
    required this.onTap,
    this.locked = false,
  });

  final ShopItem item;
  final bool worn;
  final bool owned;
  final VoidCallback onTap;

  /// Премиум-вещь, а премиума нет: примерить можно, купить — нет.
  final bool locked;

  static const _slotIcons = {
    ShopSlot.hair: LucideIcons.scissors,
    ShopSlot.top: LucideIcons.shirt,
    ShopSlot.bottom: LucideIcons.layers,
    ShopSlot.sneakers: LucideIcons.footprints,
    ShopSlot.accessory: LucideIcons.watch,
  };

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final swatch = item.swatch;
    return Semantics(
      button: true,
      selected: worn,
      label:
          '${item.name}, ${owned ? 'есть' : '${item.price} монет'}${worn ? ', надето' : ''}',
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
              color: worn ? accent : AppColors.hairline,
              width: worn ? 1.5 : 1,
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
                        _slotIcons[item.slot] ?? LucideIcons.sparkles,
                        size: 18,
                        color: AppColors.textSecondary,
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const Spacer(),
              if (owned)
                Text(
                  worn ? 'надето' : 'есть',
                  style: TextStyle(
                    fontSize: 11,
                    color: worn ? accent : AppColors.textMuted,
                  ),
                )
              else if (item.testerOnly)
                const Text(
                  'тестерам',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8B5CF6)),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.premium ? LucideIcons.crown : LucideIcons.coins,
                      size: 12,
                      color: item.premium ? _gold : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${item.price}',
                      style: figureStyle(size: 12)
                          .copyWith(color: locked ? AppColors.textMuted : null),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
