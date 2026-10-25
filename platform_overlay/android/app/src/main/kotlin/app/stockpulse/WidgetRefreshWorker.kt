package app.stockpulse

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import kotlin.math.abs

/// Periodic background job: fetches prices for held symbols straight from
/// Yahoo's no-crumb chart endpoint, refreshes both widgets, and fires local
/// notifications for:
///  * price moves >= the user's alert threshold,
///  * a dividend ex-date / payment landing today,
///  * earnings landing today.
///
/// All inputs (positions, FX rates, alert settings, dates) are written by the
/// Flutter app into the HomeWidgetPlugin SharedPreferences as small JSON
/// strings, so the worker never needs Flutter or a crumb handshake.
class WidgetRefreshWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    companion object {
        private const val UA =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        private const val CHANNEL = "stockpulse_alerts"
    }

    override suspend fun doWork(): Result {
        return try {
            refreshWidgetsAndAlerts()
            Result.success()
        } catch (_: Exception) {
            Result.success() // soft-fail; next scheduled run retries anyway
        }
    }

    private suspend fun refreshWidgetsAndAlerts() {
        val context = applicationContext
        val prefs = WidgetRenderer.prefs(context)
        val symbolsJson = prefs.getString("bg_symbols", null) ?: return
        val symbols = JSONArray(symbolsJson)
        if (symbols.length() == 0) return

        val display = prefs.getString("bg_display", "") ?: ""
        val rates = prefs.getString("bg_rates", "{}")?.let {
            runCatching { JSONObject(it) }.getOrDefault(JSONObject())
        } ?: JSONObject()

        var total = 0.0
        var prevTotal = 0.0
        var fetched = 0

        for (i in 0 until symbols.length()) {
            val item = symbols.getJSONObject(i)
            val symbol = item.getString("s")
            val qty = item.getDouble("q")
            val cur = item.optString("cur", "USD")

            val closes = fetchLastTwoCloses(symbol) ?: continue
            fetched++

            val fx = if (display.isNotEmpty() && cur != display) {
                rates.optDouble(cur, 1.0)
            } else 1.0

            total += (closes[0]) * qty * fx
            prevTotal += (closes[1]) * qty * fx

            Thread.sleep(120)
        }
        if (fetched == 0) return

        val change = total - prevTotal
        val changePct = if (prevTotal > 0) change / prevTotal * 100 else 0.0

        prefs.edit()
            .putString("widget_total", formatMoney(total, display))
            .putString("widget_change", formatChange(change, changePct, display))
            .putInt(
                "widget_change_sign",
                if (change > 0) 1 else if (change < 0) -1 else 0
            )
            .putString("bg_last_run", System.currentTimeMillis().toString())
            .apply()
        WidgetRenderer.updateAll(context)

        // ---- alerts ----
        val alerts = prefs.getString("bg_alerts", null)?.let {
            runCatching { JSONObject(it) }.getOrDefault(JSONObject())
        } ?: JSONObject() // {"AAPL": 5.0}
        for (key in alerts.keys()) {
            val threshold = alerts.optDouble(key, 0.0)
            if (threshold <= 0) continue
            val item = findSymbol(symbols, key) ?: continue
            val closes = fetchLastTwoCloses(key) ?: continue
            val pct = (closes[0] - closes[1]) / closes[1] * 100.0
            if (abs(pct) >= threshold) {
                notifyOnce(
                    context,
                    "pricemove:$key:${todayKey()}",
                    "${item.optString("name", key)} ${pct.toPercentString()} today",
                    "Price moved ${pct.toPercentString()} "
                        + "(now ${formatMoney(closes[0], item.optString("cur", "USD"))})."
                )
            }
            Thread.sleep(120)
        }

        // Dividend landing today?
        val nextDiv = prefs.getString("bg_next_div", null)?.let {
            runCatching { JSONObject(it) }.getOrNull()
        }
        if (nextDiv != null) {
            val ms = nextDiv.optLong("exMs", 0)
            if (ms > 0 && sameDay(ms)) {
                notifyOnce(
                    context,
                    "dividend:${nextDiv.optString("s")}:${todayKey()}",
                    "${nextDiv.optString("s")} dividend today",
                    "Ex-dividend is today - payment follows shortly after. "
                        + "Open Stock Pulse for the calendar."
                )
            }
        }

        // Earnings today?
        val earnings = prefs.getString("bg_earnings", null)?.let {
            runCatching { JSONObject(it) }.getOrDefault(JSONObject())
        } ?: JSONObject() // {"AAPL": 1793649600}
        for (key in earnings.keys()) {
            val ms = earnings.optLong(key, 0)
            if (ms > 0 && sameDay(ms)) {
                notifyOnce(
                    context,
                    "earnings:$key:${todayKey()}",
                    "$key reports earnings today",
                    "Open Stock Pulse for the event calendar."
                )
            }
        }
    }

    // ------------------------------------------------------------------------
    // Network
    // ------------------------------------------------------------------------

    private fun fetchLastTwoCloses(symbol: String): DoubleArray? {
        val conn = try {
            val url = URL(
                "https://query1.finance.yahoo.com/v8/finance/chart/" +
                    URLEncoder.encode(symbol, "UTF-8") +
                    "?interval=1d&range=5d"
            )
            url.openConnection() as HttpURLConnection
        } catch (_: Exception) {
            return null
        }
        conn.connectTimeout = 8000
        conn.readTimeout = 8000
        conn.setRequestProperty("User-Agent", UA)
        try {
            if (conn.responseCode != 200) return null
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            val result = JSONObject(body).getJSONArray("result")
                .getJSONObject(0)
            val closes = result.getJSONObject("indicators")
                .getJSONArray("quote").getJSONObject(0)
                .getJSONArray("close")
            val valid = ArrayList<Double>(closes.length())
            for (i in 0 until closes.length()) {
                if (closes.isNull(i)) continue
                val c = closes.getDouble(i)
                if (c > 0) valid.add(c)
            }
            if (valid.size < 2) return null
            return doubleArrayOf(valid[valid.size - 1], valid[valid.size - 2])
        } catch (_: Exception) {
            return null
        } finally {
            conn.disconnect()
        }
    }

    // ------------------------------------------------------------------------
    // Notifications
    // ------------------------------------------------------------------------

    private fun notifyOnce(context: Context, id: String, title: String, text: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = androidx.core.app.NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(
                androidx.core.app.NotificationCompat.BigTextStyle().bigText(text)
            )
            .setAutoCancel(true)
            .build()
        val nid = (id.hashCode() and 0x7fffffff)
        runCatching { nm.notify(nid, notification) }
    }

    // ------------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------------

    private fun findSymbol(symbols: JSONArray, key: String): JSONObject? {
        for (i in 0 until symbols.length()) {
            val o = symbols.getJSONObject(i)
            if (o.optString("s") == key) return o
        }
        return null
    }

    private fun formatMoney(v: Double, currency: String?): String {
        val nf = NumberFormat.getCurrencyInstance(Locale.US)
        if (!currency.isNullOrEmpty() && currency != "XX") {
            runCatching { nf.currency = java.util.Currency.getInstance(currency) }
        }
        return runCatching { nf.format(v) }.getOrDefault(v.toString())
    }

    private fun formatChange(change: Double, pct: Double, currency: String?): String {
        val sign = if (change >= 0) "+" else "-"
        val body = formatMoney(abs(change), currency).removePrefix("+")
        return "$sign$body (${sign}${abs(pct).toFormattedDecimal(2)}%)"
    }

    private fun sameDay(ms: Long): Boolean {
        val d = Instant.ofEpochMilli(ms).atZone(ZoneId.systemDefault()).toLocalDate()
        return d == LocalDate.now()
    }

    private fun todayKey(): String = LocalDate.now().toString()
}

private fun Double.toPercentString(): String =
    (if (this >= 0) "+" else "") + String.format(Locale.US, "%.2f%%", this)

private fun Double.toFormattedDecimal(places: Int): String =
    String.format(Locale.US, "%.${places}f", this)