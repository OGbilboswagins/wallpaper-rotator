package com.vaporpaper.wallpaperrotator

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE
        )

        val rotationEnabled = prefs.getBoolean("flutter.rotationEnabled", false)
        val folderPath = prefs.getString("flutter.androidFolderPath", "") ?: ""
        val intervalString = prefs.getString("flutter.interval", "4 hours") ?: "4 hours"

        val lockFolderPath =
            prefs.getString("flutter.lockFolderPath", "") ?: ""

        val wallpaperMode =
            prefs.getString("flutter.wallpaperMode", "Home Only")
                ?: "Home Only"
        
        val fitMode =
            prefs.getString("flutter.globalFitMode", "Fill") ?: "Fill"

        if (!rotationEnabled || folderPath.isBlank()) return

        val intervalSeconds = when (intervalString) {
            "30 seconds" -> 30
            "1 minute" -> 60
            "15 minutes" -> 900
            "30 minutes" -> 1800
            "1 hour" -> 3600
            "4 hours" -> 14400
            "Daily" -> 86400
            else -> 14400
        }

        val serviceIntent = Intent(context, WallpaperRotationService::class.java).apply {
            putExtra("folderPath", folderPath)
            putExtra("lockFolderPath", lockFolderPath)
            putExtra("wallpaperMode", wallpaperMode)
            putExtra("fitMode", fitMode)
            putExtra("intervalSeconds", intervalSeconds)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}