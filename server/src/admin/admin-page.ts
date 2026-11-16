/**
 * Страница веб-админки (/admin). Данных в ней нет: всё приходит из /admin/api/*
 * по ключу, который вводится на странице и живёт в sessionStorage до закрытия вкладки.
 * Без обратных кавычек и «${» в скрипте страницы — это шаблонная строка TypeScript.
 */
export const adminPageHtml = String.raw`<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>IronRise — админка</title>
<style>
  :root { --bg:#141415; --surface:#19191b; --raised:#232325; --text:#ededed; --text2:#a1a1a6;
    --muted:#85858b; --line:#2c2c2f; --accent:#c6ff3d; --on-accent:#111; --danger:#ff6b5e; }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--text); font:15px/1.45 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  .wrap { max-width:980px; margin:0 auto; padding:20px 16px 60px; }
  h1 { font-size:22px; margin:0 0 16px; }
  h2 { font-size:15px; color:var(--text2); font-weight:600; margin:22px 0 8px; }
  .card { background:var(--surface); border:1px solid var(--line); border-radius:14px; padding:14px; }
  .row { display:flex; gap:8px; flex-wrap:wrap; align-items:center; }
  input { flex:1; min-width:0; background:var(--raised); color:var(--text); border:1px solid var(--line);
    border-radius:10px; padding:10px 12px; font:inherit; }
  button { background:var(--raised); color:var(--text); border:1px solid var(--line); border-radius:10px;
    padding:10px 14px; font:inherit; cursor:pointer; }
  button.primary { background:var(--accent); color:var(--on-accent); border-color:var(--accent); font-weight:600; }
  button.danger { color:var(--danger); border-color:var(--danger); background:transparent; }
  button:disabled { opacity:.45; cursor:default; }
  pre { white-space:pre-wrap; word-break:break-word; margin:0; font:13px/1.5 ui-monospace, Consolas, monospace; color:var(--text2); }
  .chips { display:flex; flex-wrap:wrap; gap:6px; }
  .chip { padding:6px 10px; border-radius:999px; border:1px solid var(--line); background:transparent;
    color:var(--text2); font-size:13px; }
  .chip.owned { border-color:#3a5a1a; color:var(--text); background:#1f2a12; }
  .chip.sel { outline:2px solid var(--accent); color:var(--text); }
  .chip small { color:var(--muted); margin-left:4px; }
  .legend { color:var(--muted); font-size:13px; margin:6px 0 0; }
  .msg { margin-top:10px; padding:10px 12px; border-radius:10px; background:var(--raised); display:none; }
  .msg.err { color:var(--danger); }
  .hidden { display:none; }
  .stats { display:grid; grid-template-columns:repeat(auto-fill,minmax(150px,1fr)); gap:8px; }
  .stat { background:var(--surface); border:1px solid var(--line); border-radius:12px; padding:10px 12px; }
  .stat b { display:block; font-size:22px; }
  .stat span { color:var(--muted); font-size:12px; }
  .bars { display:flex; align-items:flex-end; gap:4px; height:130px; padding-top:8px; }
  .bars div { flex:1; display:flex; flex-direction:column; justify-content:flex-end; align-items:center; gap:2px; min-width:0; }
  .bars i { display:block; width:100%; border-radius:3px 3px 0 0; }
  .bars small { color:var(--muted); font-size:10px; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  td, th { padding:6px 4px; border-bottom:1px solid var(--line); text-align:left; }
  th { color:var(--muted); font-weight:500; }
  .bar { position:sticky; bottom:0; background:var(--bg); padding:12px 0; border-top:1px solid var(--line); margin-top:16px; }
</style>
</head>
<body>
<div class="wrap">
  <h1>IronRise — админка</h1>

  <div id="login" class="card">
    <div class="row">
      <input id="token" type="password" placeholder="Ключ админки (ADMIN_TOKEN)" autocomplete="off">
      <button class="primary" id="enter">Войти</button>
    </div>
    <p class="legend">Ключ хранится только в этой вкладке до её закрытия.</p>
  </div>

  <div id="main" class="hidden">
    <div class="card">
      <div class="row">
        <input id="who" placeholder="Ник или e-mail игрока">
        <button class="primary" id="find">Найти</button>
        <button id="recent">Последние</button>
        <button id="history">Журнал</button>
        <button id="suspects">Античит</button>
        <button id="statsBtn">Статистика</button>
        <button id="logout">Выйти</button>
      </div>
    </div>
    <div id="msg" class="msg"></div>

    <div id="statsBox" class="hidden"></div>

    <div id="susBox" class="hidden">
      <h2>Античит</h2>
      <div class="row">
        <select id="susStatus">
          <option value="open">Не разобранные</option>
          <option value="resolved">Разобранные</option>
          <option value="all">Все</option>
        </select>
        <select id="susKind">
          <option value="">Любые</option>
          <option value="impossible_set">Невозможный подход</option>
          <option value="strength_jump">Резкий скачок силы</option>
          <option value="flat_pulse">Ровный пульс</option>
        </select>
        <select id="susDays">
          <option value="7">7 дней</option>
          <option value="30" selected>30 дней</option>
          <option value="90">90 дней</option>
          <option value="365">год</option>
        </select>
        <button id="susReload">Показать</button>
      </div>
      <p class="legend">Нажми на строку — откроется игрок: там «Не жулик» или «Подтвердить блокировку» с заметкой.</p>
      <div class="card"><table id="susTable"></table></div>
    </div>

    <div id="listBox" class="hidden"><h2 id="listTitle"></h2><div class="card"><pre id="list"></pre></div></div>

    <div id="player" class="hidden">
      <h2>Игрок</h2>
      <div class="card"><pre id="cardText"></pre></div>
      <div class="row" style="margin-top:8px">
        <button id="clearSus">Не жулик — разблокировать</button>
        <button class="danger" id="confirmSus">Подтвердить блокировку</button>
      </div>
      <h2>Управление</h2>
      <p class="legend">Каждое действие пишется в журнал. Игрок увидит изменения при следующей синхронизации (до 5 минут или при открытии приложения).</p>
      <div class="card" id="actions"></div>
      <h2>Тренировки</h2>
      <div class="card"><table id="workouts"></table></div>
      <h2>Вещи</h2>
      <p class="legend">Зелёные — уже есть у игрока. Нажми на вещи, чтобы выбрать, потом «Выдать» или «Забрать».</p>
      <div id="groups"></div>
      <div class="bar row">
        <span id="selInfo" class="legend" style="flex:1">Ничего не выбрано</span>
        <button id="clear">Сбросить</button>
        <button class="danger" id="take" disabled>Забрать</button>
        <button class="primary" id="give" disabled>Выдать</button>
      </div>
    </div>
  </div>
</div>
<script>
(function () {
  var $ = function (id) { return document.getElementById(id); };
  var KEY = 'ironrise-admin-token';
  var token = '';
  try { token = sessionStorage.getItem(KEY) || ''; } catch (e) {}
  var groups = null, player = null, selected = new Set();

  function show(text, isErr) {
    var m = $('msg');
    m.textContent = text;
    m.className = 'msg' + (isErr ? ' err' : '');
    m.style.display = text ? 'block' : 'none';
  }

  function api(path, body) {
    return fetch('/v1/admin/api/' + path, {
      method: body ? 'POST' : 'GET',
      headers: Object.assign({ 'X-Admin-Token': token }, body ? { 'Content-Type': 'application/json' } : {}),
      body: body ? JSON.stringify(body) : undefined,
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (data) {
        if (r.status === 401) { logout(); throw new Error('Неверный ключ'); }
        if (!r.ok) throw new Error(Array.isArray(data.message) ? data.message.join(', ') : (data.message || ('Ошибка ' + r.status)));
        return data;
      });
    });
  }

  function enter() {
    token = $('token').value.trim() || token;
    if (!token) return;
    api('items').then(function (g) {
      groups = g;
      try { sessionStorage.setItem(KEY, token); } catch (e) {}
      $('login').classList.add('hidden');
      $('main').classList.remove('hidden');
      $('who').focus();
    }).catch(function (e) { alertLogin(e.message); });
  }

  function alertLogin(text) {
    $('token').value = '';
    $('token').placeholder = text + ' — введите ключ ещё раз';
  }

  function logout() {
    token = '';
    try { sessionStorage.removeItem(KEY); } catch (e) {}
    $('main').classList.add('hidden');
    $('login').classList.remove('hidden');
  }

  function listOut(title, args) {
    show('');
    api('run', { args: args }).then(function (r) {
      $('listTitle').textContent = title;
      $('list').textContent = r.output;
      $('susBox').classList.add('hidden');
      $('listBox').classList.remove('hidden');
    }).catch(function (e) { show(e.message, true); });
  }

  function find(who) {
    who = (who || $('who').value).trim();
    if (!who) return;
    show('');
    api('player?who=' + encodeURIComponent(who)).then(function (p) {
      player = p;
      selected.clear();
      $('susBox').classList.add('hidden');
      $('listBox').classList.add('hidden');
      render();
      renderActions();
      $('statsBox').classList.add('hidden');
      $('player').classList.remove('hidden');
      loadWorkouts(p.nickname);
    }).catch(function (e) { $('player').classList.add('hidden'); show(e.message, true); });
  }

  function cell(tag, text) {
    var el = document.createElement(tag);
    el.textContent = text;
    return el;
  }

  function loadWorkouts(who) {
    var t = $('workouts');
    t.textContent = '';
    api('player/workouts?who=' + encodeURIComponent(who)).then(function (rows) {
      var head = document.createElement('tr');
      ['День', 'Вид', 'Мин', 'Подходы', 'Опыт', 'Часы'].forEach(function (h) { head.appendChild(cell('th', h)); });
      t.appendChild(head);
      if (!rows.length) {
        var empty = document.createElement('tr');
        var td = cell('td', 'Тренировок пока нет');
        td.colSpan = 6;
        empty.appendChild(td);
        t.appendChild(empty);
      }
      rows.forEach(function (w) {
        var tr = document.createElement('tr');
        var kind = w.type === 'strength' ? 'Силовая' : (w.activity === 'recovery' ? 'Восстановление' : 'Кардио');
        [w.day, kind, String(w.minutes), w.type === 'strength' ? String(w.sets) : '—', String(w.xp), w.verified ? '✓' : '—']
          .forEach(function (v) { tr.appendChild(cell('td', v)); });
        t.appendChild(tr);
      });
    }).catch(function (e) { show(e.message, true); });
  }

  var GOAL = { mass: 'Масса', strength: 'Сила', fatLoss: 'Похудеть', endurance: 'Выносливость', consistency: 'Регулярность' };
  var FORMAT = { minimum: 'Минимум', fullBody: 'Всё тело', upperLower: 'Верх/низ', split: 'Сплит', custom: 'Подбери сам' };
  var LEVEL = { novice: 'Новичок', intermediate: 'Средний', advanced: 'Опытный' };

  function stats() {
    show('');
    api('stats').then(function (s) {
      var box = $('statsBox');
      box.textContent = '';
      function section(title) { box.appendChild(cell('h2', title)); }
      function tiles(items) {
        var g = document.createElement('div');
        g.className = 'stats';
        items.forEach(function (it) {
          var d = document.createElement('div');
          d.className = 'stat';
          d.appendChild(cell('b', it[1] === null || it[1] === undefined ? '—' : String(it[1])));
          d.appendChild(cell('span', it[0]));
          g.appendChild(d);
        });
        box.appendChild(g);
      }
      function note(text) { var p = cell('p', text); p.className = 'legend'; box.appendChild(p); }
      section('Игроки');
      tiles([['всего', s.players.total], ['новых за сутки', s.players.new1], ['новых за неделю', s.players.new7],
        ['активны сегодня', s.players.active1], ['за неделю', s.players.active7], ['за месяц', s.players.active30],
        ['удержание новичков, %', s.retention.percent], ['подозрений открыто', s.openSuspicions]]);
      note('Удержание: из ' + s.retention.cohort + ' игроков, зарегистрированных 8–30 дней назад, на этой неделе тренировались ' + s.retention.active + '.');
      section('Тренировки за 14 дней');
      var max = Math.max(1, Math.max.apply(null, s.workoutsPerDay.map(function (d) { return d.strength + d.cardio; })));
      var bars = document.createElement('div');
      bars.className = 'card bars';
      s.workoutsPerDay.forEach(function (d) {
        var col = document.createElement('div');
        col.title = d.day + ': силовых ' + d.strength + ', кардио ' + d.cardio;
        col.appendChild(cell('small', String(d.strength + d.cardio)));
        var c = document.createElement('i');
        c.style.height = (d.cardio / max * 90) + 'px';
        c.style.background = '#5aa9ff';
        var st = document.createElement('i');
        st.style.height = (d.strength / max * 90) + 'px';
        st.style.background = 'var(--accent)';
        col.appendChild(c);
        col.appendChild(st);
        col.appendChild(cell('small', d.day.slice(8)));
        bars.appendChild(col);
      });
      box.appendChild(bars);
      note('Лаймовые — силовые, синие — кардио. Подтверждены часами за неделю: ' + (s.week.verifiedPercent === null ? '—' : s.week.verifiedPercent + '%') + '.');
      section('Экономика за неделю');
      tiles([['тренировок', s.week.workouts], ['монет выдано', s.week.coinsIssued], ['монет потрачено', s.week.coinsSpent]]);
      function dist(title, obj, names) {
        section(title);
        var keys = Object.keys(obj);
        if (!keys.length) { note('Пока нет данных'); return; }
        tiles(keys.map(function (k) { return [names[k] || k, obj[k]]; }));
      }
      dist('Главные цели', s.goals, GOAL);
      dist('Форматы', s.formats, FORMAT);
      dist('Уровни по входной тренировке', s.entryLevels, LEVEL);
      section('Нормы пульса по упражнениям (60 дней)');
      var normsBox = document.createElement('div');
      normsBox.className = 'card';
      box.appendChild(normsBox);
      api('pulse-norms').then(function (rows) {
        if (!rows.length) {
          normsBox.appendChild(cell('p', 'Пока мало данных: норма считается от 20 подходов с пульсом в упражнении.'));
          return;
        }
        var t = document.createElement('table');
        var head = document.createElement('tr');
        ['Упражнение', 'Подходов', 'Пик', 'Отдых', 'Разброс'].forEach(function (h) { head.appendChild(cell('th', h)); });
        t.appendChild(head);
        rows.forEach(function (n) {
          var tr = document.createElement('tr');
          [n.name, String(n.sets), n.peakMedian + ' уд/мин', n.baseMedian === null ? '—' : n.baseMedian + ' уд/мин', '±' + Math.round(n.peakSpread / 2)]
            .forEach(function (v) { tr.appendChild(cell('td', v)); });
          t.appendChild(tr);
        });
        normsBox.appendChild(t);
      }).catch(function (e) { show(e.message, true); });
      $('listBox').classList.add('hidden');
      $('player').classList.add('hidden');
      $('susBox').classList.add('hidden');
      box.classList.remove('hidden');
    }).catch(function (e) { show(e.message, true); });
  }

  function render() {
    $('cardText').textContent = player.card;
    var owned = new Set(player.owned);
    var box = $('groups');
    box.textContent = '';
    groups.forEach(function (g) {
      if (!g.items.length) return;
      var h = document.createElement('h2');
      h.textContent = g.name;
      var chips = document.createElement('div');
      chips.className = 'chips';
      g.items.forEach(function (it) {
        var b = document.createElement('button');
        b.className = 'chip' + (owned.has(it.id) ? ' owned' : '') + (selected.has(it.id) ? ' sel' : '');
        b.textContent = it.id;
        if (it.price) {
          var s = document.createElement('small');
          s.textContent = it.price + ' мон.';
          b.appendChild(s);
        }
        b.onclick = function () {
          if (selected.has(it.id)) selected.delete(it.id); else selected.add(it.id);
          render();
        };
        chips.appendChild(b);
      });
      box.appendChild(h);
      box.appendChild(chips);
    });
    var ids = Array.from(selected);
    var toGive = ids.filter(function (id) { return !owned.has(id); });
    var toTake = ids.filter(function (id) { return owned.has(id); });
    $('selInfo').textContent = ids.length
      ? 'Выбрано: ' + ids.length + ' (выдать ' + toGive.length + ', забрать ' + toTake.length + ')'
      : 'Ничего не выбрано';
    $('give').disabled = !toGive.length;
    $('take').disabled = !toTake.length;
  }

  // Всемогущая панель: команда, поля и подпись. Значения полей идут аргументами
  // после ника игрока — как в консольной админке (commands.ts).
  var PARTS = [['all', 'все части'], ['chest', 'грудь'], ['back', 'спина'], ['arms', 'руки'], ['legs', 'ноги'], ['core', 'пресс'], ['cardio', 'кардио']];
  var AURAS = [['fury', 'Ярость'], ['guard', 'Стойкость'], ['haste', 'Скорость'], ['focus', 'Фокус']];
  var LEAGUES = [['0', 'Бронзовая'], ['1', 'Серебряная'], ['2', 'Золотая'], ['3', 'Платиновая'], ['4', 'Алмазная'], ['5', 'Чемпионская']];
  var ACTIONS = [
    { cmd: 'coins', title: 'Монеты', fields: [{ ph: '±сумма', num: true }, { ph: 'причина' }], go: 'Начислить' },
    { cmd: 'level', title: 'Уровень', fields: [{ opts: PARTS }, { ph: 'уровень', num: true }], go: 'Выставить' },
    { cmd: 'power', title: 'Сила', fields: [{ ph: 'сила ≈', num: true }], go: 'Выставить', note: 'ровно по всем частям' },
    { cmd: 'xp', title: 'Опыт части', fields: [{ opts: PARTS.slice(1) }, { ph: '±опыт', num: true }], go: 'Изменить' },
    { cmd: 'streak', title: 'Серия', fields: [{ ph: 'дней', num: true }], go: 'Выставить' },
    { cmd: 'boosters', title: 'Бустеры', fields: [{ ph: 'опыт, шт', num: true }, { ph: 'монеты, шт', num: true }], go: 'Выставить' },
    { cmd: 'aura', title: 'Аура', fields: [{ opts: AURAS }, { opts: [['0', '0 — закрыть'], ['1', '1'], ['2', '2'], ['3', '3'], ['4', '4'], ['5', '5']] }], go: 'Выставить' },
    { cmd: 'aura-equip', title: 'Надеть ауру', fields: [{ opts: AURAS.concat([['off', 'снять']]) }], go: 'Применить' },
    { cmd: 'aura-reset', title: 'Лимит аур', fields: [], go: 'Сбросить', note: 'можно снова тренировать ауру сегодня' },
    { cmd: 'league', title: 'Лига', fields: [{ opts: LEAGUES }], go: 'Перевести' },
    { cmd: 'season', title: 'Очки сезона', fields: [{ ph: '±очки', num: true }], go: 'Начислить' },
    { cmd: 'premium', title: 'Премиум', fields: [{ ph: 'дней или off' }], go: 'Выдать' },
    { cmd: 'tester', title: 'Тестер', fields: [{ opts: [['', 'выдать статус'], ['off', 'снять']] }], go: 'Применить' },
    { cmd: 'nick', title: 'Ник', fields: [{ ph: 'новый ник' }], go: 'Переименовать' },
    { cmd: 'start-look', title: 'Стартовый образ', fields: [], go: 'Открыть', note: 'снова бесплатный выбор на 14 дней' },
    { cmd: 'duels-reset', title: 'Бои с ботами', fields: [], go: 'Сбросить', note: 'сегодняшние бои и перезарядка' },
    { cmd: 'ban', title: 'Блокировка', fields: [{ ph: 'причина — её увидит игрок' }], go: 'Заблокировать', danger: true },
    { cmd: 'unban', title: 'Разблокировать', fields: [], go: 'Снять блокировку' },
  ];

  function renderActions() {
    var box = $('actions');
    box.textContent = '';
    ACTIONS.forEach(function (a) {
      var row = document.createElement('div');
      row.className = 'row';
      row.style.marginBottom = '6px';
      var label = cell('span', a.title);
      label.style.minWidth = '140px';
      row.appendChild(label);
      var inputs = a.fields.map(function (fd) {
        var el;
        if (fd.opts) {
          el = document.createElement('select');
          fd.opts.forEach(function (o) {
            var op = document.createElement('option');
            op.value = o[0];
            op.textContent = o[1];
            el.appendChild(op);
          });
        } else {
          el = document.createElement('input');
          el.placeholder = fd.ph;
          if (fd.num) { el.inputMode = 'numeric'; el.style.maxWidth = '120px'; }
        }
        row.appendChild(el);
        return el;
      });
      var b = cell('button', a.go);
      if (a.danger) b.className = 'danger';
      b.onclick = function () {
        var values = inputs.map(function (i) { return i.value.trim(); });
        var args = [a.cmd, player.nickname];
        values.forEach(function (v) { if (v !== '') args.push.apply(args, a.cmd === 'nick' || a.cmd === 'ban' || a.cmd === 'coins' ? [v] : v.split(/\s+/)); });
        if (a.fields.some(function (fd, i) { return !fd.opts && !values[i] && fd.ph.indexOf('причина') !== 0; })) {
          show('Заполните поля: ' + a.title, true);
          return;
        }
        if (!confirm(a.title + ' — ' + player.nickname + ': ' + (values.join(' ') || a.go) + '?')) return;
        api('run', { args: args }).then(function (r) {
          show(a.title + ': готово. ' + (r.output || '').split('\n')[0]);
          find(player.nickname);
        }).catch(function (e) { show(e.message, true); });
      };
      row.appendChild(b);
      if (a.note) { var n = cell('small', a.note); n.className = 'legend'; row.appendChild(n); }
      box.appendChild(row);
    });
  }

  var KIND = { impossible_set: 'Невозможный подход', strength_jump: 'Резкий скачок силы', flat_pulse: 'Ровный пульс' };
  var VERDICT = { clear: 'не жулик', confirm: 'подтверждено' };

  function suspicions() {
    show('');
    var q = 'suspicions?status=' + $('susStatus').value + '&kind=' + $('susKind').value + '&days=' + $('susDays').value;
    api(q).then(function (rows) {
      var t = $('susTable');
      t.textContent = '';
      var head = document.createElement('tr');
      ['Когда', 'Игрок', 'Что', 'Тренировка', 'Подробности', 'Блок', 'Решение'].forEach(function (h) { head.appendChild(cell('th', h)); });
      t.appendChild(head);
      if (!rows.length) {
        var tr0 = document.createElement('tr');
        var td0 = cell('td', 'Ничего не найдено');
        td0.colSpan = 7;
        tr0.appendChild(td0);
        t.appendChild(tr0);
      }
      rows.forEach(function (r) {
        var tr = document.createElement('tr');
        tr.style.cursor = 'pointer';
        tr.onclick = function () { $('susBox').classList.add('hidden'); find(r.nickname); };
        var verdict = r.resolvedAt
          ? (VERDICT[r.resolution] || 'разобрано') + ' ' + String(r.resolvedAt).slice(0, 10) + (r.note ? ' — ' + r.note : '')
          : 'ждёт';
        [
          String(r.at).slice(0, 16).replace('T', ' '),
          r.nickname,
          (KIND[r.kind] || r.kind) + (r.severe ? ' !' : ''),
          r.workoutDay ? r.workoutDay + (r.workoutType === 'cardio' ? ' кардио' : ' силовая') : '—',
          JSON.stringify(r.details),
          r.bannedNow ? 'да' : (r.blocked ? 'снят' : '—'),
          verdict,
        ].forEach(function (v) { tr.appendChild(cell('td', v)); });
        t.appendChild(tr);
      });
      $('listBox').classList.add('hidden');
      $('player').classList.add('hidden');
      $('statsBox').classList.add('hidden');
      $('susBox').classList.remove('hidden');
    }).catch(function (e) { show(e.message, true); });
  }

  function change(cmd) {
    var owned = new Set(player.owned);
    var ids = Array.from(selected).filter(function (id) { return cmd === 'give' ? !owned.has(id) : owned.has(id); });
    if (!ids.length) return;
    var verb = cmd === 'give' ? 'Выдать' : 'Забрать у';
    if (!confirm(verb + ' ' + player.nickname + ': ' + ids.join(', ') + '?')) return;
    api('run', { args: [cmd, player.nickname].concat(ids) }).then(function () {
      show((cmd === 'give' ? 'Выдано: ' : 'Забрано: ') + ids.join(', ') + '. Игрок увидит при следующей синхронизации приложения.');
      find(player.nickname);
    }).catch(function (e) { show(e.message, true); });
  }

  $('enter').onclick = enter;
  $('token').onkeydown = function (e) { if (e.key === 'Enter') enter(); };
  $('find').onclick = function () { find(); };
  $('who').onkeydown = function (e) { if (e.key === 'Enter') find(); };
  $('recent').onclick = function () { listOut('Последние зарегистрированные', ['list', '30']); };
  $('history').onclick = function () { listOut('Журнал действий', ['history', '30']); };
  $('statsBtn').onclick = stats;
  $('suspects').onclick = suspicions;
  $('susReload').onclick = suspicions;
  function verdict(cmd, text) {
    if (!player || !confirm(text + ' — ' + player.nickname + '?')) return;
    // Заметка попадёт в журнал античита («почему так решил»); при подтверждении — и в причину блокировки.
    var note = (prompt('Заметка к решению (можно пусто)') || '').trim();
    var args = [cmd, player.nickname];
    if (note) args.push(note);
    api('run', { args: args }).then(function () {
      show(cmd === 'clear' ? 'Подозрения закрыты, блокировка снята' : 'Блокировка подтверждена');
      find(player.nickname);
    }).catch(function (e) { show(e.message, true); });
  }
  $('clearSus').onclick = function () { verdict('clear', 'Не жулик: закрыть подозрения и снять блокировку'); };
  $('confirmSus').onclick = function () { verdict('confirm', 'Подтвердить блокировку'); };
  $('logout').onclick = logout;
  $('clear').onclick = function () { selected.clear(); render(); };
  $('give').onclick = function () { change('give'); };
  $('take').onclick = function () { change('take'); };
  if (token) enter();
})();
</script>
</body>
</html>`;
