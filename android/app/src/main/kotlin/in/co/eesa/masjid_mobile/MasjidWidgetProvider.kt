package `in`.co.eesa.masjid_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale

/**
 * Home-screen widget showing the nearest masjid + next prayer + countdown.
 *
 * Data is read from "FlutterSharedPreferences" — the same store the
 * Flutter side writes to via shared_preferences. The Flutter app is the
 * source of truth; the widget never makes its own network call.
 */
class MasjidWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        updateAll(context, manager, appWidgetIds)
    }

    companion object {
        // shared_preferences plugin stores Strings under this XML file with a
        // "flutter." key prefix.
        private const val PREF_FILE = "FlutterSharedPreferences"
        private const val P = "flutter."

        fun updateAll(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            val masjidName = prefs.getString(P + "widget_masjid_name", null) ?: "Masjid Timings"
            val masjidArea = prefs.getString(P + "widget_masjid_area", null) ?: ""
            val nextPrayer = prefs.getString(P + "widget_next_prayer", null)
            val nextTime   = prefs.getString(P + "widget_next_time", null)
            val updatedAt  = prefs.getString(P + "widget_updated_at", null)

            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.masjid_widget)
                views.setTextViewText(R.id.w_masjid_name, masjidName)
                views.setTextViewText(R.id.w_masjid_area, masjidArea)

                if (nextPrayer != null && nextTime != null) {
                    views.setTextViewText(R.id.w_prayer_name, displayName(nextPrayer))
                    views.setTextViewText(R.id.w_prayer_time, nextTime)
                    views.setTextViewText(R.id.w_countdown, countdownText(nextTime))
                } else {
                    views.setTextViewText(R.id.w_prayer_name, "Open app")
                    views.setTextViewText(R.id.w_prayer_time, "—")
                    views.setTextViewText(R.id.w_countdown, "Tap to load timings")
                }
                views.setTextViewText(R.id.w_updated,
                    if (updatedAt != null) "Updated ${shortTime(updatedAt)}" else "")

                // Tapping anywhere on the widget launches the app.
                val launch = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                if (launch != null) {
                    val pi = PendingIntent.getActivity(
                        context, 0, launch,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                    views.setOnClickPendingIntent(R.id.w_root, pi)
                }
                manager.updateAppWidget(id, views)
            }
        }

        /** Extract HH:mm from an ISO-8601 timestamp ("2026-04-26T22:30:01.123…"). */
        private fun shortTime(iso: String): String {
            val t = iso.indexOf('T')
            return if (t > 0 && iso.length >= t + 6) iso.substring(t + 1, t + 6) else iso
        }

        private fun displayName(p: String): String = when (p) {
            "fajr" -> "Fajr"; "dhuhr" -> "Dhuhr"; "asr" -> "Asr"
            "maghrib" -> "Maghrib"; "isha" -> "Isha"; "jumuah" -> "Jumu'ah"
            else -> p.replaceFirstChar { it.uppercase() }
        }

        /** Compute "in 1h 23m" from "HH:mm". Best-effort — no exact-second precision. */
        private fun countdownText(hhmm: String): String {
            val parts = hhmm.split(":")
            if (parts.size < 2) return ""
            val h = parts[0].toIntOrNull() ?: return ""
            val m = parts[1].toIntOrNull() ?: return ""
            val now = Calendar.getInstance()
            val nowMin = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            var diff = (h * 60 + m) - nowMin
            if (diff <= 0) diff += 24 * 60
            return if (diff < 60) String.format(Locale.US, "in %dm", diff)
                   else String.format(Locale.US, "in %dh %dm", diff / 60, diff % 60)
        }
    }
}
