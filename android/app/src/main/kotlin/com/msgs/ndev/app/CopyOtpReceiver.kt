package com.msgs.ndev.app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.widget.Toast

class CopyOtpReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val otp = intent.getStringExtra("otp") ?: return
        val notificationId = intent.getIntExtra("notificationId", -1)

        // Copy OTP to clipboard
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("OTP", otp)
        clipboard.setPrimaryClip(clip)

        // Show toast confirmation
        Toast.makeText(context, "OTP copied: $otp", Toast.LENGTH_SHORT).show()

        // Dismiss the notification
        if (notificationId != -1) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
        }
    }
}
