package com.lucas.tv_home

import android.app.usage.UsageStatsManager
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlin.math.pow

private const val FIRE_SETTINGS = "com.amazon.tv.settings.v2"
private const val DAY_MS = 24 * 60 * 60 * 1000L

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tv_home/apps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "list" -> executor.execute {
                        val apps = listApps()
                        mainHandler.post { result.success(apps) }
                    }
                    "usage" -> executor.execute {
                        val scores = usageScores()
                        mainHandler.post { result.success(scores) }
                    }
                    "launch" -> {
                        val pkg = call.argument<String>("package")!!
                        val intent = packageManager.getLeanbackLaunchIntentForPackage(pkg)
                            ?: packageManager.getLaunchIntentForPackage(pkg)
                        if (intent == null) {
                            result.error("not_found", "No launch activity for $pkg", null)
                        } else {
                            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(null)
                        }
                    }
                    "openSettingsPage" -> {
                        val activity = "$FIRE_SETTINGS.${call.argument<String>("activity")!!}"
                        startActivity(
                            // A fresh task each time, so Back always comes straight home.
                            Intent().setClassName(FIRE_SETTINGS, activity)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK),
                        )
                        result.success(null)
                    }
                    "openFireSettings" -> {
                        // Just long enough for Amazon's Settings (part of its home screen) to open.
                        // After that, Home comes back here as usual.
                        HomeRedirectService.pause(this, 2_000L)
                        startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    }
                    "openFireHome" -> {
                        HomeRedirectService.pause(this, 5 * 60_000L)
                        startActivity(
                            Intent(Intent.ACTION_MAIN)
                                .addCategory(Intent.CATEGORY_HOME)
                                .setPackage(FIRE_LAUNCHER)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                    "wallpaperChanged" -> {
                        HomeRedirectService.setCoverWallpaper(this, call.argument<String>("asset")!!)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        // Back on our home screen, so any pause for Amazon's screens is over.
        HomeRedirectService.resume(this)
    }

    /**
     * How much each app has been watched lately: minutes in the foreground over the last 30 days,
     * from Android's own usage stats, with each day counting half as much for every week it's old.
     * Empty until usage access is granted.
     */
    private fun usageScores(): Map<String, Double> {
        val now = System.currentTimeMillis()
        val stats = getSystemService(UsageStatsManager::class.java)
            .queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 30 * DAY_MS, now)
            ?: return emptyMap()
        val scores = HashMap<String, Double>()
        for (day in stats) {
            if (day.totalTimeInForeground <= 0) continue
            val weeksOld = (now - day.lastTimeStamp).coerceAtLeast(0) / (7.0 * DAY_MS)
            scores.merge(day.packageName, day.totalTimeInForeground / 60_000.0 * 0.5.pow(weeksOld), Double::plus)
        }
        return scores
    }

    /** Every launchable app, TV apps first, with its icon rendered to PNG for Flutter. */
    private fun listApps(): List<Map<String, Any>> {
        val apps = LinkedHashMap<String, Map<String, Any>>()
        for (category in listOf(Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER)) {
            val query = Intent(Intent.ACTION_MAIN).addCategory(category)
            for (info in packageManager.queryIntentActivities(query, 0)) {
                val pkg = info.activityInfo.packageName
                if (pkg == packageName || pkg == FIRE_LAUNCHER || pkg in apps) continue
                apps[pkg] = mapOf(
                    "package" to pkg,
                    "label" to info.loadLabel(packageManager).toString(),
                    "icon" to toPng(info.loadIcon(packageManager)),
                )
            }
        }
        return apps.values.toList()
    }

    private fun toPng(drawable: Drawable): ByteArray {
        val size = 160
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        drawable.mutate().setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        return ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }
}
