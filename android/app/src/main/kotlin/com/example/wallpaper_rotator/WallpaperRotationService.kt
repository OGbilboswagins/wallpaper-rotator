package com.example.wallpaper_rotator

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.app.WallpaperManager
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import java.io.File
import kotlin.random.Random
import android.graphics.Bitmap
import kotlin.math.max

class WallpaperRotationService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var rotationRunnable: Runnable? = null
    private var folderPath: String? = null
    private var lockFolderPath: String? = null
    private var intervalSeconds: Int = 30
    private var wallpaperMode: String = "Home Only"

    companion object {
        const val CHANNEL_ID = "wallpaper_rotation_channel"
        const val NOTIFICATION_ID = 1001
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        folderPath = intent?.getStringExtra("folderPath")
        lockFolderPath = intent?.getStringExtra("lockFolderPath")
        intervalSeconds = intent?.getIntExtra("intervalSeconds", 30) ?: 30
        wallpaperMode = intent?.getStringExtra("wallpaperMode") ?: "Home Only"

        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)

        startRotation()

        return START_STICKY
    }

    override fun onDestroy() {
        rotationRunnable?.let {
            handler.removeCallbacks(it)
        }

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun buildNotification(): Notification {
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                Notification.Builder(this)
            }

        return builder
            .setContentTitle("Wallpaper Rotator")
            .setContentText("Mode: $wallpaperMode")
            .setSmallIcon(android.R.drawable.ic_menu_gallery)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Wallpaper Rotation",
                NotificationManager.IMPORTANCE_LOW
            )

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun getRandomImageFile(path: String?): File? {
        if (path.isNullOrBlank()) return null

        val folder = File(path)

        if (!folder.exists() || !folder.isDirectory) {
            return null
        }

        val imageFiles = folder.listFiles { file ->
            file.extension.lowercase() in listOf("jpg", "jpeg", "png", "webp")
        } ?: return null

        if (imageFiles.isEmpty()) return null

        return imageFiles[Random.nextInt(imageFiles.size)]
    }

    private fun applyWallpaperFile(file: File, flags: Int) {
        val bitmap = decodeBitmapForWallpaper(file.absolutePath) ?: return
        val wallpaperManager = WallpaperManager.getInstance(applicationContext)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            wallpaperManager.setBitmap(
                bitmap,
                null,
                true,
                flags
            )
        } else {
            wallpaperManager.setBitmap(bitmap)
        }

        bitmap.recycle()
    }

    private fun rotateWallpaper() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            val homeFile = getRandomImageFile(folderPath) ?: return
            applyWallpaperFile(homeFile, WallpaperManager.FLAG_SYSTEM)
            return
        }

        when (wallpaperMode) {
            "Lock Only" -> {
                val lockFile = getRandomImageFile(lockFolderPath ?: folderPath) ?: return
                applyWallpaperFile(lockFile, WallpaperManager.FLAG_LOCK)
            }

            "Both Shared" -> {
                val sharedFile = getRandomImageFile(folderPath) ?: return
                applyWallpaperFile(
                    sharedFile,
                    WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                )
            }

            "Both Separate" -> {
                val homeFile = getRandomImageFile(folderPath)
                val lockFile = getRandomImageFile(lockFolderPath)

                if (homeFile != null) {
                    applyWallpaperFile(homeFile, WallpaperManager.FLAG_SYSTEM)
                }

                if (lockFile != null) {
                   applyWallpaperFile(lockFile, WallpaperManager.FLAG_LOCK)
                }
            }

            else -> {
                val homeFile = getRandomImageFile(folderPath) ?: return
                applyWallpaperFile(homeFile, WallpaperManager.FLAG_SYSTEM)
            }
        }
    }

    private fun startRotation() {
        rotationRunnable?.let { handler.removeCallbacks(it) }

        rotationRunnable = object : Runnable {
            override fun run() {
                try {
                    rotateWallpaper()
                } catch (e: Exception) {
                    e.printStackTrace()
                }

                handler.postDelayed(
                    this,
                    intervalSeconds * 1000L
                )
            }
        }

        handler.postDelayed(rotationRunnable!!, intervalSeconds * 1000L)
    }

    private fun decodeBitmapForWallpaper(path: String): Bitmap? {
        val displayMetrics = resources.displayMetrics

        val targetWidth = displayMetrics.widthPixels
        val targetHeight = displayMetrics.heightPixels

        val boundsOptions = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }

        BitmapFactory.decodeFile(path, boundsOptions)

        val decodeOptions = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(
                boundsOptions.outWidth,
                boundsOptions.outHeight,
                targetWidth,
                targetHeight
            )
        }

        return BitmapFactory.decodeFile(path, decodeOptions)
    }

    private fun calculateInSampleSize(
        imageWidth: Int,
        imageHeight: Int,
        targetWidth: Int,
        targetHeight: Int
    ): Int {
        if (imageWidth <= 0 || imageHeight <= 0) {
            return 1
        }

        var inSampleSize = 1

        if (imageHeight > targetHeight || imageWidth > targetWidth) {
            val halfHeight = imageHeight / 2
            val halfWidth = imageWidth / 2

            while (
                halfHeight / inSampleSize >= targetHeight ||
                halfWidth / inSampleSize >= targetWidth
            ) {
                inSampleSize *= 2
            }
        }

        return max(1, inSampleSize)
    }
}