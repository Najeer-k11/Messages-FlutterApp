package com.msgs.ndev.app

import java.io.ByteArrayOutputStream

/**
 * Minimal encoder/decoder for the OMA MMS Encapsulation (WSP binary) PDUs this app needs:
 *  - encodes m-send-req (outgoing MMS) and m-notifyresp-ind (download acknowledgement)
 *  - decodes m-notification-ind (incoming MMS push) and m-retrieve-conf (downloaded MMS)
 *
 * Android has no public PDU API (com.google.android.mms is hidden), so apps implement this.
 * Reference: OMA-TS-MMS_ENC-V1_3 and WAP-230-WSP.
 */
object MmsPdu {
    // Header field names (well-known, with the high bit set).
    private const val H_CONTENT_TYPE = 0x84
    private const val H_DATE = 0x85
    private const val H_FROM = 0x89
    private const val H_MESSAGE_CLASS = 0x8A
    private const val H_MESSAGE_TYPE = 0x8C
    private const val H_MMS_VERSION = 0x8D
    private const val H_CONTENT_LOCATION = 0x83
    private const val H_STATUS = 0x95
    private const val H_TO = 0x97
    private const val H_TRANSACTION_ID = 0x98

    const val TYPE_SEND_REQ = 0x80
    const val TYPE_NOTIFICATION_IND = 0x82
    const val TYPE_NOTIFYRESP_IND = 0x83
    const val TYPE_RETRIEVE_CONF = 0x84

    private const val MMS_VERSION_1_2 = 0x92

    // Part header / parameter tokens.
    private const val P_CHARSET = 0x81
    private const val P_TYPE = 0x89
    private const val P_START = 0x8A
    private const val P_NAME = 0x85
    private const val PH_CONTENT_LOCATION = 0x8E
    private const val PH_CONTENT_ID = 0xC0
    private const val CHARSET_UTF8 = 0xEA // 106 | 0x80

    /** Well-known content types (WSP Table 40) that matter for messaging. */
    private val WELL_KNOWN_TYPES = mapOf(
        0x00 to "*/*", 0x01 to "text/*", 0x02 to "text/html", 0x03 to "text/plain",
        0x08 to "text/x-vCard", 0x1C to "image/*", 0x1D to "image/gif", 0x1E to "image/jpeg",
        0x1F to "image/tiff", 0x20 to "image/png", 0x21 to "image/vnd.wap.wbmp",
        0x22 to "application/vnd.wap.multipart.*", 0x23 to "application/vnd.wap.multipart.mixed",
        0x33 to "application/vnd.wap.multipart.related", 0x26 to "application/vnd.wap.multipart.alternative",
    )

    class Part(val contentType: String, val data: ByteArray, val name: String, val contentId: String = name) {
        val isText get() = contentType.startsWith("text/plain")
    }

    // ─────────────────────────────────────────────────────────────────────────────────────────
    // Encoding
    // ─────────────────────────────────────────────────────────────────────────────────────────

    /**
     * m-send-req to [recipients] (phone numbers or emails) with [parts]. A SMIL layout part is
     * generated so receivers lay text under the image, as stock messaging apps do.
     */
    fun encodeSendReq(recipients: List<String>, parts: List<Part>, transactionId: String): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(H_MESSAGE_TYPE); out.write(TYPE_SEND_REQ)
        out.write(H_TRANSACTION_ID); writeText(out, transactionId)
        out.write(H_MMS_VERSION); out.write(MMS_VERSION_1_2)
        // From: insert-address-token, filled in by the MMSC.
        out.write(H_FROM); out.write(0x01); out.write(0x81)
        for (r in recipients) {
            out.write(H_TO)
            val addr = if (r.contains('@')) r else "${r.filter { it.isDigit() || it == '+' }}/TYPE=PLMN"
            writeText(out, addr)
        }
        out.write(H_MESSAGE_CLASS); out.write(0x80) // personal

        val smil = Part("application/smil", buildSmil(parts).toByteArray(), "smil.xml", "<smil>")
        val all = listOf(smil) + parts

        // Content-Type must be the last header: multipart/related; type=application/smil; start=<smil>
        out.write(H_CONTENT_TYPE)
        val ct = ByteArrayOutputStream().apply {
            write(0x33 or 0x80)
            write(P_TYPE); writeText(this, "application/smil")
            write(P_START); writeText(this, "<smil>")
        }.toByteArray()
        writeValueLength(out, ct.size); out.write(ct)

