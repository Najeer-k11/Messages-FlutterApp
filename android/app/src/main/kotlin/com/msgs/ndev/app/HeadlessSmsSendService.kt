package com.msgs.ndev.app

import android.app.Service
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.provider.Telephony
import android.telephony.SmsManager

/**
 * Required by the Android Default SMS App contract.
 *
 * When a user taps "Reply" from the incoming-call screen (RESPOND_VIA_MESSAGE),
 * this service is invoked with the recipient address and reply body.
 * We send the SMS silently and write it to the Sent folder.
 */
class HeadlessSmsSendService : Service() {

    override fun onBind(intent: Intent): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && intent.action == "android.intent.action.RESPOND_VIA_MESSAGE") {
            val address = intent.data?.schemeSpecificPart?.trimStart('/')?.trim()
            val body = intent.getStringExtra(Intent.EXTRA_TEXT)

            if (!address.isNullOrBlank() && !body.isNullOrBlank()) {
                sendSmsHeadless(address, body)
            }
        }
        stopSelf(startId)
        return START_NOT_STICKY
    }

    private fun sendSmsHeadless(address: String, body: String) {
        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val parts = smsManager.divideMessage(body)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(address, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(address, null, body, null, null)
            }

            // Write sent message to the system SMS provider
            writeSmsToSentFolder(address, body)
        } catch (_: Exception) {
            // Best-effort: if sending fails, we still stop gracefully
        }
    }

    private fun writeSmsToSentFolder(address: String, body: String) {
        try {
            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS, address)
                put(Telephony.Sms.BODY, body)
                put(Telephony.Sms.DATE, System.currentTimeMillis())
                put(Telephony.Sms.READ, 1)
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
            }
            contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
        } catch (_: Exception) {}
    }
}
