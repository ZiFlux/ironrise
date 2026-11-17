/**
 * Команды админки — общие для консоли (admin.ts, ярлык «Админка») и веб-админки
 * (admin.controller.ts). Каждое изменение пишется в журнал AdminAction.
 */
import { BODY_PARTS, BodyPart } from '../game/body-part';
import { premiumStatus } from '../game/premium';
import { levelFromXp, levels as levelsOf, power as powerOf } from '../game/progression';
import { AURA_KINDS, AURA_LEVEL_SESSIONS, AuraKind, auraLevel, readAuras } from '../game/aura';
import { LEAGUE_TIERS } from '../game/league';
import { GameConfig } from '../game/config';
import { NicknameSchema, isReservedNickname, nicknameKey } from '../game/nickname';
import { moderateNicknames } from './nick-moderation';
import { ACHIEVEMENT_ITEMS, AUTHOR_ITEMS, EXCLUSIVE_ITEMS, SHOP_PRICES, TESTER_ITEMS } from '../game/shop';
import { STREAK_ITEMS, readBoosters } from '../game/streak-rewards';
import { Prisma, PrismaClient } from '../generated/prisma/client';
import { SEASON_ITEMS } from '../game/season';
import { pulseNorms } from '../game/pulse-norms';
import { findExercise } from '../game/exercises';

export const HELP = `Команды (ник или e-mail игрока — <кто>):
  find <кто>                     — карточка игрока
  list [N]                       — последние зарегистрированные
  coins <кто> <±N> [причина]     — начислить или списать монеты
  give <кто> <вещь...>           — выдать вещи (id из магазина)
  take <кто> <вещь...>           — забрать вещи
  xp <кто> <часть> <±N>          — поправить опыт части тела (chest back arms legs core cardio)
  streak <кто> <N>               — выставить серию дней
  premium <кто> <дней|off>       — премиум на N дней или снять
  tester <кто> [off]             — статус бета-тестера (с вещами тестера)
  ban <кто> <причина>            — заблокировать: вход закрыт, сессии сброшены
  unban <кто>                    — снять блокировку
  boosters <кто> <опыт> <монеты> — выставить бустеры серии (штук)
  nick <кто> <новый ник>         — переименовать (без кулдауна, старый ник не бронируется)
  duels-reset <кто>              — сбросить сегодняшние бои с ботами (перезарядку)
  suspects                       — подозрения античита, не разобранные (п. 113)
  clear <кто>                    — «не жулик»: закрыть подозрения и снять блокировку
  confirm <кто> [причина]        — подтвердить: закрыть подозрения, блокировка остаётся
  level <кто> <часть|all> <N>    — выставить уровень части тела (или всех) — сила пересчитается
  power <кто> <N>                — поднять/опустить все части ровно до силы ≈ N
  aura <кто> <вид> <уровень 0–5> — уровень ауры (fury guard haste focus); 0 — закрыть
  aura-equip <кто> <вид|off>     — надеть ауру или снять
  aura-reset <кто>               — снять лимит тренировок ауры на сегодня и неделю
  league <кто> <0–5>             — лига (0 бронзовая … 5 чемпионская)
  season <кто> <±очки>           — очки сезона (награды выдадутся при следующем начислении)
  start-look <кто>               — снова открыть бесплатный выбор стартового образа на 14 дней
  history [N]                    — журнал действий администратора
  nick-scan                      — ники, нарушающие список банвордов (shared/banwords.json)
  nick-moderate                  — заменить такие ники на нейтральные «Боец 1234», смена — бесплатно
  items                          — все id вещей по группам`;

export type Db = Pick<
  PrismaClient,
  | '$transaction'
  | 'user'
  | 'profile'
  | 'walletTx'
  | 'inventoryItem'
  | 'avatarPart'
  | 'xpEvent'
  | 'refreshToken'
  | 'adminAction'
  | 'workout'
  | 'duel'
  | 'suspicion'
>;

