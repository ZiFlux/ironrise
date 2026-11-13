package com.ironrise.ironrise

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Виджет на рабочем столе: серия, что сегодня (тренировка, отдых, сделано)
 * и уровень героя. Данные публикует приложение (MainActivity, канал «ironrise/summary»).
 */
class SummaryWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, views(context))
    }

    companion object {
        const val PREFS = "ironrise_summary"

        /** Перерисовать все виджеты после новых данных. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, SummaryWidget::class.java))
            for (id in ids) manager.updateAppWidget(id, views(context))
        }

        private fun views(context: Context): RemoteViews {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE,
            )
            return RemoteViews(context.packageName, R.layout.widget_summary).apply {
                setTextViewText(R.id.widget_streak, p.getInt("streak", 0).toString())
                setTextViewText(R.id.widget_today, p.getString("today", "Открой IronRise"))
                setTextViewText(R.id.widget_level, p.getString("level", ""))
                setOnClickPendingIntent(R.id.widget_root, open)
            }
        }
    }
}
