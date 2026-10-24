package app.stockpulse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/// Main home-screen widget: portfolio value, daily change and the next
/// upcoming dividend. Data is written from the Dart side via the
/// `home_widget` plugin into the "HomeWidgetPlugin" SharedPreferences.
class PortfolioWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_KEY = "HomeWidgetPlugin"
        private val GREEN = 0xFF66BB6A.toInt()
        private val RED = 0xFFEF5350.toInt()
        private val GREY = 0xFF8D8D8D.toInt()
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_KEY, Context.MODE_PRIVATE)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_portfolio)

            views.setTextViewText(R.id.widget_title, context.getString(R.string.widget_portfolio_name))
            views.setTextViewText(R.id.widget_value, prefs.getString("widget_total", "--"))
            views.setTextViewText(R.id.widget_change, prefs.getString("widget_change", ""))

            val sign = prefs.getInt("widget_change_sign", 0)
            views.setTextColor(
                R.id.widget_change,
                when (sign) {
                    1 -> GREEN
                    -1 -> RED
                    else -> GREY
                }
            )

            views.setTextViewText(
                R.id.widget_next,
                prefs.getString("nd_line1", "Open Stock Pulse to refresh data")
            )
            views.setTextViewText(R.id.widget_next_sub, prefs.getString("nd_line2", ""))

            val tap = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, tap)

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}