export async function findUser(db: Db, who: string) {
  const user = await db.user.findFirst({
    where: who.includes('@')
      ? { email: who.toLowerCase() }
      : { profile: { nickname: { equals: who, mode: 'insensitive' } } },
    include: { profile: true },
  });
  if (!user?.profile) throw new Error(`Игрок «${who}» не найден`);
  return user as typeof user & { profile: NonNullable<typeof user.profile> };
}

const log = (db: Db, command: string, userId: string | null, details: object) =>
  db.adminAction.create({ data: { command, userId, details: details as Prisma.InputJsonValue } });

const int = (s: string | undefined, what: string): number => {
  const n = Number(s);
  if (!Number.isInteger(n)) throw new Error(`${what}: нужно целое число, получено «${s ?? ''}»`);
  return n;
};

async function card(db: Db, who: string): Promise<string> {
  const u = await findUser(db, who);
  const [coins, parts, items, workouts] = await Promise.all([
    db.walletTx.aggregate({ where: { userId: u.id }, _sum: { amount: true } }),
    db.avatarPart.findMany({ where: { userId: u.id } }),
    db.inventoryItem.findMany({ where: { userId: u.id }, select: { itemId: true } }),
    db.workout.count({ where: { userId: u.id } }),
  ]);
  const p = u.profile;
  const prem = premiumStatus(p);
  const xp = BODY_PARTS.map((part) => {
    const v = parts.find((r) => r.part === part)?.xp ?? 0;
    return `${part} ${levelFromXp(v)} ур. (${v} xp)`;
  });
  return [
    `${p.nickname} <${u.email}>  id ${u.id}`,
    `  создан ${u.createdAt.toISOString().slice(0, 10)}, тренировок ${workouts}, серия ${p.streakDays}, последний день ${p.lastActiveDay ?? '—'}`,
    `  монеты ${coins._sum.amount ?? 0}; премиум ${prem.active ? prem.source + (prem.until ? ' до ' + prem.until.toISOString().slice(0, 10) : '') : 'нет'}; тестер ${p.isTester ? 'да' : 'нет'}`,
    `  блокировка: ${u.bannedAt ? `${u.bannedAt.toISOString().slice(0, 16)} — ${u.banReason ?? ''}` : 'нет'}`,
    `  опыт: ${xp.join(', ')}`,
    `  вещи: ${items.map((i) => i.itemId).join(', ') || '—'}`,
    `  бустеры: опыт ${readBoosters(p.boosters).xp}, монеты ${readBoosters(p.boosters).coins}; веха героя ${p.heroMilestone}`,
    `  сила ${powerOf(levelsOf(Object.fromEntries(parts.map((r) => [r.part, r.xp])) as Record<BodyPart, number>), p.streakDays)}; лига ${LEAGUE_TIERS[p.leagueTier] ?? p.leagueTier}; сезон ${p.seasonNumber}, очков ${p.seasonPoints}`,
    `  ауры: ${AURA_KINDS.map((k) => `${k} ${auraLevel(readAuras(p.auras)[k])}`).join(', ')}; надета ${p.auraEquipped ?? '—'}; на неделе ${p.auraSessions}`,
  ].join('\n');
}

