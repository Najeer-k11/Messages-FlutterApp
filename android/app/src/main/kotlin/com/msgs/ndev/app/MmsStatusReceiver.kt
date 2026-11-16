package com.msgs.ndev.app

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Telephony
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File

/**
 * Completion callbacks from the platform MMS service:
 *  - [MmsSender.ACTION_MMS_SENT]: mark the outgoing message sent / failed, tell Flutter.
 *  - [MmsStatusReceiver.ACTION_MMS_DOWNLOADED]: decode the retrieved MMS, store it in the
 *    provider (as the default SMS app must), notify the user and acknowledge to the MMSC.
 */
class MmsStatusReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_MMS_DOWNLOADED = "com.msgs.ndev.app.MMS_DOWNLOADED"
        const val EXTRA_TRANSACTION_ID = "transaction_id"

        /** Set by MainActivity while it is alive, to surface send failures in the UI. */
        @Volatile var onSendResult: ((Boolean) -> Unit)? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val file = intent.getStringExtra(MmsSender.EXTRA_PDU_FILE)?.let(::File)
        when (intent.action) {
            MmsSender.ACTION_MMS_SENT -> {
                val ok = resultCode == Activity.RESULT_OK
                Log.i(MmsSender.TAG, "MMS send result=$resultCode http=${intent.getIntExtra(android.telephony.SmsManager.EXTRA_MMS_HTTP_STATUS, 0)}")
                intent.getStringExtra(MmsSender.EXTRA_MESSAGE_URI)?.let { uri ->
                    val values = ContentValues().apply {
                        put(Telephony.Mms.MESSAGE_BOX,
                            if (ok) Telephony.Mms.MESSAGE_BOX_SENT else Telephony.Mms.MESSAGE_BOX_FAILED)
                    }
                    try { context.contentResolver.update(Uri.parse(uri), values, null, null) } catch (_: Exception) {}
                }
                file?.delete()
                onSendResult?.invoke(ok)
            }
            ACTION_MMS_DOWNLOADED -> {
                val pending = goAsync()
                Thread {
                    try {
                        if (resultCode == Activity.RESULT_OK && file != null && file.exists()) {
                            handleDownloaded(context, file.readBytes(), intent.getStringExtra(EXTRA_TRANSACTION_ID))
                        }
                    } finally {
                        file?.delete()
                        pending.finish()
                    }
                }.start()
            }
        }
    }

    private fun handleDownloaded(context: Context, pdu: ByteArray, transactionId: String?) {
        val msg = MmsPdu.decode(pdu) ?: return
        if (msg.messageType != MmsPdu.TYPE_RETRIEVE_CONF) return
        val from = msg.from ?: "Unknown"
        val dateSec = msg.dateSeconds ?: (System.currentTimeMillis() / 1000)
        val media = msg.parts.filter { !it.contentType.startsWith("application/smil") }

        try {
            val threadId = Telephony.Threads.getOrCreateThreadId(context, from)
            val values = ContentValues().apply {
                put(Telephony.Mms.THREAD_ID, threadId)
                put(Telephony.Mms.DATE, dateSec)
                put(Telephony.Mms.DATE_SENT, dateSec)
                put(Telephony.Mms.MESSAGE_BOX, Telephony.Mms.MESSAGE_BOX_INBOX)
                put(Telephony.Mms.READ, 0)
                put(Telephony.Mms.SEEN, 0)
                put(Telephony.Mms.MESSAGE_TYPE, MmsPdu.TYPE_RETRIEVE_CONF)
                put(Telephony.Mms.MMS_VERSION, 0x12)
                put(Telephony.Mms.CONTENT_TYPE, "application/vnd.wap.multipart.related")
                msg.transactionId?.let { put(Telephony.Mms.TRANSACTION_ID, it) }
            }
            val uri = context.contentResolver.insert(Telephony.Mms.CONTENT_URI, values) ?: return
            val id = uri.lastPathSegment!!
            MmsStore.insertParts(context, id, media)
            MmsStore.insertAddress(context, id, from, 137) // FROM
        } catch (e: Exception) {
            Log.w(MmsSender.TAG, "Could not store downloaded MMS", e)
            return
        }

        val text = media.firstOrNull { it.isText }?.let { String(it.data, Charsets.UTF_8) }
        val preview = text?.takeIf { it.isNotBlank() } ?: "Photo"
        SmsReceiver().showNotification(context, from, preview)

        transactionId?.let { acknowledge(context, it) }
    }

    /** Sends m-notifyresp-ind so the MMSC marks the message retrieved. */
    private fun acknowledge(context: Context, transactionId: String) {
        try {
            val file = File(MmsSender.pduDir(context), "ack_$transactionId.pdu").apply {
                writeBytes(MmsPdu.encodeNotifyResp(transactionId))
            }
            val uri = FileProvider.getUriForFile(context, MmsSender.authority(context), file)
            val pi = PendingIntent.getBroadcast(
                context, ("ack$transactionId").hashCode(),
                Intent(context, MmsStatusReceiver::class.java).setAction("com.msgs.ndev.app.MMS_ACK")
                    .putExtra(MmsSender.EXTRA_PDU_FILE, file.absolutePath),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            MmsSender.smsManager(context).sendMultimediaMessage(context, uri, null, null, pi)
        } catch (_: Exception) {}
    }
}
