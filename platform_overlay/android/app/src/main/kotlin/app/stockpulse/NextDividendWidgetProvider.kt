package app.stockpulse

import android.appwidget.AppWidgetProvider
import android.content.Context
import android.appwidget.AppWidgetManager
import android.widget.RemoteViews

/// Small widget: the next upcoming dividend payment.
class NextDividendWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val views = WidgetRenderer.renderNextDividend(context)
        views.setOnClickPendingIntent(R.id.nd_root, MainActivityIntents.open(context))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}