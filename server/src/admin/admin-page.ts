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
        <button id="suspects">Подозрительные</button>
        <button id="logout">Выйти</button>
      </div>
    </div>
    <div id="msg" class="msg"></div>

    <div id="listBox" class="hidden"><h2 id="listTitle"></h2><div class="card"><pre id="list"></pre></div></div>

    <div id="player" class="hidden">
      <h2>Игрок</h2>
      <div class="card"><pre id="cardText"></pre></div>
      <div class="row" style="margin-top:8px">
        <button id="clearSus">Не жулик — разблокировать</button>
        <button class="danger" id="confirmSus">Подтвердить блокировку</button>
      </div>
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
      $('listBox').classList.add('hidden');
      render();
      $('player').classList.remove('hidden');
    }).catch(function (e) { $('player').classList.add('hidden'); show(e.message, true); });
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
  $('suspects').onclick = function () { listOut('Подозрения античита — не разобранные', ['suspects']); };
  function verdict(cmd, text) {
    if (!player || !confirm(text + ' — ' + player.nickname + '?')) return;
    api('run', { args: [cmd, player.nickname] }).then(function () {
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
