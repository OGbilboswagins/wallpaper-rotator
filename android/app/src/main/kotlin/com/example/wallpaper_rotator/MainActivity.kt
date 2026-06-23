package com.example.wallpaper_rotator

import android.app.WallpaperManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private val channelName = "vpp_wallpaper_rotator/wallpaper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setHomeWallpaper" -> {
                        val path = call.argument<String>("path")

                        if (path.isNullOrBlank()) {
                            result.error("NO_PATH", "No image path was provided.", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val message = setHomeWallpaper(path)

                                runOnUiThread {
                                    result.success(message)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("SET_WALLPAPER_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun setHomeWallpaper(path: String): String {
        val imageFile = File(path)

        if (!imageFile.exists()) {
            throw IllegalArgumentException("Image file does not exist: $path")
        }

        val bitmap = decodeBitmapForWallpaper(path)
            ?: throw IllegalArgumentException("Could not decode image: $path")

        val wallpaperManager = WallpaperManager.getInstance(applicationContext)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            wallpaperManager.setBitmap(
                bitmap,
                null,
                true,
                WallpaperManager.FLAG_SYSTEM
            )
        } else {
            wallpaperManager.setBitmap(bitmap)
        }

        bitmap.recycle()

        return "Android home wallpaper set"
    }

    private fun decodeBitmapForWallpaper(path: String): Bitmap? {
        val displayMetrics = resources.displayMetrics

        val targetWidth = displayMetrics.widthPixels * 2
        val targetHeight = displayMetrics.heightPixels * 2

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
        var inSampleSize = 1

        if (imageWidth <= 0 || imageHeight <= 0) {
            return inSampleSize
        }

        if (imageHeight > targetHeight || imageWidth > targetWidth) {
            val halfHeight = imageHeight / 2
            val halfWidth = imageWidth / 2

            while (
                halfHeight / inSampleSize >= targetHeight &&
                halfWidth / inSampleSize >= targetWidth
            ) {
                inSampleSize *= 2
            }
        }

        return max(1, inSampleSize)
    }
}