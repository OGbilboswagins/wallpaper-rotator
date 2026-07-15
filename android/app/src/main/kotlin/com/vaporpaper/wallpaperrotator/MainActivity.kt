package com.vaporpaper.wallpaperrotator

import android.app.WallpaperManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.max
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import kotlin.math.min


class MainActivity : FlutterActivity() {
    private val channelName = "vpp_wallpaper_rotator/wallpaper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setHomeWallpaper" -> {
                        val path = call.argument<String>("path")
                        val mode = call.argument<String>("mode") ?: "Home Only"
                        val fitMode = call.argument<String>("fitMode") ?: "Fill"

                        if (path.isNullOrBlank()) {
                            result.error("NO_PATH", "No image path was provided.", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val message = setWallpaper(path, mode, fitMode)

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

                    "moveToBackground" -> {
                        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }

                        startActivity(homeIntent)
                        result.success("Moved app to home screen")
                    }

                    "startRotationService" -> {
                        val wallpaperMode = call.argument<String>("wallpaperMode") ?: "Home Only"
                        val fitMode = call.argument<String>("fitMode") ?: "Fill"
                        val folderPath = call.argument<String>("folderPath")
                        val lockFolderPath = call.argument<String>("lockFolderPath") ?: ""
                        val intervalSeconds = call.argument<Int>("intervalSeconds")

                        val serviceIntent = Intent(this, WallpaperRotationService::class.java).apply {
                            putExtra("wallpaperMode", wallpaperMode)
                            putExtra("fitMode", fitMode)
                            putExtra("folderPath", folderPath)
                            putExtra("lockFolderPath", lockFolderPath)
                            putExtra("intervalSeconds", intervalSeconds ?: 30)
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }

                        result.success("Rotation service started")
                    }

                    "stopRotationService" -> {
                        val serviceIntent = Intent(this, WallpaperRotationService::class.java)
                        stopService(serviceIntent)
                        result.success("Rotation service stopped")
                    }

                    "isAndroidRotationRunning" -> {
                        result.success(WallpaperRotationService.isRunning)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun setWallpaper(
        path: String,
        mode: String,
        fitMode: String
    ): String {
        val imageFile = File(path)

        if (!imageFile.exists()) {
            throw IllegalArgumentException("Image file does not exist: $path")
        }

        val bitmap = prepareBitmapForWallpaper(path, fitMode)
            ?: throw IllegalArgumentException("Could not decode image: $path")

        val wallpaperManager = WallpaperManager.getInstance(applicationContext)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val flags = when (mode) {
                "Lock Only" -> WallpaperManager.FLAG_LOCK
                "Both Shared" ->
                    WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
               else -> WallpaperManager.FLAG_SYSTEM
            }

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

        return "Wallpaper applied: $mode, fit: $fitMode"
    }

    private fun prepareBitmapForWallpaper(
        path: String,
        fitMode: String
    ): Bitmap? {
        val displayMetrics = resources.displayMetrics

        val targetWidth = displayMetrics.widthPixels
        val targetHeight = displayMetrics.heightPixels

        if (targetWidth <= 0 || targetHeight <= 0) {
            return null
        }

        val boundsOptions = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }

        BitmapFactory.decodeFile(path, boundsOptions)

        if (boundsOptions.outWidth <= 0 || boundsOptions.outHeight <= 0) {
            return null
        }

        val decodeOptions = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(
                boundsOptions.outWidth,
                boundsOptions.outHeight,
                targetWidth,
                targetHeight
            )
        }

        val sourceBitmap =
            BitmapFactory.decodeFile(path, decodeOptions) ?: return null

        val preparedBitmap = transformBitmap(
            sourceBitmap = sourceBitmap,
            targetWidth = targetWidth,
            targetHeight = targetHeight,
            fitMode = fitMode
        )

        if (preparedBitmap !== sourceBitmap && !sourceBitmap.isRecycled) {
            sourceBitmap.recycle()
        }

        return preparedBitmap
    }

    private fun transformBitmap(
        sourceBitmap: Bitmap,
        targetWidth: Int,
        targetHeight: Int,
        fitMode: String
    ): Bitmap {
        val sourceWidth = sourceBitmap.width.toFloat()
        val sourceHeight = sourceBitmap.height.toFloat()

        val outputBitmap = Bitmap.createBitmap(
            targetWidth,
            targetHeight,
            Bitmap.Config.ARGB_8888
        )

        val canvas = Canvas(outputBitmap)

       val paint = Paint(
            Paint.ANTI_ALIAS_FLAG or
                Paint.FILTER_BITMAP_FLAG or
                Paint.DITHER_FLAG
        )

        when (fitMode) {
            "Stretch" -> {
                val destination = RectF(
                    0f,
                    0f,
                    targetWidth.toFloat(),
                    targetHeight.toFloat()
                )

                canvas.drawBitmap(
                    sourceBitmap,
                    null,
                    destination,
                    paint
                )
            }

            "Fit" -> {
                canvas.drawColor(Color.BLACK)

                val scale = min(
                    targetWidth / sourceWidth,
                    targetHeight / sourceHeight
                )

                val scaledWidth = sourceWidth * scale
                val scaledHeight = sourceHeight * scale

                val left = (targetWidth - scaledWidth) / 2f
                val top = (targetHeight - scaledHeight) / 2f

               val destination = RectF(
                    left,
                    top,
                    left + scaledWidth,
                    top + scaledHeight
                )

                canvas.drawBitmap(
                    sourceBitmap,
                    null,
                    destination,
                    paint
                )
            }

            "Center" -> {
                canvas.drawColor(Color.BLACK)

                // Preserve the image's decoded size unless it is too large
                // to fit on the display.
                val scale = min(
                    1f,
                    min(
                        targetWidth / sourceWidth,
                        targetHeight / sourceHeight
                    )
                )

                val scaledWidth = sourceWidth * scale
                val scaledHeight = sourceHeight * scale

                val left = (targetWidth - scaledWidth) / 2f
                val top = (targetHeight - scaledHeight) / 2f

                val destination = RectF(
                    left,
                    top,
                    left + scaledWidth,
                    top + scaledHeight
                )

                canvas.drawBitmap(
                    sourceBitmap,
                    null,
                    destination,
                    paint
                )
            }

            "Fill" -> {
                val scale = max(
                    targetWidth / sourceWidth,
                    targetHeight / sourceHeight
                )

                val scaledWidth = sourceWidth * scale
                val scaledHeight = sourceHeight * scale

                val left = (targetWidth - scaledWidth) / 2f
                val top = (targetHeight - scaledHeight) / 2f

                val destination = RectF(
                    left,
                    top,
                    left + scaledWidth,
                    top + scaledHeight
                )

                canvas.drawBitmap(
                    sourceBitmap,
                    null,
                    destination,
                    paint
                )
            }

            else -> {
                // Unknown values safely fall back to Fill.
                val scale = max(
                    targetWidth / sourceWidth,
                    targetHeight / sourceHeight
                )

                val scaledWidth = sourceWidth * scale
                val scaledHeight = sourceHeight * scale

                val left = (targetWidth - scaledWidth) / 2f
                val top = (targetHeight - scaledHeight) / 2f

                val destination = RectF(
                    left,
                    top,
                    left + scaledWidth,
                    top + scaledHeight
                )

                canvas.drawBitmap(
                    sourceBitmap,
                    null,
                    destination,
                    paint
                )
            }
        }

        return outputBitmap
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