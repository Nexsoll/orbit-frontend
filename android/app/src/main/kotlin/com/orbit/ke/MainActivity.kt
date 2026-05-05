package com.orbit.ke

import android.app.Activity.RESULT_OK
import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.util.Log
import android.util.Rational
import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.orbit.ke/notifications"
    private val RECORDING_CHANNEL = "com.orbit.ke/recording_service"
    private val SCREEN_SHARE_CHANNEL = "com.orbit.ke/screen_share"
    private val PIP_CHANNEL = "com.orbit.ke/picture_in_picture"
    private lateinit var notificationHelper: NotificationHelper

    private val RINGTONE_REQUEST_CODE = 1001
    private val SCREEN_CAPTURE_REQUEST_CODE = 3001
    private var pendingSoundResult: MethodChannel.Result? = null
    private var pendingScreenCaptureResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d("MainActivity", "🔧 Configuring Flutter Engine with notification channel")
        notificationHelper = NotificationHelper(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d("MainActivity", "📱 Method called: ${call.method}")
            when (call.method) {
                "showNotificationWithReply" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val payload = call.argument<String>("payload") ?: "{}"
                    val channelId = call.argument<String>("channelId")

                    Log.d("MainActivity", "🔔 Showing native notification: $title on channel: ${channelId ?: NotificationHelper.CHANNEL_ID}")
                    notificationHelper.showNotificationWithReply(id, title, body, payload, channelId)
                    result.success(true)
                }
                "pickNotificationSound" -> {
                    if (pendingSoundResult != null) {
                        result.error("busy", "Another picker is in progress", null)
                    } else {
                        pendingSoundResult = result
                        try {
                            val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                                putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
                                putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                                putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            }
                            startActivityForResult(intent, RINGTONE_REQUEST_CODE)
                        } catch (e: Exception) {
                            pendingSoundResult = null
                            result.error("picker_error", e.message, null)
                        }
                    }
                }
                "createOrUpdateChannel" -> {
                    val channelId = call.argument<String>("channelId")
                    val name = call.argument<String>("name")
                    val description = call.argument<String>("description")
                    val soundUri = call.argument<String>("soundUri")
                    if (channelId.isNullOrEmpty() || name.isNullOrEmpty() || soundUri.isNullOrEmpty()) {
                        result.error("bad_args", "Missing required args", null)
                    } else {
                        val ok = notificationHelper.createOrUpdateChannel(channelId, name, description ?: name, soundUri)
                        result.success(ok)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        // Recording foreground service channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecordingService" -> {
                    val title = call.argument<String>("title") ?: "Recording"
                    val content = call.argument<String>("content") ?: "Recording in background"
                    val intent = Intent(this, RecordingForegroundService::class.java).apply {
                        putExtra("title", title)
                        putExtra("content", content)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopRecordingService" -> {
                    val intent = Intent(this, RecordingForegroundService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        // Screen share MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_SHARE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestScreenCapture" -> {
                    try {
                        pendingScreenCaptureResult = result
                        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        val intent = projectionManager.createScreenCaptureIntent()
                        startActivityForResult(intent, SCREEN_CAPTURE_REQUEST_CODE)
                    } catch (e: Exception) {
                        pendingScreenCaptureResult = null
                        result.error("screen_capture_error", e.message, null)
                    }
                }
                "startScreenCaptureService" -> {
                    val title = call.argument<String>("title") ?: "Screen Sharing"
                    val content = call.argument<String>("content") ?: "You are sharing your screen"
                    val intent = Intent(this, ScreenCaptureForegroundService::class.java).apply {
                        putExtra("title", title)
                        putExtra("content", content)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopScreenCaptureService" -> {
                    val intent = Intent(this, ScreenCaptureForegroundService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPictureInPictureSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && packageManager.hasSystemFeature("android.software.picture_in_picture")
                    result.success(supported)
                }
                "enterPictureInPictureMode" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(false)
                    } else {
                        try {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(16, 9))
                                .build()
                            enterPictureInPictureMode(params)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("pip_error", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        Log.d("MainActivity", "✅ Notification channel registered")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RINGTONE_REQUEST_CODE) {
            val res = pendingSoundResult
            pendingSoundResult = null
            if (res == null) return

            if (resultCode == RESULT_OK && data != null) {
                try {
                    val uri: Uri? = data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                    if (uri != null) {
                        val ringtone = RingtoneManager.getRingtone(this, uri)
                        val title = ringtone?.getTitle(this) ?: "Custom"
                        res.success(mapOf("uri" to uri.toString(), "title" to title))
                    } else {
                        res.success(null)
                    }
                } catch (e: Exception) {
                    res.error("picker_failed", e.message, null)
                }
            } else {
                res.success(null)
            }
        } else if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
            val res = pendingScreenCaptureResult
            pendingScreenCaptureResult = null
            if (res == null) return

            if (resultCode == RESULT_OK) {
                Log.d("MainActivity", "Screen capture permission granted")
                res.success(true)
            } else {
                Log.d("MainActivity", "Screen capture permission denied")
                res.success(false)
            }
        }
    }
}
