/// Смена графика тренировок (PLAN 4.3): не чаще раза в 7 дней, чтобы нельзя было
/// «подстроить» график под пропуск и спасти серию. Первая смена — в любой момент.
/// С аккаунтом правило проверяет сервер (server/src/game/schedule.ts).
const scheduleChangeCooldown = Duration(days: 7);

/// [nextChangeAt] — когда смена станет доступна; null — уже можно.
bool canChangeSchedule(DateTime? nextChangeAt, DateTime now) =>
    nextChangeAt == null || !nextChangeAt.isAfter(now);
