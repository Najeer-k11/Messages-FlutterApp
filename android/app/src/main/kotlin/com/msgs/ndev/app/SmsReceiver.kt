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
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput

/**
 * Receives SMS_DELIVER broadcasts (when we are the default SMS app) or
 * SMS_RECEIVED broadcasts (fallback). Shows a rich notification with:
 *  - Deep-link tap to open the exact conversation
 *  - Inline Quick Reply via RemoteInput (Android 7+)
 *  - Copy OTP action button (when OTP detected)
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val KEY_QUICK_REPLY_TEXT = "quick_reply_text"
        const val ACTION_QUICK_REPLY = "com.msgs.ndev.app.QUICK_REPLY"
        const val EXTRA_SENDER = "extra_sender"
        const val EXTRA_THREAD_ID = "extra_thread_id"
        const val CHANNEL_ID = "sms_channel"

        /** Single group key shared by ALL incoming SMS notifications */
        const val GROUP_KEY_SMS = "com.msgs.ndev.app.SMS_GROUP"

        /** Stable ID for the global summary notification (must not collide with sender hash codes) */
        const val SUMMARY_NOTIFICATION_ID = Int.MAX_VALUE
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Telephony.Sms.Intents.SMS_DELIVER_ACTION ||
            action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {

            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNotEmpty()) {
                val sender = messages[0].displayOriginatingAddress ?: "Unknown"
                val body = messages.joinToString(separator = "") { it.displayMessageBody }
                val timestamp = messages[0].timestampMillis

                // Skip promotional messages (–P senders) — just don't notify, don't delete
                if (sender.contains("-P", ignoreCase = true) ||
                    sender.uppercase().matches(Regex(".*-[A-Z]{2,}$"))) {
                    // For SMS_DELIVER we still save so the sync picks it up normally
                    if (action == Telephony.Sms.Intents.SMS_DELIVER_ACTION) {
                        saveSmsToProvider(context, sender, body, timestamp)
                    }
                    return
                }

                if (action == Telephony.Sms.Intents.SMS_DELIVER_ACTION) {
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
                put(Telephony.Sms.READ, 0)
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
            }
            context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, values)
        } catch (_: Exception) {}
    }

    private fun extractOtp(body: String): String? {
        val otpKeywords = listOf("otp", "code", "verify", "verification", "pin", "authenticate", "one.time", "one time", "passcode")
        val lowerBody = body.lowercase()
        if (otpKeywords.none { lowerBody.contains(it) }) return null

        val patterns = listOf(
            Regex("""(?:OTP|otp|code|Code|CODE|pin|PIN|Pin|passcode)[\s:is]*(\d{4,8})"""),
            Regex("""(\d{4,8})[\s]*(?:is your|is the|is ur)"""),
            Regex("""(?:verify|verification|authenticate)[\s\S]*?(\d{4,8})""", RegexOption.IGNORE_CASE),
            Regex("""\b(\d{4,8})\b""")
        )

        for (pattern in patterns) {
            val match = pattern.find(body)
            if (match != null && match.groupValues.size > 1) {
                return match.groupValues[1]
            }
        }
        return null
    }

    private fun getContactName(context: Context, phoneNumber: String): String? {
        if (phoneNumber.isBlank() || phoneNumber.contains("insert-address")) return null
        val uri = Uri.withAppendedPath(
            android.provider.ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(phoneNumber)
        )
        val projection = arrayOf(android.provider.ContactsContract.PhoneLookup.DISPLAY_NAME)
        return try {
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(cursor.getColumnIndexOrThrow(android.provider.ContactsContract.PhoneLookup.DISPLAY_NAME))
                } else null
            }
        } catch (_: Exception) { null }
    }

    private fun showNotification(context: Context, sender: String, body: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SMS Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for incoming SMS"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val contactName = getContactName(context, sender)
        val title = contactName ?: sender
        val notificationId = sender.hashCode() // Group by sender for conversation-style notifs

        // ── Deep-link tap intent: open MainActivity with sender address ──────
        val openIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_SENDTO
            data = Uri.parse("sms:${Uri.encode(sender)}")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_SENDER, sender)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── Inline Quick Reply RemoteInput ────────────────────────────────────
        val remoteInput = RemoteInput.Builder(KEY_QUICK_REPLY_TEXT)
            .setLabel("Reply")
            .build()

        val replyIntent = Intent(context, QuickReplyReceiver::class.java).apply {
            putExtra(EXTRA_SENDER, sender)
            putExtra(EXTRA_THREAD_ID, notificationId)
        }
        val replyPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 1,
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        val replyAction = NotificationCompat.Action.Builder(
            android.R.drawable.sym_action_chat,
            "Reply",
            replyPendingIntent
        ).addRemoteInput(remoteInput).build()

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            .addAction(replyAction)
            .setGroup(GROUP_KEY_SMS) // ← all SMS share ONE group so they collapse together

        // ── OTP Copy action ───────────────────────────────────────────────────
        val otp = extractOtp(body)
        if (otp != null) {
            val copyIntent = Intent(context, CopyOtpReceiver::class.java).apply {
                putExtra("otp", otp)
                putExtra("notificationId", notificationId)
            }
            val copyPendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId + 2,
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
        updateSummaryNotification(context, notificationManager)
    }

    /**
     * Builds/updates the global summary notification.
     *
     * Android requires a summary notification when using notification groups.
     * We look at all currently active notifications in our group, collect their
     * titles (sender names) and first lines, and render an InboxStyle summary
     * that shows up in the notification shade as a collapsible group.
     *
     * Rules:
     *  - Only show the summary when ≥ 2 child notifications are active.
     *  - Each child belongs to group [GROUP_KEY_SMS].
     *  - The summary itself has setGroupSummary(true) on the same group key.
     */
    private fun updateSummaryNotification(context: Context, nm: NotificationManager) {
        val activeNotifications = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            nm.activeNotifications
                .filter { it.notification.group == GROUP_KEY_SMS && !it.notification.extras.getBoolean("isGroupSummary", false) }
        } else {
            return // GroupSummary only meaningful on API 23+
        }

        if (activeNotifications.isEmpty()) {
            nm.cancel(SUMMARY_NOTIFICATION_ID)
            return
        }

        val summaryIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val summaryPendingIntent = PendingIntent.getActivity(
            context,
            SUMMARY_NOTIFICATION_ID,
            summaryIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val count = activeNotifications.size
        val inboxStyle = NotificationCompat.InboxStyle()
            .setBigContentTitle(if (count == 1) "1 new message" else "$count new messages")
            .setSummaryText("Messages")

        // Add one line per active conversation
        for (sbn in activeNotifications) {
            val extras = sbn.notification.extras
            val title = extras.getString("android.title") ?: continue
            val text = extras.getCharSequence("android.text")?.toString() ?: ""
            val preview = if (text.length > 40) text.take(40) + "…" else text
            inboxStyle.addLine("$title  $preview")
        }

        val summaryNotification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setContentTitle(if (count == 1) "1 new message" else "$count new messages")
            .setContentText(activeNotifications.joinToString(", ") {
                it.notification.extras.getString("android.title") ?: "Unknown"
            })
            .setStyle(inboxStyle)
            .setGroup(GROUP_KEY_SMS)
            .setGroupSummary(true)
            .setAutoCancel(true)
            .setContentIntent(summaryPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .putExtras(android.os.Bundle().apply { putBoolean("isGroupSummary", true) })
            .build()

        nm.notify(SUMMARY_NOTIFICATION_ID, summaryNotification)
    }
}

