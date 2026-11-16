package com.msgs.ndev.app

import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.FileProvider
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Sends MMS through the platform MMS service ([SmsManager.sendMultimediaMessage]), which
 * handles APN selection and the HTTP POST to the carrier's MMSC.
 *
 * When this app is the default SMS app the platform does not record the message, so it is
 * persisted to the MMS provider here (outbox, then sent / failed in [MmsStatusReceiver]).
 * Otherwise the platform persists it on our behalf.
 */
object MmsSender {
    const val TAG = "MsgsMms"
    const val ACTION_MMS_SENT = "com.msgs.ndev.app.MMS_SENT"
    const val EXTRA_PDU_FILE = "pdu_file"
    const val EXTRA_MESSAGE_URI = "message_uri"
    private const val DEFAULT_MAX_MESSAGE_SIZE = 300 * 1024
    private const val MAX_IMAGE_SIDE = 1600

    fun authority(context: Context) = "${context.packageName}.mmsfiles"

    fun pduDir(context: Context) = File(context.cacheDir, "mms").apply { mkdirs() }

    fun smsManager(context: Context): SmsManager =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) context.getSystemService(SmsManager::class.java)
        else @Suppress("DEPRECATION") SmsManager.getDefault()

    /** Carrier's MMS size limit; images are recompressed to fit inside it. */
    private fun maxMessageSize(context: Context): Int = try {
        @Suppress("DEPRECATION")
        smsManager(context).carrierConfigValues.getInt(SmsManager.MMS_CONFIG_MAX_MESSAGE_SIZE, DEFAULT_MAX_MESSAGE_SIZE)
    } catch (_: Exception) {
        DEFAULT_MAX_MESSAGE_SIZE
    }.takeIf { it > 0 } ?: DEFAULT_MAX_MESSAGE_SIZE

    /** Builds, persists and dispatches the MMS. Throws on failure to build/dispatch. */
    fun send(context: Context, address: String, text: String?, attachments: List<Uri>) {
        val parts = ArrayList<MmsPdu.Part>()
        // Leave headroom for headers, SMIL and text.
        val budget = ((maxMessageSize(context) * 0.9).toInt() - 4096) / attachments.size.coerceAtLeast(1)
        attachments.forEachIndexed { i, uri ->
            val mime = context.contentResolver.getType(uri) ?: "image/jpeg"
            val (data, type) = if (mime.startsWith("image/") && mime != "image/gif") {
                compressImage(context, uri, budget) to "image/jpeg"
            } else {
                (context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: throw IllegalArgumentException("Cannot read $uri")) to mime
            }
            val ext = when (type) { "image/jpeg" -> "jpg"; "image/png" -> "png"; "image/gif" -> "gif"; else -> "bin" }
            parts.add(MmsPdu.Part(type, data, "image$i.$ext"))
        }
        if (!text.isNullOrBlank()) parts.add(MmsPdu.Part("text/plain", text.toByteArray(), "text0.txt"))
        require(parts.isNotEmpty()) { "Nothing to send" }

        val transactionId = "T" + java.lang.Long.toHexString(System.currentTimeMillis())
        val pdu = MmsPdu.encodeSendReq(listOf(address), parts, transactionId)

        val messageUri = if (DefaultSmsApp.isDefault(context)) {
            persistOutgoing(context, address, parts)
        } else null

        val file = File(pduDir(context), "send_$transactionId.pdu").apply { writeBytes(pdu) }
        val contentUri = FileProvider.getUriForFile(context, authority(context), file)

        val sentIntent = Intent(ACTION_MMS_SENT).apply {
            setClass(context, MmsStatusReceiver::class.java)
            putExtra(EXTRA_PDU_FILE, file.absolutePath)
            messageUri?.let { putExtra(EXTRA_MESSAGE_URI, it.toString()) }
        }
        val pi = PendingIntent.getBroadcast(
            context, transactionId.hashCode(), sentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        smsManager(context).sendMultimediaMessage(context, contentUri, null, null, pi)
    }

    /** Decodes (EXIF-rotated), downsizes and JPEG-compresses until it fits in [budget] bytes. */
    private fun compressImage(context: Context, uri: Uri, budget: Int): ByteArray {
        var bitmap: Bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri)) { decoder, info, _ ->
                val longest = maxOf(info.size.width, info.size.height)
                if (longest > MAX_IMAGE_SIDE) {
                    val s = MAX_IMAGE_SIDE.toFloat() / longest
                    decoder.setTargetSize((info.size.width * s).toInt(), (info.size.height * s).toInt())
                }
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        } else {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_IMAGE_SIDE) sample *= 2
            context.contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
            } ?: throw IllegalArgumentException("Cannot decode $uri")
        }

        var quality = 85
        while (true) {
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
            if (out.size() <= budget) return out.toByteArray()
            if (quality > 40) {
                quality -= 10
            } else {
                // Still too big at low quality: shrink the image instead.
                val w = (bitmap.width * 0.75f).toInt().coerceAtLeast(64)
                val h = (bitmap.height * 0.75f).toInt().coerceAtLeast(64)
                if (w == 64 && h == 64) return out.toByteArray()
                bitmap = Bitmap.createScaledBitmap(bitmap, w, h, true)
                quality = 75
            }
        }
    }

    /** Records an outgoing MMS (outbox) with its parts and recipient, as the default SMS app must. */
    private fun persistOutgoing(context: Context, address: String, parts: List<MmsPdu.Part>): Uri? = try {
        val threadId = Telephony.Threads.getOrCreateThreadId(context, address)
        val values = ContentValues().apply {
            put(Telephony.Mms.THREAD_ID, threadId)
            put(Telephony.Mms.DATE, System.currentTimeMillis() / 1000)
            put(Telephony.Mms.MESSAGE_BOX, Telephony.Mms.MESSAGE_BOX_OUTBOX)
            put(Telephony.Mms.READ, 1)
            put(Telephony.Mms.SEEN, 1)
            put(Telephony.Mms.MESSAGE_TYPE, 128) // m-send-req
            put(Telephony.Mms.MMS_VERSION, 0x12)
            put(Telephony.Mms.CONTENT_TYPE, "application/vnd.wap.multipart.related")
        }
        val uri = context.contentResolver.insert(Telephony.Mms.CONTENT_URI, values)
        Log.i(TAG, "Outgoing MMS stored at $uri (thread $threadId)")
        if (uri != null) {
            val id = uri.lastPathSegment!!
            MmsStore.insertParts(context, id, parts)
            MmsStore.insertAddress(context, id, address, 151) // TO
        }
        uri
    } catch (e: Exception) {
        Log.w(TAG, "Could not persist outgoing MMS", e)
        null
    }
}