export async function run(db: Db, [cmd, who, ...rest]: string[]): Promise<string> {
  switch (cmd) {
    case 'find':
      return card(db, who);

    case 'list': {
      const users = await db.user.findMany({
        orderBy: { createdAt: 'desc' },
        take: rest.length ? int(who, 'N') : who ? int(who, 'N') : 20,
        include: { profile: { select: { nickname: true, isTester: true } } },
      });
      return users
        .map((u) => `${u.createdAt.toISOString().slice(0, 10)}  ${u.profile?.nickname ?? '—'}  <${u.email}>${u.profile?.isTester ? '  [тестер]' : ''}${u.bannedAt ? '  [бан]' : ''}`)
        .join('\n');
    }

    case 'coins': {
      const u = await findUser(db, who);
      const amount = int(rest[0], 'Сумма');
      const reason = rest.slice(1).join(' ') || 'корректировка';
      await db.walletTx.create({ data: { userId: u.id, amount, reason: `admin:${reason}` } });
      await log(db, 'coins', u.id, { amount, reason });
      return card(db, who);
    }

    case 'give':
    case 'take': {
      const u = await findUser(db, who);
      const known = new Set([...Object.keys(SHOP_PRICES), ...EXCLUSIVE_ITEMS]);
      const bad = rest.filter((id) => !known.has(id));
      if (!rest.length || bad.length) throw new Error(`Неизвестные вещи: ${bad.join(', ') || '(не указаны)'} — список: items`);
      if (cmd === 'give') {
        await db.inventoryItem.createMany({ data: rest.map((itemId) => ({ userId: u.id, itemId })), skipDuplicates: true });
      } else {
        await db.inventoryItem.deleteMany({ where: { userId: u.id, itemId: { in: rest } } });
      }
      await log(db, cmd, u.id, { items: rest });
      return (await card(db, who)) + (cmd === 'take' ? '\n  (если вещь надета, она пропадёт с аватара при следующей смене образа)' : '');
    }

    case 'xp': {
      const u = await findUser(db, who);
      const part = rest[0] as BodyPart;
      if (!BODY_PARTS.includes(part)) throw new Error(`Часть тела: ${BODY_PARTS.join(', ')}`);
      const delta = int(rest[1], 'Опыт');
      const row = await db.avatarPart.findUniqueOrThrow({ where: { userId_part: { userId: u.id, part } } });
      const next = Math.max(0, row.xp + delta);
      await db.$transaction([
        db.avatarPart.update({ where: { userId_part: { userId: u.id, part } }, data: { xp: next } }),
        db.xpEvent.create({ data: { userId: u.id, part, xp: next - row.xp, validity: 1, wasLagging: false } }),
      ]);
      await log(db, 'xp', u.id, { part, delta: next - row.xp });
      return card(db, who);
    }

    case 'level':
    case 'power': {
      const u = await findUser(db, who);
      const rows = await db.avatarPart.findMany({ where: { userId: u.id } });
      const xpNow = Object.fromEntries(rows.map((r) => [r.part, r.xp])) as Record<BodyPart, number>;
      let target: Partial<Record<BodyPart, number>>;
      if (cmd === 'level') {
        const which = rest[0];
        const lvl = int(rest[1], 'Уровень');
        if (lvl < 1 || lvl > 500) throw new Error('Уровень: 1–500');
        if (which !== 'all' && !BODY_PARTS.includes(which as BodyPart)) {
          throw new Error(`Часть тела: ${BODY_PARTS.join(', ')} или all`);
        }
        const parts = which === 'all' ? BODY_PARTS : [which as BodyPart];
        target = Object.fromEntries(parts.map((p) => [p, lvl]));
      } else {
        // Ровные уровни дают бонус баланса ×1,05: P ≈ (60·L + 2·min(S,30))·1,05.
        const want = int(rest[0], 'Сила');
        const streakBonus = 2 * Math.min(u.profile.streakDays, GameConfig.streakCap);
        const lvl = Math.max(1, Math.round((want / GameConfig.powerBonusBalanced - streakBonus) / (10 * BODY_PARTS.length)));
        target = Object.fromEntries(BODY_PARTS.map((p) => [p, lvl]));
      }
      const ops = (Object.entries(target) as [BodyPart, number][]).flatMap(([part, lvl]) => {
        const xp = (lvl - 1) * GameConfig.xpPerLevel;
        const delta = xp - (xpNow[part] ?? 0);
        return [
          db.avatarPart.upsert({
            where: { userId_part: { userId: u.id, part } },
            update: { xp },
            create: { userId: u.id, part, xp },
          }),
          db.xpEvent.create({ data: { userId: u.id, part, xp: delta, validity: 1, wasLagging: false } }),
        ];
      });
      await db.$transaction(ops);
      const after = await db.avatarPart.findMany({ where: { userId: u.id } });
      const lv = levelsOf(Object.fromEntries(after.map((r) => [r.part, r.xp])) as Record<BodyPart, number>);
      await log(db, cmd, u.id, { target });
      return `Сила теперь ${powerOf(lv, u.profile.streakDays)}.\n` + (await card(db, who));
    }

    case 'aura': {
      const u = await findUser(db, who);
      const kind = rest[0] as AuraKind;
      if (!AURA_KINDS.includes(kind)) throw new Error(`Аура: ${AURA_KINDS.join(', ')}`);
      const lvl = int(rest[1], 'Уровень');
      if (lvl < 0 || lvl > AURA_LEVEL_SESSIONS.length) throw new Error(`Уровень ауры: 0–${AURA_LEVEL_SESSIONS.length}`);
      const progress = readAuras(u.profile.auras);
      progress[kind] = lvl === 0 ? 0 : AURA_LEVEL_SESSIONS[lvl - 1];
      const equipped = lvl === 0 && u.profile.auraEquipped === kind ? null : u.profile.auraEquipped;
      await db.profile.update({
        where: { userId: u.id },
        data: { auras: progress as unknown as Prisma.InputJsonValue, auraEquipped: equipped },
      });
      await log(db, 'aura', u.id, { kind, level: lvl });
      return card(db, who);
    }

    case 'aura-equip': {
      const u = await findUser(db, who);
      const kind = rest[0] === 'off' ? null : (rest[0] as AuraKind);
      if (kind !== null) {
        if (!AURA_KINDS.includes(kind)) throw new Error(`Аура: ${AURA_KINDS.join(', ')} или off`);
        if (auraLevel(readAuras(u.profile.auras)[kind]) === 0) throw new Error('Аура закрыта — сначала aura <кто> <вид> <уровень>');
      }
      await db.profile.update({ where: { userId: u.id }, data: { auraEquipped: kind } });
      await log(db, 'aura-equip', u.id, { kind });
      return card(db, who);
    }

    case 'aura-reset': {
      const u = await findUser(db, who);
      await db.profile.update({ where: { userId: u.id }, data: { auraWeek: null, auraSessions: 0, auraLastDay: null } });
      await log(db, 'aura-reset', u.id, {});
      return card(db, who);
    }

    case 'league': {
      const u = await findUser(db, who);
      const tier = int(rest[0], 'Лига');
      if (tier < 0 || tier >= LEAGUE_TIERS.length) throw new Error(`Лига: 0–${LEAGUE_TIERS.length - 1}`);
      await db.profile.update({ where: { userId: u.id }, data: { leagueTier: tier } });
      await log(db, 'league', u.id, { tier });
      return card(db, who);
    }

    case 'season': {
      const u = await findUser(db, who);
      const delta = int(rest[0], 'Очки');
      const points = Math.max(0, u.profile.seasonPoints + delta);
      await db.profile.update({ where: { userId: u.id }, data: { seasonPoints: points } });
      await log(db, 'season', u.id, { delta, points });
      return card(db, who);
    }

    case 'start-look': {
      const u = await findUser(db, who);
      await db.profile.update({
        where: { userId: u.id },
        data: { startLockedAt: null, startLookUntil: new Date(Date.now() + 14 * 86_400_000) },
      });
      await log(db, 'start-look', u.id, {});
      return card(db, who);
    }

    case 'streak': {
      const u = await findUser(db, who);
      const days = int(rest[0], 'Серия');
      // Серия считается от последнего активного дня — ставим его на сегодня (в поясе игрока).
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: u.profile.timezone }).format(new Date());
      await db.profile.update({ where: { userId: u.id }, data: { streakDays: Math.max(0, days), lastActiveDay: today } });
      await log(db, 'streak', u.id, { days });
      return card(db, who);
    }

    case 'premium': {
      const u = await findUser(db, who);
      const off = rest[0] === 'off';
      const until = off ? null : new Date(Date.now() + int(rest[0], 'Дней') * 86_400_000);
      await db.profile.update({ where: { userId: u.id }, data: { premiumUntil: until } });
      await log(db, 'premium', u.id, { until });
      return card(db, who);
    }

    case 'tester': {
      const u = await findUser(db, who);
      const off = rest[0] === 'off';
      await db.profile.update({ where: { userId: u.id }, data: { isTester: !off } });
      if (!off) {
        await db.inventoryItem.createMany({
          data: TESTER_ITEMS.map((itemId) => ({ userId: u.id, itemId })),
          skipDuplicates: true,
        });
      }
      await log(db, 'tester', u.id, { on: !off });
      return card(db, who);
    }

    case 'ban': {
      const u = await findUser(db, who);
      const reason = rest.join(' ').trim();
      if (!reason) throw new Error('Укажите причину блокировки — её увидит игрок');
      await db.$transaction([
        db.user.update({ where: { id: u.id }, data: { bannedAt: new Date(), banReason: reason } }),
        // Сессии гасим сразу; запросы по выданному access-токену сервер отклонит в течение 30 с (AuthGuard).
        db.refreshToken.updateMany({ where: { userId: u.id, revokedAt: null }, data: { revokedAt: new Date() } }),
      ]);
      await log(db, 'ban', u.id, { reason });
      return card(db, who);
    }

    case 'unban': {
      const u = await findUser(db, who);
      await db.user.update({ where: { id: u.id }, data: { bannedAt: null, banReason: null } });
      await log(db, 'unban', u.id, {});
      return card(db, who);
    }

    case 'boosters': {
      const u = await findUser(db, who);
      const boosters = { xp: Math.max(0, int(rest[0], 'Бустеры опыта')), coins: Math.max(0, int(rest[1], 'Бустеры монет')) };
      await db.profile.update({ where: { userId: u.id }, data: { boosters } });
      await log(db, 'boosters', u.id, boosters);
      return card(db, who);
    }

    case 'nick': {
      const u = await findUser(db, who);
      const parsed = NicknameSchema.safeParse(rest.join(' '));
      if (!parsed.success) throw new Error('Ник: 3–20 знаков, буквы, цифры, «_» и пробелы');
      const nickname = parsed.data;
      if (isReservedNickname(nickname)) throw new Error('Этот ник запрещён (выдаёт себя за проект)');
      const key = nicknameKey(nickname);
      const taken = await db.profile.findUnique({ where: { nicknameKey: key }, select: { userId: true } });
      if (taken && taken.userId !== u.id) throw new Error('Ник занят другим игроком');
      await db.profile.update({ where: { userId: u.id }, data: { nickname, nicknameKey: key } });
      await log(db, 'nick', u.id, { from: u.profile.nickname, to: nickname });
      return card(db, nickname);
    }

    case 'nick-scan': {
      // Только показать ники, которые нарушают текущий список банвордов.
      const list = await moderateNicknames(db, { apply: false });
      return list.length ? list.map((v) => `${v.nickname}  (${v.userId})`).join('\n') : 'Нарушающих ников нет';
    }

    case 'nick-moderate': {
      // Заменить нарушающие ники на нейтральные (без пуша — его шлёт сервер при своей проверке).
      const list = await moderateNicknames(db, { apply: true });
      return list.length
        ? list.map((v) => `${v.nickname} → ${v.replacement}`).join('\n')
        : 'Нарушающих ников нет';
    }

    case 'duels-reset': {
      const u = await findUser(db, who);
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: u.profile.timezone }).format(new Date());
      const { count } = await db.duel.deleteMany({ where: { attackerId: u.id, opponentKind: 'bot', day: today } });
      await log(db, 'duels-reset', u.id, { removed: count });
      return `Снято боёв с ботами за сегодня: ${count}. Монеты за них остаются у игрока.\n` + (await card(db, who));
    }

    case 'suspects': {
      const rows = await db.suspicion.findMany({
        where: { resolvedAt: null },
        orderBy: { createdAt: 'desc' },
        take: 50,
        include: { user: { select: { bannedAt: true, profile: { select: { nickname: true } } } } },
      });
      return (
        rows
          .map(
            (r) =>
              `${r.createdAt.toISOString().slice(0, 16)}  ${(r.user.profile?.nickname ?? '—').padEnd(16)} ${r.kind}${r.severe ? ' [серьёзно]' : ''}${r.user.bannedAt ? ' [заблокирован]' : ''}  ${JSON.stringify(r.details)}`,
          )
          .join('\n') || 'Подозрений нет'
      );
    }

    case 'clear':
    case 'confirm': {
      const u = await findUser(db, who);
      const now = new Date();
      const note = rest.join(' ').trim() || null;
      const { count } = await db.suspicion.updateMany({
        where: { userId: u.id, resolvedAt: null },
        data: { resolvedAt: now, resolution: cmd, resolvedNote: note },
      });
      if (cmd === 'clear') {
        await db.user.update({ where: { id: u.id }, data: { bannedAt: null, banReason: null } });
      } else {
        const reason = rest.join(' ').trim() || 'Нарушение честной игры: подозрительные тренировки';
        await db.user.update({ where: { id: u.id }, data: { bannedAt: u.bannedAt ?? now, banReason: reason } });
      }
      await log(db, cmd, u.id, { resolved: count });
      return `Закрыто подозрений: ${count}.\n` + (await card(db, who));
    }

    case 'history': {
      const rows = await db.adminAction.findMany({ orderBy: { at: 'desc' }, take: who ? int(who, 'N') : 30 });
      const names = new Map(
        (await db.profile.findMany({ where: { userId: { in: rows.flatMap((r) => (r.userId ? [r.userId] : [])) } } })).map(
          (p) => [p.userId, p.nickname],
        ),
      );
      return rows
        .map((r) => `${r.at.toISOString().slice(0, 16)}  ${r.command.padEnd(8)} ${names.get(r.userId ?? '') ?? '—'}  ${JSON.stringify(r.details)}`)
        .join('\n') || 'Журнал пуст';
    }

    case 'items':
      return itemGroups()
        .map((g) => `${g.name}: ${g.items.map((i) => (i.price ? `${i.id} (${i.price})` : i.id)).join(', ')}`)
        .join('\n');

    default:
      return HELP;
  }
}


