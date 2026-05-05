package com.orbit.ke

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import org.json.JSONObject

class NotificationHelper(private val context: Context) {
    companion object {
        const val CHANNEL_ID = "chat_notifications"
        const val CHANNEL_NAME = "Chat Notifications"
        const val TAG = "NotificationHelper"
        const val KEY_TEXT_REPLY = "key_text_reply"
    }

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Chat message notifications"
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created: $CHANNEL_ID")
        }
    }

    fun createOrUpdateChannel(channelId: String, name: String, description: String, soundUri: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Delete existing channel first to ensure sound is applied
                try {
                    notificationManager.deleteNotificationChannel(channelId)
                } catch (_: Exception) {}
                val channel = NotificationChannel(
                    channelId,
                    name,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    this.description = description
                    enableVibration(true)
                    setShowBadge(true)
                    try {
                        val uri = Uri.parse(soundUri)
                        val attrs = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                        setSound(uri, attrs)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to set custom sound: ${e.message}")
                    }
                }
                notificationManager.createNotificationChannel(channel)
                Log.d(TAG, "Custom channel created/updated: $channelId -> $soundUri")
                true
            } else {
                // Pre-Oreo devices use builder.setSound at notification time; we'll rely on default
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "createOrUpdateChannel error: ${e.message}")
            false
        }
    }

    fun showNotificationWithReply(
        notificationId: Int,
        title: String,
        body: String,
        payload: String,
        channelId: String? = null
    ) {
        Log.d(TAG, "🚨 SHOWING NATIVE NOTIFICATION WITH REPLY")
        Log.d(TAG, "ID: $notificationId")
        Log.d(TAG, "Title: $title")
        Log.d(TAG, "Body: $body")
        Log.d(TAG, "Payload length: ${payload.length}")

        // Try to extract roomId from payload JSON so tapping the notification opens the chat
        var roomId: String? = null
        try {
            val json = JSONObject(payload)
            roomId = json.optString("roomId", null)
            Log.d(TAG, "Parsed roomId from payload: $roomId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse payload JSON: ${e.message}")
        }

        // Build PendingIntent that opens the app to the specific chat via deep link
        var contentPendingIntent: PendingIntent? = null
        if (!roomId.isNullOrEmpty()) {
            try {
                val tapIntent = Intent(Intent.ACTION_VIEW, Uri.parse("orbit://room/$roomId")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }

                contentPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.getActivity(
                        context,
                        notificationId,
                        tapIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                    )
                } else {
                    PendingIntent.getActivity(
                        context,
                        notificationId,
                        tapIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT
                    )
                }
                Log.d(TAG, "Content PendingIntent created for roomId=$roomId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create content PendingIntent: ${e.message}")
            }
        }

        // Create RemoteInput for reply action
        val remoteInput = RemoteInput.Builder(KEY_TEXT_REPLY)
            .setLabel("Type your message...")
            .build()
        
        Log.d(TAG, "RemoteInput created with key: $KEY_TEXT_REPLY")

        // Create explicit intent for reply action
        val replyIntent = Intent(context, NotificationReplyReceiver::class.java).apply {
            action = NotificationReplyReceiver.ACTION_REPLY
            putExtra("payload", payload)
            putExtra("notificationId", notificationId)
        }
        
        Log.d(TAG, "Reply intent created with action: ${NotificationReplyReceiver.ACTION_REPLY}")

        // Create PendingIntent with unique request code
        val replyPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.getBroadcast(
                context,
                notificationId,
                replyIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        } else {
            PendingIntent.getBroadcast(
                context,
                notificationId,
                replyIntent,
                PendingIntent.FLAG_UPDATE_CURRENT
            )
        }
        
        Log.d(TAG, "PendingIntent created for reply")

        // Create reply action
        val replyAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_dialog_email,
            "Reply",
            replyPendingIntent
        )
            .addRemoteInput(remoteInput)
            .setAllowGeneratedReplies(true)
            .build()
        
        Log.d(TAG, "Reply action created and RemoteInput attached")

        // Create mark as read action
        val markReadIntent = Intent(context, NotificationReplyReceiver::class.java).apply {
            action = NotificationReplyReceiver.ACTION_MARK_READ
            putExtra("payload", payload)
            putExtra("notificationId", notificationId)
        }

        val markReadPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.getBroadcast(
                context,
                notificationId + 10000,
                markReadIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        } else {
            PendingIntent.getBroadcast(
                context,
                notificationId + 10000,
                markReadIntent,
                PendingIntent.FLAG_UPDATE_CURRENT
            )
        }

        val markReadAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_view,
            "Mark as read",
            markReadPendingIntent
        ).build()

        // Build and show notification
        val usedChannel = channelId ?: CHANNEL_ID
        val builder = NotificationCompat.Builder(context, usedChannel)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .addAction(replyAction)
            .addAction(markReadAction)

        // Attach tap action only if we have a valid roomId
        if (contentPendingIntent != null) {
            builder.setContentIntent(contentPendingIntent)
        }

        val notification = builder.build()

        Log.d(TAG, "Notification built with ${notification.actions?.size ?: 0} actions")
        
        notificationManager.notify(notificationId, notification)
        Log.d(TAG, "✅✅✅ NOTIFICATION SHOWN WITH ID: $notificationId")
    }
}
