package com.lucas.tv_home

import android.service.notification.NotificationListenerService

/**
 * Does nothing itself: Android only lets an app see other apps' media sessions while one of its
 * notification listeners is enabled. Enabled once over adb:
 * adb shell cmd notification allow_listener com.lucas.tv_home/com.lucas.tv_home.MediaListener
 */
class MediaListener : NotificationListenerService()