/**
 * Журнал античита (п. 134): подозрения с фильтрами — открытые, разобранные, все;
 * по виду; за N дней. С ником, днём тренировки и решением админа.
 */
export async function suspicionLog(
  db: Db,
  q: { status?: string; kind?: string; days?: number },
  now = new Date(),
) {
  const days = Math.min(Math.max(q.days ?? 30, 1), 365);
  const rows = await db.suspicion.findMany({
    where: {
      createdAt: { gte: new Date(now.getTime() - days * 86_400_000) },
      ...(q.status === 'open' ? { resolvedAt: null } : q.status === 'resolved' ? { resolvedAt: { not: null } } : {}),
      ...(q.kind ? { kind: q.kind } : {}),
    },
    orderBy: { createdAt: 'desc' },
    take: 300,
    include: { user: { select: { bannedAt: true, profile: { select: { nickname: true } } } } },
  });
  const workoutIds = rows.flatMap((r) => (r.workoutId ? [r.workoutId] : []));
  const days_ = new Map(
    (await db.workout.findMany({ where: { id: { in: workoutIds } }, select: { id: true, day: true, type: true } })).map(
      (w) => [w.id, w],
    ),
  );
  return rows.map((r) => ({
    at: r.createdAt,
    nickname: r.user.profile?.nickname ?? '—',
    kind: r.kind,
    severe: r.severe,
    blocked: r.blocked,
    bannedNow: r.user.bannedAt !== null,
    details: r.details,
    workoutDay: r.workoutId ? (days_.get(r.workoutId)?.day ?? null) : null,
    workoutType: r.workoutId ? (days_.get(r.workoutId)?.type ?? null) : null,
    resolvedAt: r.resolvedAt,
    resolution: r.resolution,
    note: r.resolvedNote,
  }));
}

