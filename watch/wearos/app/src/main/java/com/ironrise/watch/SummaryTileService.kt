package com.ironrise.watch

import android.content.Context
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.dp
import androidx.wear.protolayout.DimensionBuilders.sp
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * Плитка IronRise на часах: серия, что сегодня и уровень героя. Данные присылает
 * телефон (PhoneCommandService.onDataChanged), нажатие открывает приложение.
 */
class SummaryTileService : TileService() {

    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val summary = Summary.read(this)
        val open = ModifiersBuilders.Clickable.Builder()
            .setId("open")
            .setOnClick(
                ActionBuilders.LaunchAction.Builder()
                    .setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(packageName)
                            .setClassName(MainActivity::class.java.name)
                            .build(),
                    )
                    .build(),
            )
            .build()
        val column = LayoutElementBuilders.Column.Builder()
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setModifiers(ModifiersBuilders.Modifiers.Builder().setClickable(open).build())
            .addContent(text("${summary.streak}", 40f, ORANGE, bold = true))
            .addContent(text("дней серии", 12f, MUTED))
            .addContent(LayoutElementBuilders.Spacer.Builder().setHeight(dp(8f)).build())
            .addContent(text(summary.today, 14f, PRIMARY))
            .addContent(text(summary.level, 12f, ACCENT))
            .apply {
                // Статус надетой ауры (п. 83): горит — её цветом, тухнет — приглушённо.
                val aura = Auras.of(summary.aura)
                when {
                    aura == null || summary.auraState.isEmpty() -> Unit
                    summary.auraState == "on" -> addContent(text("${aura.name} горит", 12f, aura.main))
                    else -> addContent(text("${aura.name} тухнет — потренируй", 12f, MUTED))
                }
            }
            .build()
        val layout = LayoutElementBuilders.Layout.Builder()
            .setRoot(
                LayoutElementBuilders.Box.Builder()
                    .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
                    .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
                    .addContent(column)
                    .build(),
            )
            .build()
        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setTileTimeline(TimelineBuilders.Timeline.fromLayoutElement(layout.root!!))
            // Раз в час — на случай, если телефон долго молчит (день сменился).
            .setFreshnessIntervalMillis(60 * 60 * 1000L)
            .build()
        return Futures.immediateFuture(tile)
    }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest,
    ): ListenableFuture<ResourceBuilders.Resources> =
        Futures.immediateFuture(ResourceBuilders.Resources.Builder().setVersion(RESOURCES_VERSION).build())

    private fun text(value: String, size: Float, color: Int, bold: Boolean = false) =
        LayoutElementBuilders.Text.Builder()
            .setText(value)
            .setMaxLines(2)
            .setMultilineAlignment(LayoutElementBuilders.TEXT_ALIGN_CENTER)
            .setFontStyle(
                LayoutElementBuilders.FontStyle.Builder()
                    .setSize(sp(size))
                    .setColor(argb(color))
                    .setWeight(
                        if (bold) LayoutElementBuilders.FONT_WEIGHT_BOLD else LayoutElementBuilders.FONT_WEIGHT_NORMAL,
                    )
                    .build(),
            )
            .build()

    private companion object {
        const val RESOURCES_VERSION = "1"
        const val ORANGE = 0xFFFF8A3D.toInt()
        const val PRIMARY = 0xFFEDEDED.toInt()
        const val MUTED = 0xFF85858B.toInt()
        const val ACCENT = 0xFFC6FF3D.toInt()
    }
}

/** Сводка от телефона: хранится на часах до следующего обновления. */
/** [aura] — id надетой ауры с телефона; пусто — ауры нет (или телефон старый). */
data class Summary(
    val streak: Int,
    val today: String,
    val level: String,
    val aura: String = "",
    /** «on» — горит (тренировалась на неделе), «fading» — тухнет; пусто — не знаем. */
    val auraState: String = "",
) {
    companion object {
        const val PREFS = "summary"

        fun read(context: Context): Summary {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return Summary(
                streak = p.getInt("streak", 0),
                today = p.getString("today", null) ?: "Открой IronRise на телефоне",
                level = p.getString("level", null) ?: "",
                aura = p.getString("aura", null) ?: "",
                auraState = p.getString("auraState", null) ?: "",
            )
        }

        fun save(context: Context, summary: Summary) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putInt("streak", summary.streak)
                .putString("today", summary.today)
                .putString("level", summary.level)
                .putString("aura", summary.aura)
                .putString("auraState", summary.auraState)
                .apply()
        }
    }
}
