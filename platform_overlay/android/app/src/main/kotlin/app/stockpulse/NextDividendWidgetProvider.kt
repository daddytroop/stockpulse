package app.stockpulse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/// Small widget: the next upcoming dividend payment.
class NextDividendWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_KEY = "HomeWidgetPlugin"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_KEY, Context.MODE_PRIVATE)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_next_dividend)

            views.setTextViewText(R.id.nd_title, context.getString(R.string.widget_next_dividend_title))
            views.setTextViewText(R.id.nd_line1, prefs.getString("nd_line1", "No upcoming dividends"))
            views.setTextViewText(R.id.nd_line2, prefs.getString("nd_line2", ""))

            val tap = PendingIntent.getActivity(
                context,
                1,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.nd_root, tap)

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}