/** Все вещи, которые можно выдать, по группам (цена — у продающихся). */
export function itemGroups(): { name: string; items: { id: string; price: number | null }[] }[] {
  const groups: [string, (id: string) => boolean][] = [
    ['Причёски', (id) => id.startsWith('hair_')],
    ['Цвет волос', (id) => id.startsWith('hc_')],
    ['Верх', (id) => id.startsWith('top_')],
    ['Цвет верха', (id) => id.startsWith('tc_')],
    ['Низ', (id) => id.startsWith('bottom_')],
    ['Цвет низа', (id) => id.startsWith('bc_')],
    ['Обувь', (id) => id.startsWith('sn_')],
    ['Аксессуары', (id) => id.startsWith('acc_')],
  ];
  const forSale = Object.keys(SHOP_PRICES).filter((id) => SHOP_PRICES[id] > 0);
  const priced = (ids: readonly string[]) => ids.map((id) => ({ id, price: SHOP_PRICES[id] > 0 ? SHOP_PRICES[id] : null }));
  return [
    ...groups.map(([name, test]) => ({ name, items: priced(forSale.filter(test)) })),
    { name: 'Тестерам', items: priced(TESTER_ITEMS) },
    { name: 'За серию', items: priced(STREAK_ITEMS) },
    { name: 'Создателю', items: priced(AUTHOR_ITEMS) },
    { name: 'За достижения', items: priced(Object.values(ACHIEVEMENT_ITEMS)) },
    { name: 'Сезонные', items: priced(SEASON_ITEMS) },
  ];
}

