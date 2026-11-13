﻿# Админка: управление аккаунтами игроков на сервере.
# Сначала выбираешь игрока, потом действие по номеру. Команды выполняются внутри
# контейнера API (на VPS — по SSH), снаружи по сети их нет. Всё пишется в журнал.
. "$PSScriptRoot\config.ps1"

$target = Read-Host 'Сервер: Enter — основной (VPS), d — DEV на этом компьютере'
$dev = $target.Trim().ToLower() -in @('d', 'д')
$where = if ($dev) { 'DEV' } else { 'ОСНОВНОЙ' }

function Admin([string[]]$Words) {
  if ($dev) {
    docker exec server-api-1 node dist/admin/admin.js @Words
  } else {
    $line = ($Words | ForEach-Object { Q $_ }) -join ' '
    Invoke-Remote "docker exec ironrise-api-1 node dist/admin/admin.js $line"
  }
}

# Аргумент в одинарных кавычках для bash (ники и причины с пробелами).
function Q([string]$s) { "'" + ($s -replace "'", "'\''") + "'" }

# На основном сервере изменения подтверждаем.
function Change([string[]]$Words) {
  if (-not $dev -and -not (Ask "Изменить на ОСНОВНОМ сервере: $($Words -join ' ') ?")) { return }
  Admin $Words
}

function Pick-Player {
  while ($true) {
    $who = (Read-Host "`n[$where] Игрок: ник или e-mail (l — последние, h — журнал, i — вещи, Enter — выход)").Trim()
    switch ($who.ToLower()) {
      '' { return $null }
      { $_ -in 'l', 'д' } { Admin @('list', '30'); continue }
      { $_ -in 'h', 'р' } { Admin @('history', '30'); continue }
      { $_ -in 'i', 'ш' } { Admin @('items'); continue }
      default {
        Admin @('find', $who)
        if ($LASTEXITCODE -eq 0) { return $who }
      }
    }
  }
}

$menu = @'
  1  Монеты: начислить или списать
  2  Выдать вещи
  3  Забрать вещи
  4  Опыт части тела
  5  Серия
  6  Бустеры серии
  7  Переименовать
  8  Премиум
  9  Статус тестера (вкл/выкл)
  10 Сбросить бои с ботами за сегодня
  11 Заблокировать
  12 Разблокировать
  Enter — другой игрок
'@

while ($who = Pick-Player) {
  while ($true) {
    Write-Host "`n[$where] Игрок: $who" -ForegroundColor Cyan
    Write-Host $menu
    $choice = (Read-Host 'Действие').Trim()
    if (-not $choice) { break }
    switch ($choice) {
      '1' { $n = Read-Host 'Сколько (минус — списать)'; $why = Read-Host 'Причина'; Change @('coins', $who, $n, $why) }
      '2' { Admin @('items'); $ids = Read-Host 'id вещей через пробел'; Change (@('give', $who) + ($ids -split '\s+' | Where-Object { $_ })) }
      '3' { $ids = Read-Host 'id вещей через пробел'; Change (@('take', $who) + ($ids -split '\s+' | Where-Object { $_ })) }
      '4' { $part = Read-Host 'Часть: chest back arms legs core cardio'; $n = Read-Host 'Сколько опыта (минус — убрать)'; Change @('xp', $who, $part, $n) }
      '5' { $n = Read-Host 'Серия, дней'; Change @('streak', $who, $n) }
      '6' { $x = Read-Host 'Бустеров опыта'; $c = Read-Host 'Бустеров монет'; Change @('boosters', $who, $x, $c) }
      '7' {
        $nick = Read-Host 'Новый ник'
        Change @('nick', $who, $nick)
        if ($LASTEXITCODE -eq 0) { $who = $nick }
      }
      '8' { $d = Read-Host 'Дней премиума (off — снять)'; Change @('premium', $who, $d) }
      '9' { $off = Ask 'Снять статус тестера?'; Change (@('tester', $who) + $(if ($off) { @('off') } else { @() })) }
      '10' { Change @('duels-reset', $who) }
      '11' { $why = Read-Host 'Причина (её увидит игрок)'; Change @('ban', $who, $why) }
      '12' { Change @('unban', $who) }
      default { Write-Host 'Нет такого пункта' -ForegroundColor Yellow }
    }
  }
}
