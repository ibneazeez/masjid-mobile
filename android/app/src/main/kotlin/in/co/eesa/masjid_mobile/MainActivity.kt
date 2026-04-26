package `in`.co.eesa.masjid_mobile

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channel = "in.co.eesa.masjid_mobile/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveWidgetData" -> {
                        @Suppress("UNCHECKED_CAST")
                        val data = call.arguments as? Map<String, String> ?: emptyMap()
                        // Write to a dedicated XML file the widget reads
                        // directly — avoids the FlutterSharedPreferences /
                        // DataStore divergence in the shared_preferences plugin.
                        val prefs = applicationContext.getSharedPreferences(
                            MasjidWidgetProvider.PREF_FILE, Context.MODE_PRIVATE)
                        val edit = prefs.edit()
                        for ((k, v) in data) edit.putString(k, v)
                        edit.commit()
                        // Redraw any pinned widgets immediately.
                        val mgr = AppWidgetManager.getInstance(applicationContext)
                        val ids = mgr.getAppWidgetIds(
                            ComponentName(applicationContext, MasjidWidgetProvider::class.java))
                        if (ids.isNotEmpty()) {
                            MasjidWidgetProvider.updateAll(applicationContext, mgr, ids)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