/** Карточка игрока для веб-админки: текст как в консоли и список вещей. */
export async function playerInfo(db: Db, who: string) {
  const u = await findUser(db, who);
  const owned = await db.inventoryItem.findMany({ where: { userId: u.id }, select: { itemId: true } });
  return {
    nickname: u.profile.nickname,
    banned: u.bannedAt != null,
    card: await card(db, who),
    owned: owned.map((i) => i.itemId),
  };
}

const isoDay = (d: Date) => d.toISOString().slice(0, 10);

/**
 * Статистика для веб-админки (п. 120): игроки, активность, удержание, тренировки по
 * дням, экономика, входные тренировки, цели и форматы. Только сводные числа — без
 * персональных данных.
 */
export async function adminStats(db: Db & Pick<PrismaClient, 'entryTest'>, now = new Date()) {
  const day = 86_400_000;
  const ago = (n: number) => new Date(now.getTime() - n * day);
  const today = isoDay(now);
  const [total, new1, new7, active1, active7, active30, cohort, cohortActive] = await Promise.all([
    db.user.count(),
    db.user.count({ where: { createdAt: { gte: ago(1) } } }),
    db.user.count({ where: { createdAt: { gte: ago(7) } } }),
    db.profile.count({ where: { lastActiveDay: { gte: isoDay(ago(1)) } } }),
    db.profile.count({ where: { lastActiveDay: { gte: isoDay(ago(7)) } } }),
    db.profile.count({ where: { lastActiveDay: { gte: isoDay(ago(30)) } } }),
    // Удержание: зарегистрированы 8–30 дней назад — сколько тренировались за последнюю неделю.
    db.user.count({ where: { createdAt: { gte: ago(30), lt: ago(8) } } }),
    db.user.count({
      where: { createdAt: { gte: ago(30), lt: ago(8) }, profile: { lastActiveDay: { gte: isoDay(ago(7)) } } },
    }),
  ]);
  const since14 = isoDay(ago(13));
  const byDay = await db.workout.groupBy({
    by: ['day', 'type'],
    where: { day: { gte: since14 } },
    _count: { _all: true },
  });
  const workoutsPerDay = Array.from({ length: 14 }, (_, i) => {
    const d = isoDay(ago(13 - i));
    const count = (t: string) => byDay.find((r) => r.day === d && r.type === t)?._count._all ?? 0;
    return { day: d, strength: count('strength'), cardio: count('cardio') };
  });
  const [issued, spent, verified, allWeek] = await Promise.all([
    db.walletTx.aggregate({ _sum: { amount: true }, where: { amount: { gt: 0 }, createdAt: { gte: ago(7) } } }),
    db.walletTx.aggregate({ _sum: { amount: true }, where: { amount: { lt: 0 }, createdAt: { gte: ago(7) } } }),
    db.workout.count({ where: { day: { gte: isoDay(ago(6)) }, validity: { gte: 0.99 } } }),
    db.workout.count({ where: { day: { gte: isoDay(ago(6)) } } }),
  ]);
  const [goals, formats, entryLevels, openSuspicions] = await Promise.all([
    db.profile.groupBy({ by: ['goal'], _count: { _all: true } }),
    db.profile.groupBy({ by: ['trainingFormat'], _count: { _all: true } }),
    db.entryTest.groupBy({ by: ['level'], _count: { _all: true } }),
    db.suspicion.count({ where: { resolvedAt: null } }),
  ]);
  const counts = (rows: { _count: { _all: number } }[], key: (r: never) => string) =>
    Object.fromEntries(rows.map((r) => [key(r as never), r._count._all]));
  return {
    today,
    players: { total, new1, new7, active1, active7, active30 },
    retention: { cohort, active: cohortActive, percent: cohort ? Math.round((cohortActive / cohort) * 100) : null },
    workoutsPerDay,
    week: {
      workouts: allWeek,
      verifiedPercent: allWeek ? Math.round((verified / allWeek) * 100) : null,
      coinsIssued: issued._sum.amount ?? 0,
      coinsSpent: -(spent._sum.amount ?? 0),
    },
    goals: counts(goals, (r: { goal: string }) => r.goal),
    formats: counts(formats, (r: { trainingFormat: string }) => r.trainingFormat),
    entryLevels: counts(entryLevels, (r: { level: string }) => r.level),
    openSuspicions,
  };
}

