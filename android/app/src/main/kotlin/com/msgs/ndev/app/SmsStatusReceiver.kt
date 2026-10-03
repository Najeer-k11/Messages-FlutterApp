package com.msgs.ndev.app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsManager

/**
 * Receives SMS sent/delivered confirmation broadcasts.
 * Updates the SMS status in the provider and notifies Flutter via the
 * content observer (which triggers a sync).
 */
class SmsStatusReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_SMS_SENT = "com.msgs.ndev.app.SMS_SENT"
        const val ACTION_SMS_DELIVERED = "com.msgs.ndev.app.SMS_DELIVERED"
        const val EXTRA_MESSAGE_ID = "sms_message_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val messageId = intent.getStringExtra(EXTRA_MESSAGE_ID) ?: return

        when (intent.action) {
            ACTION_SMS_SENT -> {
                when (resultCode) {
                    Activity.RESULT_OK -> {
                        // SMS sent successfully — update status in provider
                        updateSmsStatus(context, messageId, Telephony.Sms.STATUS_NONE)
                    }
                    SmsManager.RESULT_ERROR_GENERIC_FAILURE,
                    SmsManager.RESULT_ERROR_NO_SERVICE,
                    SmsManager.RESULT_ERROR_NULL_PDU,
                    SmsManager.RESULT_ERROR_RADIO_OFF -> {
                        // SMS failed — update status to failed
                        updateSmsStatus(context, messageId, Telephony.Sms.STATUS_FAILED)
                    }
                }
            }
            ACTION_SMS_DELIVERED -> {
                if (resultCode == Activity.RESULT_OK) {
                    // SMS delivered to recipient
                    updateSmsStatus(context, messageId, Telephony.Sms.STATUS_COMPLETE)
                }
            }
        }
    }

    private fun updateSmsStatus(context: Context, messageId: String, status: Int) {
        try {
            val id = if (messageId.startsWith("sms_")) messageId.substringAfter("sms_")
                     else messageId
            val uri = android.net.Uri.parse("content://sms/$id")
            val values = android.content.ContentValues().apply {
                put("status", status)
            }
            context.contentResolver.update(uri, values, null, null)
        } catch (_: Exception) {}
    }
}
