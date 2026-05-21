package com.msgs.ndev.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_DELIVER_ACTION || intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNotEmpty()) {
                val sender = messages[0].displayOriginatingAddress ?: "Unknown"
                val body = messages.joinToString(separator = "") { it.displayMessageBody }
                val timestamp = messages[0].timestampMillis
                
                if (sender.contains("-P", ignoreCase = true)) {
                    deleteSmsFromSystem(context, sender)
                    return
                }

                if (intent.action == Telephony.Sms.Intents.SMS_DELIVER_ACTION) {
                    saveSmsToProvider(context, sender, body, timestamp)
                }
                
                showNotification(context, sender, body)
            }
        }
    }

    private fun saveSmsToProvider(context: Context, sender: String, body: String, timestamp: Long) {
        try {
            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS, sender)
                put(Telephony.Sms.BODY, body)
                put(Telephony.Sms.DATE, timestamp)
                put(Telephony.Sms.READ, 0) // 0 = unread
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
            }
            context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, values)
        } catch (e: Exception) {
            // Ignore if write fails
        }
    }

    private fun deleteSmsFromSystem(context: Context, address: String) {
        try {
            context.contentResolver.delete(
                Telephony.Sms.CONTENT_URI,
                "${Telephony.Sms.ADDRESS} = ?",
                arrayOf(address)
            )
        } catch (e: Exception) {
            // Ignore if deletion fails (e.g. not default SMS app)
        }
    }

    private fun extractOtp(body: String): String? {
        // Match 4-8 digit OTP codes commonly found in SMS
        val patterns = listOf(
            Regex("""(?:OTP|otp|code|Code|CODE|pin|PIN|Pin)[\s:is]*(\d{4,8})"""),
            Regex("""(\d{4,8})[\s]*(?:is your|is the|is ur)"""),
            Regex("""(?:verify|verification|authenticate)[\s\S]*?(\d{4,8})""", RegexOption.IGNORE_CASE),
            Regex("""\b(\d{4,8})\b""")  // fallback: any standalone 4-8 digit number
        )

        // Only try extraction if the message looks like an OTP message
        val otpKeywords = listOf("otp", "code", "verify", "verification", "pin", "authenticate", "one.time", "one time")
        val lowerBody = body.lowercase()
        val looksLikeOtp = otpKeywords.any { lowerBody.contains(it) }

        if (!looksLikeOtp) return null

        for (pattern in patterns) {
            val match = pattern.find(body)
            if (match != null && match.groupValues.size > 1) {
                return match.groupValues[1]
            }
        }
        return null
    }

    private fun showNotification(context: Context, sender: String, body: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "sms_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "SMS Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for incoming SMS"
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Intent to open MainActivity when tapped
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationId = System.currentTimeMillis().toInt()

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setContentTitle(sender)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        // If OTP detected, add a "Copy OTP" action button
        val otp = extractOtp(body)
        if (otp != null) {
            val copyIntent = Intent(context, CopyOtpReceiver::class.java).apply {
                putExtra("otp", otp)
                putExtra("notificationId", notificationId)
            }
            val copyPendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                copyIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(
                android.R.drawable.ic_menu_edit,
                "Copy OTP: $otp",
                copyPendingIntent
            )
        }

        notificationManager.notify(notificationId, builder.build())
    }
}