/** Последние тренировки игрока (веб-админка, карточка игрока). */
export async function playerWorkouts(db: Db, who: string, take = 15) {
  const u = await findUser(db, who);
  const rows = await db.workout.findMany({
    where: { userId: u.id },
    orderBy: { startedAt: 'desc' },
    take,
    select: { day: true, type: true, validity: true, startedAt: true, endedAt: true, payload: true },
  });
  return rows.map((w) => {
    const p = w.payload as { entries?: { sets: unknown[] }[]; activity?: string; summary?: { gains?: { xp: number }[] } } | null;
    return {
      day: w.day,
      type: w.type,
      minutes: Math.round((w.endedAt.getTime() - w.startedAt.getTime()) / 60_000),
      sets: p?.entries?.reduce((n, e) => n + e.sets.length, 0) ?? 0,
      activity: p?.activity ?? null,
      xp: Math.round((p?.summary?.gains ?? []).reduce((n, g) => n + g.xp, 0)),
      verified: w.validity >= 0.99,
    };
  });
}

/**
 * Нормы пульса по упражнениям за 60 дней (п. 118) — для админки. Пульсовые поля в
 * тренировках есть только у игроков с согласием на данные о здоровье (п. 106).
 */
export async function adminPulseNorms(db: Db, now = new Date()) {
  const rows = await db.workout.findMany({
    where: { type: 'strength', startedAt: { gte: new Date(now.getTime() - 60 * 86_400_000) } },
    select: { payload: true },
    take: 5000,
  });
  type Entry = { exerciseId: string; sets: { peak?: number; base?: number }[] };
  const norms = pulseNorms(rows.map((r) => ((r.payload as { entries?: Entry[] } | null)?.entries ?? []) as Entry[]));
  return norms.map((n) => ({ ...n, name: findExercise(n.exerciseId)?.name ?? n.exerciseId }));
}
