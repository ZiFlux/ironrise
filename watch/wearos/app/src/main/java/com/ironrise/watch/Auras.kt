package com.ironrise.watch

import android.graphics.Color

/**
 * Ауры, которые эти часы умеют рисовать. id — как AuraKind на телефоне
 * (app/lib/game/aura.dart). Телефон шлёт id надетой ауры в сводке; если id
 * здесь нет (аура новее часов) — эффект просто не рисуется, остальное работает.
 */
enum class AuraStyle {
    /** Пламя: неровное мерцание. */
    FLAME,

    /** Щит: ровное «дыхание», без вращения. */
    SHIELD,

    /** Молнии: быстрые рваные сегменты по кругу. */
    LIGHTNING,

    /** Фокус: медленное плавное вращение. */
    FLOW,
}

data class WatchAura(val id: String, val name: String, val main: Int, val light: Int, val style: AuraStyle)

object Auras {
    private val all = listOf(
        WatchAura("fury", "Ярость", Color.parseColor("#FF5A1F"), Color.parseColor("#FFC23D"), AuraStyle.FLAME),
        WatchAura("guard", "Стойкость", Color.parseColor("#FFB23D"), Color.parseColor("#FFF0B8"), AuraStyle.SHIELD),
        WatchAura("haste", "Скорость", Color.parseColor("#2E8BFF"), Color.parseColor("#D6F0FF"), AuraStyle.LIGHTNING),
        WatchAura("focus", "Фокус", Color.parseColor("#9B5CF6"), Color.parseColor("#E2C8FF"), AuraStyle.FLOW),
    ).associateBy { it.id }

    /** null — ауры нет или эти часы её не знают: без эффекта. */
    fun of(id: String?): WatchAura? = id?.let { all[it] }

    /** Для ответа телефону: какие ауры часы рисуют. */
    val ids: Collection<String> get() = all.keys
}

/**
 * Версия протокола часы ↔ телефон. Меняется только при новых возможностях;
 * старые сообщения остаются прежними, поэтому любые версии приложений совместимы.
 */
/** 3 — вспышка ауры в дуэли и статус «горит / тухнет» на плитке (п. 83). */
const val WATCH_PROTOCOL = 3
