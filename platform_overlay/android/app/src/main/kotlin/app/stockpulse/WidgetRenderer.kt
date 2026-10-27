package app.stockpulse

import android.content.ComponentName
import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews

/// Shared RemoteViews rendering for both widgets, used by the providers
/// AND by the background worker so visuals stay identical.
object WidgetRenderer {

    const val PREFS_KEY = "HomeWidgetPlugin"

    val GREEN = 0xFF66BB6A.toInt()
    val RED = 0xFFEF5350.toInt()
    val GREY = 0xFF8D8D8D.toInt()

    fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_KEY, Context.MODE_PRIVATE)

    fun renderPortfolio(context: Context): RemoteViews {
        val prefs = prefs(context)
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
        views.setTextViewText(
            R.id.widget_meta,
            prefs.getString("widget_meta", "")
        )
        return views
    }

    fun renderNextDividend(context: Context): RemoteViews {
        val prefs = prefs(context)
        val views = RemoteViews(context.packageName, R.layout.widget_next_dividend)
        views.setTextViewText(R.id.nd_title, context.getString(R.string.widget_next_dividend_title))
        views.setTextViewText(R.id.nd_symbol, prefs.getString("nd_symbol", "No dividends"))
        views.setTextViewText(R.id.nd_amount, prefs.getString("nd_amount", ""))
        views.setTextViewText(R.id.nd_when, prefs.getString("nd_when", ""))
        views.setTextViewText(R.id.nd_line2, prefs.getString("nd_line2", ""))
        return views
    }

    /// Writes the freshly rendered views to every instance of both widgets.
    fun updateAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context) ?: return
        val portfolio = renderPortfolio(context)
        val next = renderNextDividend(context)
        val openTap = MainActivityIntents.open(context)

        portfolio.setOnClickPendingIntent(R.id.widget_root, openTap)
        next.setOnClickPendingIntent(R.id.nd_root, openTap)

        for (provider in listOf(
            PortfolioWidgetProvider::class.java,
            NextDividendWidgetProvider::class.java
        )) {
            val ids = mgr.getAppWidgetIds(ComponentName(context, provider))
            if (ids.isEmpty()) continue
            for (id in ids) {
                val views = if (provider == PortfolioWidgetProvider::class.java) portfolio else next
                mgr.updateAppWidget(id, views)
            }
        }
    }
}