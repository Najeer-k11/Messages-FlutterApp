package com.msgs.ndev.app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import java.io.File

class MmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "android.provider.Telephony.WAP_PUSH_DELIVER") {
            val pdu = intent.getByteArrayExtra("data") ?: return
            val locationUrl = extractContentLocation(pdu) ?: return

            try {
                // Set up temporary file to store downloaded MMS
                val cacheDir = context.cacheDir
                val tempFile = File(cacheDir, "mms_" + System.currentTimeMillis() + ".dat")
                
                val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    context.getSystemService(SmsManager::class.java)
                } else {
                    SmsManager.getDefault()
                }

                val dummyIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    Intent("com.msgs.ndev.app.MMS_DOWNLOADED"),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // Trigger download via SmsManager
                smsManager?.downloadMultimediaMessage(
                    context,
                    locationUrl,
                    Uri.fromFile(tempFile),
                    null,
                    dummyIntent
                )
            } catch (e: Exception) {
                // Ignore download failure
            }
        }
    }

    private fun extractContentLocation(pdu: ByteArray): String? {
        val pduString = String(pdu, Charsets.US_ASCII)
        val httpIdx = pduString.indexOf("http://")
        val httpsIdx = pduString.indexOf("https://")
        val idx = when {
            httpIdx != -1 && httpsIdx != -1 -> minOf(httpIdx, httpsIdx)
            httpIdx != -1 -> httpIdx
            httpsIdx != -1 -> httpsIdx
            else -> return null
        }
        val sb = StringBuilder()
        for (i in idx until pdu.size) {
            val char = pdu[i].toInt().toChar()
            if (char.code in 32..126) {
                sb.append(char)
            } else {
                break
            }
        }
        return sb.toString()
    }
}