/** Shared provider writes for outgoing and incoming MMS. */
object MmsStore {
    fun insertParts(context: Context, messageId: String, parts: List<MmsPdu.Part>) {
        val partUri = Uri.parse("content://mms/$messageId/part")
        for (p in parts) {
            val v = ContentValues().apply {
                put(Telephony.Mms.Part.MSG_ID, messageId)
                put(Telephony.Mms.Part.CONTENT_TYPE, p.contentType)
                put(Telephony.Mms.Part.CONTENT_ID, p.contentId)
                put(Telephony.Mms.Part.CONTENT_LOCATION, p.name)
                put(Telephony.Mms.Part.NAME, p.name)
                if (p.isText) {
                    put(Telephony.Mms.Part.CHARSET, 106)
                    put(Telephony.Mms.Part.TEXT, String(p.data, Charsets.UTF_8))
                }
            }
            val inserted = context.contentResolver.insert(partUri, v) ?: continue
            if (!p.isText && !p.contentType.startsWith("application/smil")) {
                context.contentResolver.openOutputStream(inserted)?.use { it.write(p.data) }
            }
        }
    }

    fun insertAddress(context: Context, messageId: String, address: String, type: Int) {
        val v = ContentValues().apply {
            put(Telephony.Mms.Addr.MSG_ID, messageId)
            put(Telephony.Mms.Addr.ADDRESS, address)
            put(Telephony.Mms.Addr.TYPE, type)
            put(Telephony.Mms.Addr.CHARSET, 106)
        }
        context.contentResolver.insert(Uri.parse("content://mms/$messageId/addr"), v)
    }
}
