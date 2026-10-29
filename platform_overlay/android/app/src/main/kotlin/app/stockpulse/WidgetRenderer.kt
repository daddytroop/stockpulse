package app.stockpulse

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.BitmapFactory
import android.widget.RemoteViews

/// Shared RemoteViews rendering for both widgets, used by the providers
/// AND by the background worker so visuals stay identical.
object WidgetRenderer {

    /// The shared-preferences file the home_widget plugin writes to.
    /// It has to match `HomeWidgetPlugin.PREFERENCES` exactly, otherwise
    /// the widget reads an empty file and shows placeholder text.
    const val PREFS_KEY = "HomeWidgetPreferences"

    /// The key the rendered trend line is stored under.
    const val SPARKLINE_KEY = "widget_sparkline"

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
        views.setTextViewText(R.id.widget_meta, prefs.getString("widget_meta", ""))
        views.setTextViewText(
            R.id.widget_next,
            prefs.getString("widget_next", "Open Stock Pulse to refresh data")
        )
        views.setTextViewText(R.id.widget_next_amount, prefs.getString("widget_next_amount", ""))

        // The trend line is rendered by the app and stored as a small PNG.
        val spark = prefs.getString(SPARKLINE_KEY, null)
        if (!spark.isNullOrEmpty()) {
            try {
                val bitmap = BitmapFactory.decodeFile(spark)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_sparkline, bitmap)
                }
            } catch (_: Exception) {
                // A missing trend line just leaves the space empty.
            }
        }
        return views
    }

    fun renderNextDividend(context: Context): RemoteViews {
        val prefs = prefs(context)
        val views = RemoteViews(context.packageName, R.layout.widget_next_dividend)
        views.setTextViewText(R.id.nd_title, context.getString(R.string.widget_next_dividend_title))
        views.setTextViewText(R.id.nd_symbol, prefs.getString("nd_symbol", "No dividends"))
        views.setTextViewText(R.id.nd_amount, prefs.getString("nd_amount", ""))
        views.setTextViewText(R.id.nd_when, prefs.getString("nd_when", ""))
        views.setTextViewText(R.id.nd_ex, prefs.getString("nd_ex", ""))
        views.setTextViewText(R.id.nd_paid, prefs.getString("nd_paid", ""))
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
