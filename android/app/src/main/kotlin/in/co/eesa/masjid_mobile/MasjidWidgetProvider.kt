package `in`.co.eesa.masjid_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale

/**
 * Home-screen widget — nearest masjid + next prayer + all 5 daily prayers,
 * with an "X overdue near you" badge for admins. Reads from a dedicated
 * SharedPreferences file (MasjidWidgetPrefs) the Flutter app populates via
 * a MethodChannel. The widget never makes its own network call — the
 * Flutter side is the single source of truth.
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
        const val PREF_FILE = "MasjidWidgetPrefs"

        fun updateAll(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            val name        = prefs.getString("masjid_name", null) ?: "Masjid Timings"
            val area        = prefs.getString("masjid_area", null) ?: ""
            val distance    = prefs.getString("distance_km", null) ?: ""
            val nextPrayer  = prefs.getString("next_prayer", null)?.takeIf { it.isNotEmpty() }
            val nextTime    = prefs.getString("next_time",   null)?.takeIf { it.isNotEmpty() }
            val updated     = prefs.getString("updated_at",  null)
            val overdueCnt  = prefs.getString("overdue_count", "0")?.toIntOrNull() ?: 0
            val overdueName = prefs.getString("overdue_name",  null)?.takeIf { it.isNotEmpty() }

            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.masjid_widget)

                // Header: masjid name + distance
                views.setTextViewText(R.id.w_masjid_name, name)
                if (area.isNotEmpty() && distance.isNotEmpty()) {
                    views.setTextViewText(R.id.w_masjid_area, "$area · ${distance} km")
                } else {
                    views.setTextViewText(R.id.w_masjid_area, area.ifEmpty { distance })
                }

                // Next prayer / countdown
                if (nextPrayer != null && nextTime != null) {
                    views.setTextViewText(R.id.w_prayer_name, displayName(nextPrayer))
                    views.setTextViewText(R.id.w_prayer_time, nextTime)
                    views.setTextViewText(R.id.w_countdown,   countdownText(nextTime))
                } else {
                    views.setTextViewText(R.id.w_prayer_name, "Open app")
                    views.setTextViewText(R.id.w_prayer_time, "—")
                    views.setTextViewText(R.id.w_countdown,   "Tap to load timings")
                }

                // 5-prayer grid
                val pairs = listOf(
                    R.id.w_p1_name to "fajr",  R.id.w_p1_time to "fajr",
                    R.id.w_p2_name to "dhuhr", R.id.w_p2_time to "dhuhr",
                    R.id.w_p3_name to "asr",   R.id.w_p3_time to "asr",
                    R.id.w_p4_name to "maghrib", R.id.w_p4_time to "maghrib",
                    R.id.w_p5_name to "isha",  R.id.w_p5_time to "isha"
                )
                val labels = mapOf(
                    R.id.w_p1_name to "Fajr",    R.id.w_p2_name to "Dhuhr",
                    R.id.w_p3_name to "Asr",     R.id.w_p4_name to "Maghrib",
                    R.id.w_p5_name to "Isha"
                )
                for ((vid, label) in labels) views.setTextViewText(vid, label)
                for ((vid, key) in pairs) {
                    if (vid !in labels) {
                        val raw = prefs.getString(key, "") ?: ""
                        views.setTextViewText(vid, raw.ifEmpty { "—" })
                    }
                }
                // Highlight the active prayer in the grid
                val activeIds = mapOf(
                    "fajr"    to (R.id.w_p1_name to R.id.w_p1_time),
                    "dhuhr"   to (R.id.w_p2_name to R.id.w_p2_time),
                    "asr"     to (R.id.w_p3_name to R.id.w_p3_time),
                    "maghrib" to (R.id.w_p4_name to R.id.w_p4_time),
                    "isha"    to (R.id.w_p5_name to R.id.w_p5_time)
                )
                val highlight = nextPrayer?.let { activeIds[it] }
                for ((_, ids) in activeIds) {
                    val (nameId, timeId) = ids
                    val isActive = highlight == ids
                    val color = if (isActive) 0xFFE8C863.toInt() else 0xFFA0AAA8.toInt()
                    val timeColor = if (isActive) 0xFFFFFAEC.toInt() else 0xFFC5BFA8.toInt()
                    views.setTextColor(nameId, color)
                    views.setTextColor(timeId, timeColor)
                }

                // Admin overdue badge
                if (overdueCnt > 0) {
                    views.setViewVisibility(R.id.w_overdue, View.VISIBLE)
                    val msg = if (overdueName != null && overdueCnt == 1)
                        "⚠️ $overdueName overdue nearby"
                    else
                        "⚠️ $overdueCnt overdue masjid${if (overdueCnt == 1) "" else "s"} nearby"
                    views.setTextViewText(R.id.w_overdue, msg)
                } else {
                    views.setViewVisibility(R.id.w_overdue, View.GONE)
                }

                views.setTextViewText(R.id.w_updated,
                    if (updated != null) "Updated ${shortTime(updated)}" else "Open app to load")

                // Tap → launch app
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

        private fun shortTime(iso: String): String {
            val t = iso.indexOf('T')
            return if (t > 0 && iso.length >= t + 6) iso.substring(t + 1, t + 6) else iso
        }

        private fun displayName(p: String): String = when (p) {
            "fajr" -> "Fajr"; "dhuhr" -> "Dhuhr"; "asr" -> "Asr"
            "maghrib" -> "Maghrib"; "isha" -> "Isha"; "jumuah" -> "Jumu'ah"
            else -> p.replaceFirstChar { it.uppercase() }
        }

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
