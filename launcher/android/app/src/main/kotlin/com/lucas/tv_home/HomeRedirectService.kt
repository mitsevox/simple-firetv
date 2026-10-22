package com.lucas.tv_home

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.ImageView

const val FIRE_LAUNCHER = "com.amazon.tv.launcher"

/** Views that only exist while Amazon's Settings grid (which lives inside its home screen) shows. */
private val FIRE_SETTINGS_VIEWS = listOf("settings_search_input", "settings_card_view")
    .map { "$FIRE_LAUNCHER:id/$it" }

/**
 * Fire OS won't let another app own the Home button, and it handles the key before accessibility
 * services can see it. So this watches Amazon's launcher and sends anything but its Settings grid
 * back to ours. Pressing Home while Amazon's screen is already up only switches its tab, so focus
 * and content events are watched too, not just new windows.
 *
 * Android holds our launch for ~5 seconds after a Home press, so meanwhile a full-screen copy of
 * our wallpaper covers Amazon's screen and swallows remote presses.
 */
class HomeRedirectService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val removeCoverTask = Runnable { removeCover() }
    private var cover: View? = null
    private var coverBitmap: Pair<String, Bitmap>? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        when (event.packageName?.toString()) {
            FIRE_LAUNCHER -> if (cover == null && !isPaused() && !showingFireSettings()) {
                showCover()
                openHome()
            }
            // Our home screen is up: give it a moment to draw, then lift the cover.
            packageName -> if (
                event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
                event.className == MainActivity::class.java.name
            ) {
                handler.removeCallbacks(removeCoverTask)
                handler.postDelayed(removeCoverTask, 200)
            }
        }
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        removeCover()
        super.onDestroy()
    }

    private fun showingFireSettings(): Boolean {
        val root = rootInActiveWindow ?: return false
        return FIRE_SETTINGS_VIEWS.any { root.findAccessibilityNodeInfosByViewId(it).isNotEmpty() }
    }

    private fun isPaused() = System.currentTimeMillis() < prefs(this).getLong(KEY_PAUSE_UNTIL, 0)

    private fun openHome() {
        startActivity(
            Intent(this, MainActivity::class.java).addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP,
            ),
        )
    }

    private fun showCover() {
        if (cover != null) return
        val view = ImageView(this).apply {
            setBackgroundColor(Color.BLACK)
            scaleType = ImageView.ScaleType.CENTER_CROP
            loadCoverBitmap()?.let(::setImageBitmap)
            isFocusable = true
            setOnKeyListener { _, _, _ -> true }
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_FULLSCREEN,
            PixelFormat.OPAQUE,
        )
        getSystemService(WindowManager::class.java).addView(view, params)
        view.requestFocus()
        cover = view
        // Never leave the TV stuck behind the cover if our launch doesn't happen.
        handler.postDelayed(removeCoverTask, 8_000)
    }

    private fun removeCover() {
        handler.removeCallbacks(removeCoverTask)
        cover?.let { getSystemService(WindowManager::class.java).removeView(it) }
        cover = null
    }

    /** The wallpaper Flutter last showed, decoded at half size and kept until it changes. */
    private fun loadCoverBitmap(): Bitmap? {
        val asset = prefs(this).getString(KEY_COVER_ASSET, null) ?: return null
        coverBitmap?.let { (cached, bitmap) -> if (cached == asset) return bitmap }
        val bitmap = try {
            assets.open("flutter_assets/$asset").use {
                BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = 2 })
            }
        } catch (_: Exception) {
            null
        } ?: return null
        coverBitmap = asset to bitmap
        return bitmap
    }

    companion object {
        private const val KEY_PAUSE_UNTIL = "pause_until"
        private const val KEY_COVER_ASSET = "cover_asset"

        private fun prefs(context: Context) =
            context.getSharedPreferences("home_redirect", Context.MODE_PRIVATE)

        /** Lets Amazon's home screen stay open for [millis], e.g. to reach a menu only it has. */
        fun pause(context: Context, millis: Long) {
            prefs(context).edit().putLong(KEY_PAUSE_UNTIL, System.currentTimeMillis() + millis).apply()
        }

        fun resume(context: Context) {
            prefs(context).edit().remove(KEY_PAUSE_UNTIL).apply()
        }

        /** Records which bundled wallpaper the cover should show. */
        fun setCoverWallpaper(context: Context, asset: String) {
            prefs(context).edit().putString(KEY_COVER_ASSET, asset).apply()
        }
    }
}
