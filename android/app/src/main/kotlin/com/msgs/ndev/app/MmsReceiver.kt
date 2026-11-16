package com.msgs.ndev.app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File

/**
 * WAP_PUSH_DELIVER (we are the default SMS app): an MMS notification arrived. Decode the
 * m-notification-ind, then ask the platform MMS service to download the message into a file we
 * own. [MmsStatusReceiver] picks it up from there and stores it.
 *
 * Previously the download was written to a raw file:// Uri the phone process cannot write to,
 * and nothing ever read it, so every incoming MMS was lost.
 */
class MmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.provider.Telephony.WAP_PUSH_DELIVER") return
        val pdu = intent.getByteArrayExtra("data") ?: return
        val ind = MmsPdu.decode(pdu) ?: return
        if (ind.messageType != MmsPdu.TYPE_NOTIFICATION_IND) return
        val location = ind.contentLocation ?: return
        val tid = ind.transactionId ?: System.currentTimeMillis().toString()

        try {
            val file = File(MmsSender.pduDir(context), "dl_${tid.hashCode()}.pdu")
            val uri = FileProvider.getUriForFile(context, MmsSender.authority(context), file)
            val done = Intent(context, MmsStatusReceiver::class.java).apply {
                action = MmsStatusReceiver.ACTION_MMS_DOWNLOADED
                putExtra(MmsSender.EXTRA_PDU_FILE, file.absolutePath)
                putExtra(MmsStatusReceiver.EXTRA_TRANSACTION_ID, tid)
            }
            val pi = PendingIntent.getBroadcast(
                context, tid.hashCode(), done,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            MmsSender.smsManager(context).downloadMultimediaMessage(context, location, uri, null, pi)
        } catch (_: Exception) {
            // Download could not be started (no data, airplane mode): the MMSC will re-notify.
        }
    }
}
