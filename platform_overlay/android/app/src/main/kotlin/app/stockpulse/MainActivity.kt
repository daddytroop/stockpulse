package app.stockpulse

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterFragmentActivity
import java.util.concurrent.TimeUnit

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            createNotificationChannels()
            scheduleBackgroundRefresh()
            askNotificationPermission()
        } catch (_: Exception) {
            // never block app startup on background-setup problems
        }
    }

    private fun createNotificationChannels() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val alerts = NotificationChannel(
            "stockpulse_alerts",
            "Market alerts",
            NotificationManager.IMPORTANCE_DEFAULT
        )
        alerts.description = "Dividend, earnings and price-move alerts"
        nm.createNotificationChannel(alerts)
    }

    private fun scheduleBackgroundRefresh() {
        val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(1, TimeUnit.HOURS)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
            )
            .addTag("stockpulse")
            .build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "stockpulse_widget_refresh",
            ExistingPeriodicWorkPolicy.KEEP,
            request
        )
    }

    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33) {
            if (ContextCompat.checkSelfPermission(
                    this, "android.permission.POST_NOTIFICATIONS"
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                try {
                    requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 4242)
                } catch (_: Exception) {
                }
            }
        }
    }
}