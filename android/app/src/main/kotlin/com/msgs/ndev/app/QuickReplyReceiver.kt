package com.msgs.ndev.app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput

/**
 * Handles inline quick reply from SMS notification.
 * Sends the reply SMS and updates the notification to a "Sent" state.
 */
class QuickReplyReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val sender = intent.getStringExtra(SmsReceiver.EXTRA_SENDER) ?: return
        val notificationId = intent.getIntExtra(SmsReceiver.EXTRA_THREAD_ID, -1)

        // Extract the quick reply text from RemoteInput
        val remoteInput = RemoteInput.getResultsFromIntent(intent) ?: return
        val replyText = remoteInput.getCharSequence(SmsReceiver.KEY_QUICK_REPLY_TEXT)
            ?.toString()?.trim() ?: return

        if (replyText.isEmpty()) return

        // Send SMS
        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val parts = smsManager.divideMessage(replyText)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(sender, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(sender, null, replyText, null, null)
            }

            // Write to sent folder
            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS, sender)
                put(Telephony.Sms.BODY, replyText)
                put(Telephony.Sms.DATE, System.currentTimeMillis())
                put(Telephony.Sms.READ, 1)
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
            }
            context.contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)

            // Update notification to show "Sent" state, then dismiss child + update summary
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val sentNotification = NotificationCompat.Builder(context, SmsReceiver.CHANNEL_ID)
                .setSmallIcon(android.R.drawable.sym_action_chat)
                .setContentTitle("Sent")
                .setContentText(replyText)
                .setGroup(SmsReceiver.GROUP_KEY_SMS)
                .setAutoCancel(true)
                .build()

            if (notificationId != -1) {
                notificationManager.notify(notificationId, sentNotification)
                // Cancel child notification after 1.5 seconds, then update summary
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    notificationManager.cancel(notificationId)
                    // Check if any SMS notifications remain in the group
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val remaining = notificationManager.activeNotifications
                            .filter { it.notification.group == SmsReceiver.GROUP_KEY_SMS
                                    && it.id != SmsReceiver.SUMMARY_NOTIFICATION_ID }
                        if (remaining.isEmpty()) {
                            notificationManager.cancel(SmsReceiver.SUMMARY_NOTIFICATION_ID)
                        }
                    }
                }, 1500)
            }
        } catch (_: Exception) {
            // Silently fail — notification remains
        }
    }
}
