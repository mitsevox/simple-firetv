package com.lucas.tv_home

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Base64
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

const val SPOTIFY = "com.spotify.tv.android"
private const val ART_SIZE = 144

/**
 * Follows Spotify's media session and sends each change to Flutter as `update`. The last track is
 * kept in prefs, so there's still something to show after Spotify closes or the TV restarts.
 */
class NowPlaying(private val context: Context, private val channel: MethodChannel) {
    private val sessions = context.getSystemService(MediaSessionManager::class.java)
    private val listener = ComponentName(context, MediaListener::class.java)
    private val prefs = context.getSharedPreferences("now_playing", Context.MODE_PRIVATE)
    private val handler = Handler(Looper.getMainLooper())
    private var started = false
    private var controller: MediaController? = null
    private var shownArt: Bitmap? = null

    private val callback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) = send()
        override fun onMetadataChanged(metadata: MediaMetadata?) = send()
        override fun onSessionDestroyed() {
            attach(null)
            send()
        }
    }

    private val sessionsChanged = MediaSessionManager.OnActiveSessionsChangedListener { list ->
        attach(list?.firstOrNull { it.packageName == SPOTIFY })
        send()
    }

    /** Starts following sessions; does nothing until the listener has been enabled. */
    fun start() {
        if (started) return
        try {
            sessions.addOnActiveSessionsChangedListener(sessionsChanged, listener, handler)
            attach(sessions.getActiveSessions(listener).firstOrNull { it.packageName == SPOTIFY })
            started = true
            send()
        } catch (e: SecurityException) {
            // Listener not enabled yet; tried again on the next resume.
        }
    }

    fun stop() {
        if (started) sessions.removeOnActiveSessionsChangedListener(sessionsChanged)
        attach(null)
        started = false
    }

    fun handle(method: String): Boolean {
        val controls = controller?.transportControls ?: return false
        when (method) {
            "play" -> controls.play()
            "pause" -> controls.pause()
            "next" -> controls.skipToNext()
            "previous" -> controls.skipToPrevious()
            else -> return false
        }
        return true
    }

    private fun attach(next: MediaController?) {
        if (next?.sessionToken == controller?.sessionToken) return
        controller?.unregisterCallback(callback)
        controller = next
        next?.registerCallback(callback, handler)
    }

    private fun send() = channel.invokeMethod("update", snapshot())

    /** The current track and state, or the last one remembered with state "stopped". */
    fun snapshot(): Map<String, Any?> {
        val metadata = controller?.metadata
        val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
        if (metadata != null && title != null) remember(metadata, title)

        val playback = controller?.playbackState
        val state = when (playback?.state) {
            PlaybackState.STATE_PAUSED -> "paused"
            PlaybackState.STATE_PLAYING, PlaybackState.STATE_BUFFERING, PlaybackState.STATE_CONNECTING,
            PlaybackState.STATE_FAST_FORWARDING, PlaybackState.STATE_REWINDING,
            PlaybackState.STATE_SKIPPING_TO_NEXT, PlaybackState.STATE_SKIPPING_TO_PREVIOUS,
            PlaybackState.STATE_SKIPPING_TO_QUEUE_ITEM -> "playing"
            else -> "stopped"
        }
        var position = playback?.position ?: 0L
        if (state == "playing" && playback != null && playback.lastPositionUpdateTime > 0) {
            position += ((SystemClock.elapsedRealtime() - playback.lastPositionUpdateTime) * playback.playbackSpeed).toLong()
        }
        return mapOf(
            "session" to (controller != null),
            "state" to state,
            "title" to prefs.getString("title", null),
            "artist" to prefs.getString("artist", null),
            "album" to prefs.getString("album", null),
            "durationMs" to prefs.getLong("durationMs", 0L),
            "positionMs" to position.coerceAtLeast(0L),
            "art" to prefs.getString("art", null)?.let { Base64.decode(it, Base64.NO_WRAP) },
        )
    }

    private fun remember(metadata: MediaMetadata, title: String) {
        val artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)
        val album = metadata.getString(MediaMetadata.METADATA_KEY_ALBUM)
        prefs.edit()
            .putString("title", title)
            .putString("artist", artist)
            .putString("album", album)
            .putLong("durationMs", metadata.getLong(MediaMetadata.METADATA_KEY_DURATION))
            .apply()
        // Spotify alternates updates with the cover and ones with only its logo as the display
        // icon, so the icon is never used and an update without a cover keeps the current one.
        // Compared by pixels, not by track: Spotify sends a new title before the new cover.
        val art = (metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: metadata.getBitmap(MediaMetadata.METADATA_KEY_ART))
            ?.let { Bitmap.createScaledBitmap(it, ART_SIZE, ART_SIZE, true) }
            ?: return
        if (shownArt?.sameAs(art) == true) return
        shownArt = art
        prefs.edit().putString("art", Base64.encodeToString(toPng(art), Base64.NO_WRAP)).apply()
    }

    private fun toPng(bitmap: Bitmap): ByteArray =
        ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
}
