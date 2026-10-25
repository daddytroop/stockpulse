package app.stockpulse

import android.appwidget.AppWidgetProvider
import android.content.Context
import android.appwidget.AppWidgetManager
import android.widget.RemoteViews

/// Main home-screen widget: portfolio value, daily change and the next
/// upcoming dividend. Rendering + data come from [WidgetRenderer]; the
/// background worker can refresh this widget without the app running.
class PortfolioWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val views = WidgetRenderer.renderPortfolio(context)
        views.setOnClickPendingIntent(R.id.widget_root, MainActivityIntents.open(context))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}