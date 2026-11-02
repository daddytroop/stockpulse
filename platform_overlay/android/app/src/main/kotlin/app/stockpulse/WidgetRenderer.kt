package app.stockpulse

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.widget.RemoteViews
import org.json.JSONArray

/// Shared RemoteViews rendering for both widgets, used by the providers
/// AND by the background worker so visuals stay identical.
object WidgetRenderer {

    /// The shared-preferences file the home_widget plugin writes to.
    /// It has to match `HomeWidgetPlugin.PREFERENCES` exactly, otherwise
    /// the widget reads an empty file and shows placeholder text.
    const val PREFS_KEY = "HomeWidgetPreferences"

    /// The key the trend values (a JSON list of numbers) are stored under.
    const val SPARKLINE_POINTS_KEY = "widget_spark_points"

    val LINE_UP = 0xFF64EFAE.toInt()
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

        // The app stores the trend as a JSON list of values; it is drawn
        // here so it never depends on an off-screen Flutter render.
        try {
            val raw = prefs.getString(SPARKLINE_POINTS_KEY, null)
            if (!raw.isNullOrEmpty()) {
                val arr = JSONArray(raw)
                val values = DoubleArray(arr.length()) { arr.optDouble(it, Double.NaN) }
                    .filter { !it.isNaN() }
                drawSparkline(context, values)?.let {
                    views.setImageViewBitmap(R.id.widget_sparkline, it)
                }
            }
        } catch (_: Exception) {
            // A missing trend line just leaves the space empty.
        }
        return views
    }

    /// Draws [values] as a smooth line with a soft fill, sized for the
    /// widget's trend strip. Green when the period ended up, red when down.
    private fun drawSparkline(context: Context, values: List<Double>): Bitmap? {
        if (values.size < 2) return null
        val density = context.resources.displayMetrics.density
        val w = (280 * density).toInt().coerceAtLeast(1)
        val h = (48 * density).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val min = values.min()
        val max = values.max()
        val span = max - min
        val pad = h * 0.15f
        val usable = h - pad * 2
        fun x(i: Int) = w * (i.toFloat() / (values.size - 1))
        fun y(v: Double) =
            if (span <= 0) h / 2f else (pad + usable - ((v - min) / span * usable)).toFloat()

        val line = Path()
        values.forEachIndexed { i, v ->
            if (i == 0) line.moveTo(x(i), y(v)) else line.lineTo(x(i), y(v))
        }
        val color = if (values.last() >= values.first()) LINE_UP else RED

        val fill = Path(line).apply {
            lineTo(w.toFloat(), h.toFloat())
            lineTo(0f, h.toFloat())
            close()
        }
        canvas.drawPath(fill, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            shader = LinearGradient(
                0f, 0f, 0f, h.toFloat(),
                (color and 0x00FFFFFF) or 0x40000000, color and 0x00FFFFFF,
                Shader.TileMode.CLAMP
            )
        })
        canvas.drawPath(line, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 2f * density
            strokeJoin = Paint.Join.ROUND
            strokeCap = Paint.Cap.ROUND
            this.color = color
        })
        return bitmap
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
