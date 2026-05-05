package com.orbit.ke

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.core.app.RemoteInput
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class NotificationReplyReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "NotificationReply"
        const val KEY_TEXT_REPLY = "key_text_reply"
        const val ACTION_REPLY = "com.orbit.ke.ACTION_REPLY"
        const val ACTION_MARK_READ = "com.orbit.ke.ACTION_MARK_READ"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "\n🚨🚨🚨 BROADCAST RECEIVER TRIGGERED! 🚨🚨🚨")
        Log.d(TAG, "Action: ${intent.action}")
        Log.d(TAG, "Has extras: ${intent.extras != null}")
        
        // Log all extras for debugging
        intent.extras?.let { bundle ->
            Log.d(TAG, "Extras keys: ${bundle.keySet().joinToString()}")
        }
        
        when (intent.action) {
            ACTION_REPLY -> {
                Log.d(TAG, "Handling REPLY action")
                handleReply(context, intent)
            }
            ACTION_MARK_READ -> {
                Log.d(TAG, "Handling MARK_READ action")
                handleMarkRead(context, intent)
            }
            else -> {
                Log.d(TAG, "Unknown action: ${intent.action}")
            }
        }
    }

    private fun handleReply(context: Context, intent: Intent) {
        Log.d(TAG, "handleReply called")
        
        // Get the reply text from RemoteInput
        val remoteInputBundle = RemoteInput.getResultsFromIntent(intent)
        Log.d(TAG, "RemoteInput bundle: ${remoteInputBundle != null}")
        
        if (remoteInputBundle != null) {
            val replyText = remoteInputBundle.getCharSequence(KEY_TEXT_REPLY)?.toString()
            Log.d(TAG, "📝 Reply text received: \"$replyText\"")
            
            if (!replyText.isNullOrEmpty()) {
                val payload = intent.getStringExtra("payload") ?: "{}"
                val notificationId = intent.getIntExtra("notificationId", 0)
                
                Log.d(TAG, "Processing reply - NotificationId: $notificationId")
                Log.d(TAG, "Payload: $payload")
                
                // Update notification to show reply is being processed
                updateNotification(context, notificationId, "Sending reply...")
                
                // Send the reply in background
                GlobalScope.launch(Dispatchers.IO) {
                    val success = sendReplyToServer(replyText, payload)
                    withContext(Dispatchers.Main) {
                        if (success) {
                            // Update notification to show success
                            updateNotification(context, notificationId, "Reply sent")
                            // Cancel notification after a short delay
                            delay(2000)
                            cancelNotification(context, notificationId)
                        } else {
                            updateNotification(context, notificationId, "Failed to send reply")
                        }
                    }
                }
            } else {
                Log.d(TAG, "Reply text is empty")
            }
        } else {
            Log.d(TAG, "No RemoteInput found in intent")
        }
    }
    
    private fun updateNotification(context: Context, notificationId: Int, message: String) {
        try {
            val notification = NotificationCompat.Builder(context, NotificationHelper.CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_email)
                .setContentText(message)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setOnlyAlertOnce(true)
                .build()
            
            NotificationManagerCompat.from(context).notify(notificationId, notification)
            Log.d(TAG, "Notification updated: $message")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update notification: ${e.message}")
        }
    }
    
    private fun cancelNotification(context: Context, notificationId: Int) {
        try {
            NotificationManagerCompat.from(context).cancel(notificationId)
            Log.d(TAG, "Notification cancelled: $notificationId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel notification: ${e.message}")
        }
    }

    private fun handleMarkRead(context: Context, intent: Intent) {
        Log.d(TAG, "👁️ Mark as read action")
        val payload = intent.getStringExtra("payload") ?: "{}"
        val notificationId = intent.getIntExtra("notificationId", 0)
        
        // Cancel the notification
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(notificationId)
        
        GlobalScope.launch(Dispatchers.IO) {
            markAsRead(payload)
        }
    }

    private suspend fun sendReplyToServer(text: String, payloadString: String): Boolean {
        return try {
            Log.d(TAG, "\n📤 SENDING REPLY TO SERVER")
            Log.d(TAG, "Text: \"$text\"")
            
            val payload = JSONObject(payloadString)
            val roomId = payload.optString("roomId", "")
            val token = payload.optString("token", "")
            var baseUrl = payload.optString("baseUrl", "https://api.orbit.ke/api/v1")
            
            Log.d(TAG, "RoomId: $roomId")
            Log.d(TAG, "Token present: ${token.isNotEmpty()}")
            Log.d(TAG, "BaseUrl: $baseUrl")
            
            if (roomId.isEmpty() || token.isEmpty()) {
                Log.e(TAG, "❌ Missing roomId or token")
                return false
            }
            
            val url = URL("$baseUrl/channel/$roomId/message/notification-reply")
            Log.d(TAG, "URL: $url")
            
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("authorization", "Bearer $token")
            connection.setRequestProperty("clint-version", "2.0.0")
            connection.setRequestProperty("Accept-Language", "en")
            connection.doOutput = true
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            
            val requestBody = JSONObject().apply {
                put("content", text)
                put("roomId", roomId)
                put("localId", "notif_${System.currentTimeMillis()}")
                // Backend expects enum Platform: android | ios | web
                put("platform", "android")
            }
            
            Log.d(TAG, "Request body: $requestBody")
            
            val writer = OutputStreamWriter(connection.outputStream)
            writer.write(requestBody.toString())
            writer.flush()
            writer.close()
            
            val responseCode = connection.responseCode
            Log.d(TAG, "Response code: $responseCode")
            
            if (responseCode in 200..299) {
                Log.d(TAG, "\n✅✅✅ REPLY SENT SUCCESSFULLY! ✅✅✅\n")
                true
            } else {
                Log.e(TAG, "❌ Failed with code: $responseCode")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error sending reply: ${e.message}", e)
            false
        } finally {
            Log.d(TAG, "sendReplyToServer completed")
        }
    }
    
    private suspend fun markAsRead(payloadString: String) {
        try {
            val payload = JSONObject(payloadString)
            val roomId = payload.optString("roomId", "")
            val token = payload.optString("token", "")
            var baseUrl = payload.optString("baseUrl", "https://api.orbit.ke/api/v1")
            
            if (roomId.isEmpty() || token.isEmpty()) return
            
            val url = URL("$baseUrl/channel/$roomId/deliver")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "PATCH"
            connection.setRequestProperty("authorization", "Bearer $token")
            connection.setRequestProperty("clint-version", "2.0.0")
            connection.setRequestProperty("Accept-Language", "en")
            
            val responseCode = connection.responseCode
            if (responseCode == 200) {
                Log.d(TAG, "✅ Marked as read successfully")
            }
            
            connection.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "Error marking as read: ${e.message}")
        }
    }
}
