package app.stockpulse

import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/// Pending intent that opens the app when a widget is tapped.
object MainActivityIntents {
    fun open(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
}