        writeUintVar(out, all.size)
        for (p in all) {
            val headers = ByteArrayOutputStream().apply {
                writePartContentType(this, p)
                write(PH_CONTENT_LOCATION); writeText(this, p.name)
                write(PH_CONTENT_ID); write(0x22); writeRawText(this, if (p.contentId.startsWith("<")) p.contentId else "<${p.contentId}>")
            }.toByteArray()
            writeUintVar(out, headers.size)
            writeUintVar(out, p.data.size)
            out.write(headers)
            out.write(p.data)
        }
        return out.toByteArray()
    }

    /** m-notifyresp-ind: tells the MMSC the message was retrieved so it stops re-notifying. */
    fun encodeNotifyResp(transactionId: String): ByteArray = ByteArrayOutputStream().apply {
        write(H_MESSAGE_TYPE); write(TYPE_NOTIFYRESP_IND)
        write(H_TRANSACTION_ID); writeText(this, transactionId)
        write(H_MMS_VERSION); write(MMS_VERSION_1_2)
        write(H_STATUS); write(0x81) // retrieved
    }.toByteArray()

    private fun buildSmil(parts: List<Part>): String {
        val body = parts.joinToString("") { p ->
            when {
                p.isText -> """<text src="${p.name}" region="Text"/>"""
                p.contentType.startsWith("image/") -> """<img src="${p.name}" region="Image"/>"""
                p.contentType.startsWith("video/") -> """<video src="${p.name}" region="Image"/>"""
                else -> """<ref src="${p.name}"/>"""
            }
        }
        return "<smil><head><layout><root-layout/>" +
            """<region id="Image" fit="meet" top="0" left="0" height="80%" width="100%"/>""" +
            """<region id="Text" top="80%" left="0" height="20%" width="100%"/>""" +
            "</layout></head><body><par dur=\"5000ms\">$body</par></body></smil>"
    }

    private fun writePartContentType(out: ByteArrayOutputStream, p: Part) {
        val v = ByteArrayOutputStream()
        writeText(v, p.contentType.substringBefore(';').trim())
        if (p.isText || p.contentType.startsWith("application/smil")) { v.write(P_CHARSET); v.write(CHARSET_UTF8) }
        v.write(P_NAME); writeText(v, p.name)
        val bytes = v.toByteArray()
        writeValueLength(out, bytes.size); out.write(bytes)
    }

    private fun writeText(out: ByteArrayOutputStream, s: String) {
        val b = s.toByteArray(Charsets.UTF_8)
        // A text-string starting with a byte >= 0x80 must be quoted with 0x7F.
        if (b.isNotEmpty() && (b[0].toInt() and 0xFF) >= 0x80) out.write(0x7F)
        out.write(b); out.write(0)
    }

    private fun writeRawText(out: ByteArrayOutputStream, s: String) {
        out.write(s.toByteArray(Charsets.UTF_8)); out.write(0)
    }

    private fun writeValueLength(out: ByteArrayOutputStream, len: Int) {
        if (len <= 30) out.write(len) else { out.write(0x1F); writeUintVar(out, len) }
    }

    private fun writeUintVar(out: ByteArrayOutputStream, value: Int) {
        var v = value
        val stack = ArrayList<Int>()
        stack.add(v and 0x7F)
        v = v ushr 7
        while (v > 0) { stack.add((v and 0x7F) or 0x80); v = v ushr 7 }
        for (i in stack.indices.reversed()) out.write(stack[i])
    }

    // ─────────────────────────────────────────────────────────────────────────────────────────
    // Decoding
    // ─────────────────────────────────────────────────────────────────────────────────────────

    class Decoded(
        val messageType: Int,
        val transactionId: String?,
        val contentLocation: String?,
        val from: String?,
        val dateSeconds: Long?,
        val parts: List<Part>,
    )

    fun decode(pdu: ByteArray): Decoded? = try { Reader(pdu).readPdu() } catch (_: Exception) { null }

    private class Reader(val b: ByteArray) {
        var i = 0

        fun u8() = b[i++].toInt() and 0xFF
        fun peek() = b[i].toInt() and 0xFF

        fun readPdu(): Decoded {
            var type = -1; var tid: String? = null; var loc: String? = null
            var from: String? = null; var date: Long? = null
            var parts = emptyList<Part>()
            while (i < b.size) {
                val name = u8()
                if (name < 0x80) { // application header: text name + text value
                    i--; readText(); readText(); continue
                }
                when (name) {
                    H_MESSAGE_TYPE -> type = u8()
                    H_TRANSACTION_ID -> tid = readText()
                    H_CONTENT_LOCATION -> loc = readText()
                    H_DATE -> date = readLongInteger()
                    H_FROM -> from = readFrom()
                    H_CONTENT_TYPE -> {
                        readContentType()
                        if (type == TYPE_RETRIEVE_CONF) parts = readMultipart()
                        i = b.size
                    }
                    else -> skipValue()
                }
            }
            return Decoded(type, tid, loc, from, date, parts)
        }

        fun readText(): String {
            if (i < b.size && peek() == 0x7F) i++ // quote
            if (i < b.size && peek() == 0x22) i++ // quoted-string
            val start = i
            while (i < b.size && b[i].toInt() != 0) i++
            val s = String(b, start, i - start, Charsets.UTF_8)
            i++ // terminator
            return s
        }

        fun readUintVar(): Int {
            var v = 0
            while (true) {
                val x = u8()
                v = (v shl 7) or (x and 0x7F)
                if (x and 0x80 == 0) return v
            }
        }

        fun readValueLength(): Int {
            val x = u8()
            return if (x <= 30) x else readUintVar() // x == 0x1F
        }

        fun readLongInteger(): Long {
            val len = u8()
            var v = 0L
            repeat(len) { v = (v shl 8) or u8().toLong() }
            return v
        }

        /** Skips any header value using the generic WSP value-form rules. */
        fun skipValue() {
            val x = peek()
            when {
                x >= 0x80 -> i++
                x <= 30 -> { i++; i += x }
                x == 0x1F -> { i++; i += readUintVar() }
                else -> readText()
            }
        }

        /** From: value-length (address-present-token encoded-string | insert-address-token). */
        fun readFrom(): String? {
            val len = readValueLength()
            val end = i + len
            val token = u8()
            val addr = if (token == 0x80) readEncodedString() else null
            i = end
            return addr?.substringBefore("/TYPE")
        }

        fun readEncodedString(): String {
            val x = peek()
            if (x <= 0x1F) { // value-length charset text
                readValueLength(); skipValue()
            }
            return readText()
        }

        /** Returns the media type; skips parameters. */
        fun readContentType(): String {
            val x = peek()
            return when {
                x >= 0x80 -> WELL_KNOWN_TYPES[u8() and 0x7F] ?: "application/octet-stream"
                x >= 0x20 -> readText()
                else -> {
                    val len = readValueLength()
                    val end = i + len
                    val media = if (peek() >= 0x80) WELL_KNOWN_TYPES[u8() and 0x7F] ?: "application/octet-stream"
                                else if (peek() >= 0x20) readText()
                                else { val l = u8(); val v = readIntegerBytes(l); WELL_KNOWN_TYPES[v.toInt()] ?: "application/octet-stream" }
                    i = end
                    media
                }
            }
        }

        fun readIntegerBytes(n: Int): Long { var v = 0L; repeat(n) { v = (v shl 8) or u8().toLong() }; return v }

        fun readMultipart(): List<Part> {
            val count = readUintVar()
            val parts = ArrayList<Part>(count)
            repeat(count) { idx ->
                val headersLen = readUintVar()
                val dataLen = readUintVar()
                val headersEnd = i + headersLen
                val ct = readContentType()
                var location: String? = null
                var cid: String? = null
                while (i < headersEnd) {
                    val h = u8()
                    when {
                        h == PH_CONTENT_LOCATION -> location = readText()
                        h == PH_CONTENT_ID -> cid = readText()
                        h < 0x80 -> { i--; readText(); readText() }
                        else -> skipValue()
                    }
                }
                i = headersEnd
                val data = b.copyOfRange(i, i + dataLen)
                i += dataLen
                val name = location ?: "part$idx"
                parts.add(Part(ct, data, name, cid ?: name))
            }
            return parts
        }
    }
}
