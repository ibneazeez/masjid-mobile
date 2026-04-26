package `in`.co.eesa.masjid_mobile

import android.appwidget.AppWidgetManager
import android.content.ComponentName
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
                    "refreshWidget" -> {
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
