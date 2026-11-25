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
import '../widgets/item_preview.dart';
import '../widgets/motion.dart';
import '../widgets/shop_entry.dart';
import '../widgets/status_toast.dart';

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
  ShopSlot _slot = ShopSlot.top;
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
    final heroes = ref.read(heroProvider.notifier);
    final ok = ref.read(accountProvider).signedIn
        ? await _confirmOnServer(cart, look)
        : await heroes.buyAndWear(cart, look);
    if (!mounted || ok == null) return;
    if (ok) {
      showStatus(
        cart.isEmpty ? 'Образ сохранён' : 'Куплено и надето',
        kind: StatusKind.success,
      );
    } else {
      showStatus('Не хватает монет', kind: StatusKind.error);
    }
    if (ok) setState(() => _preview = null);
  }

  /// С аккаунтом монеты списывает сервер. null — ошибка уже показана.
  Future<bool?> _confirmOnServer(List<ShopItem> cart, AvatarLook look) async {
    final api = ref.read(apiProvider);
    // Нотификатор — до await: экран могут закрыть во время покупки (п. 137).
    final heroes = ref.read(heroProvider.notifier);
    final account = ref.read(accountProvider.notifier);
    try {
      // Переодеться в своё можно и без сети: образ сразу на телефоне, на сервер
      // уйдёт при синхронизации (п. 114). Покупка — только с сетью: монеты
      // списывает сервер.
      if (cart.isEmpty) {
        final hero = await account.sendOrQueue('PUT', '/v1/me/appearance', {
          'appearance': look.toJson(),
        }, key: 'appearance');
        if (hero != null) {
          await heroes.applyServer(hero);
        } else {
          await heroes.setLook(look);
        }
        return true;
      }
      final hero = await api.post('/v1/shop/buy', {
        'itemIds': [for (final i in cart) i.id],
        'appearance': look.toJson(),
      });
      await heroes.applyServer(hero);
      return true;
    } on ApiException catch (e) {
      if (e.status == 409) return false;
      showStatusError(e.message, network: e.isNetwork);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final look = _preview ?? hero.look;
    // Пока открыт редактор стартового образа, его вещи бесплатны (как на сервере).
    final cart = [
      for (final i in ShopCatalog.unpaid(look, hero.ownedItems))
        if (!(hero.startLookOpen(DateTime.now()) && ShopCatalog.inCreator(i)))
          i,
    ];
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
    // Покупки — только с аккаунтом: монеты и вещи хранит сервер, без него они
    // пропали бы при регистрации или смене телефона. Примерка и своё — без ограничений.
    final needsAccount =
        cart.isNotEmpty && !ref.watch(accountProvider).signedIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(shop ? 'Магазин' : 'Инвентарь'),
        actions: [
          if (shop)
            IconButton(
              tooltip: 'Премиум',
              onPressed: () => context.push('/shop/premium'),
              icon: Icon(
                LucideIcons.crown,
                size: 20,
                color: hero.premium.active ? _gold : null,
              ),
            )
          else
            IconButton(
              tooltip: 'Магазин',
              onPressed: () => context.push('/shop'),
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
            if (shop)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PremiumBanner(compact: true),
              ),
            Expanded(
              child: AvatarView(
                levels: hero.avatarLevels,
                look: look,
                muscles: hero.muscles,
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
              height: MediaQuery.textScalerOf(context).scale(120),
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        shop
                            ? 'Здесь всё бесплатное — оно уже в инвентаре'
                            : 'Пока ничего — загляни в магазин',
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
                          base: look,
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
                      onPressed: changed && needsAccount
                          ? () => context.push('/profile/account')
                          : !changed ||
                                total > hero.coins ||
                                needsPremium ||
                                testerLocked
                          ? (needsPremium
                                ? () => context.push('/shop/premium')
                                : null)
                          : () => _confirm(cart, look),
                      child: Text(switch ((changed, cart.isEmpty)) {
                        (false, _) => 'Это твой образ',
                        (true, true) => 'Сохранить образ',
                        (true, false) when needsAccount =>
                          'Покупки — после регистрации',
                        (true, false) when testerLocked =>
                          cart.any((i) => i.streakDays != null)
                              ? 'Выдаётся за серию'
                              : cart.any((i) => i.exclusiveLabel != null)
                              ? 'Не продаётся'
                              : 'Только для бета-тестеров',
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
    required this.base,
    this.locked = false,
  });

  final ShopItem item;

  /// Образ, на котором показываем вещь в иконке.
  final AvatarLook base;
  final bool worn;
  final bool owned;
  final VoidCallback onTap;

  /// Премиум-вещь, а премиума нет: примерить можно, купить — нет.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
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
              color: worn ? accent : Colors.transparent,
              width: worn ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              // Иконка — сама вещь на герое, на тёмной подложке.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ItemPreview(item: item, base: base, size: 52),
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
              else if (item.streakDays case final days?)
                // Вещь за серию: огонёк и число дней — коротко, в одну строку.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.flame,
                      size: 12,
                      color: Color(0xFFFF8A3D),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$days',
                      style: figureStyle(
                        size: 12,
                        color: const Color(0xFFFF8A3D),
                      ),
                    ),
                  ],
                )
              else if (item.testerOnly)
                Text(
                  item.exclusiveLabel ?? 'тестерам',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    color: item.exclusiveLabel != null
                        ? const Color(0xFFFF8A3D)
                        : const Color(0xFF8B5CF6),
                  ),
                )
              else
                // Цена трёхзначная — при крупном шрифте ужимается, а не вылезает.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
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
                        style: figureStyle(
                          size: 12,
                        ).copyWith(color: locked ? AppColors.textMuted : null),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
