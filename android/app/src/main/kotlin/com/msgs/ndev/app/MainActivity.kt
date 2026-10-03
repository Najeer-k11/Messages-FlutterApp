package com.msgs.ndev.app

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.provider.ContactsContract
import android.provider.Telephony
import android.telephony.SmsManager
import android.app.PendingIntent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.msgs.ndevmsgs/sms"
    private var methodChannel: MethodChannel? = null
    private var smsObserver: ContentObserver? = null
    private var pendingIntentData: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerSmsObserver()
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val data = intent.data
        var address: String? = null
        var body: String? = null

        if (action == Intent.ACTION_SENDTO || action == Intent.ACTION_VIEW) {
            if (data != null) {
                val scheme = data.scheme
                if (scheme == "sms" || scheme == "smsto" || scheme == "mms" || scheme == "mmsto") {
                    var ssp = data.schemeSpecificPart ?: ""
                    if (ssp.contains("?")) {
                        val parts = ssp.split("?", limit = 2)
                        ssp = parts[0]
                        val query = parts[1]
                        val queryUri = Uri.parse("sms://host?$query")
                        body = queryUri.getQueryParameter("body")
                    }
                    address = Uri.decode(ssp)
                }
            }
            // Notification deeplink: address passed as extra
            if (address.isNullOrBlank()) {
                address = intent.getStringExtra(SmsReceiver.EXTRA_SENDER)
            }
        } else if (action == Intent.ACTION_SEND) {
            body = intent.getStringExtra(Intent.EXTRA_TEXT)
            address = intent.getStringExtra("android.intent.extra.PHONE_NUMBER")
                ?: intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
        } else {
            // Check for notification deeplink extra regardless of action
            val notifSender = intent.getStringExtra(SmsReceiver.EXTRA_SENDER)
            if (!notifSender.isNullOrBlank()) {
                address = notifSender
            }
        }

        if (address != null || body != null) {
            val dataMap = mapOf(
                "address" to (address ?: ""),
                "body" to (body ?: "")
            )
            pendingIntentData = dataMap
            methodChannel?.invokeMethod("onNewIntentReceived", dataMap)
        }
    }

    override fun onDestroy() {
        unregisterSmsObserver()
        super.onDestroy()
    }

    private fun registerSmsObserver() {
        val handler = Handler(Looper.getMainLooper())
        smsObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean) {
                super.onChange(selfChange)
                methodChannel?.invokeMethod("onSmsReceived", null)
            }
        }
        contentResolver.registerContentObserver(
            Uri.parse("content://sms"),
            true,
            smsObserver!!
        )
    }

    private fun unregisterSmsObserver() {
        smsObserver?.let {
            contentResolver.unregisterContentObserver(it)
            smsObserver = null
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler {
            call, result ->
            when (call.method) {
                "getPendingIntentData" -> {
                    result.success(pendingIntentData)
                    pendingIntentData = null
                }
                "getAllSms" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val smsList = getAllSms()
                            withContext(Dispatchers.Main) {
                                result.success(smsList)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("SMS_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "sendSms" -> {
                    val address = call.argument<String>("address")
                    val body = call.argument<String>("body")
                    if (address != null && body != null) {
                        sendSms(address, body, result)
                    } else {
                        result.error("INVALID_ARGS", "Address or body is null", null)
                    }
                }
                "isDefaultSmsApp" -> {
                    val isDefault = Telephony.Sms.getDefaultSmsPackage(context) == packageName
                    result.success(isDefault)
                }
                "requestDefaultSmsApp" -> {
                    if (Telephony.Sms.getDefaultSmsPackage(context) == packageName) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
                            if (roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
                                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } else {
                            val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                            intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                            startActivity(intent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("ROLE_ERROR", e.message, null)
                    }
                }
                "deleteThread" -> {
                    val threadId = call.argument<String>("threadId")
                    if (threadId == null) {
                        result.error("INVALID_ARGS", "threadId is null", null)
                        return@setMethodCallHandler
                    }
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val deleted = deleteThread(threadId)
                            withContext(Dispatchers.Main) {
                                result.success(deleted)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("DELETE_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "deleteSms" -> {
                    val messageId = call.argument<String>("messageId")
                    if (messageId == null) {
                        result.error("INVALID_ARGS", "messageId is null", null)
                        return@setMethodCallHandler
                    }
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val deleted = deleteSms(messageId)
                            withContext(Dispatchers.Main) {
                                result.success(deleted)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("DELETE_SMS_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "markThreadAsRead" -> {
                    val threadId = call.argument<String>("threadId")
                    if (threadId == null) {
                        result.error("INVALID_ARGS", "threadId is null", null)
                        return@setMethodCallHandler
                    }
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            markThreadAsRead(threadId)
                            withContext(Dispatchers.Main) {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("MARK_READ_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getContacts" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val contacts = getContacts()
                            withContext(Dispatchers.Main) {
                                result.success(contacts)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("CONTACTS_ERROR", e.message, null)
                            }
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getContactName(context: Context, phoneNumber: String): String? {
        if (phoneNumber.isBlank() || phoneNumber.contains("insert-address")) return null
        val uri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(phoneNumber)
        )
        val projection = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)
        return try {
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.PhoneLookup.DISPLAY_NAME))
                } else null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun getMmsAddress(mmsId: String, msgBox: Int): String {
        val uri = Uri.parse("content://mms/$mmsId/addr")
        val projection = arrayOf("address", "type")
        var address = ""
        try {
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                val addressIdx = cursor.getColumnIndexOrThrow("address")
                val typeIdx = cursor.getColumnIndexOrThrow("type")
                
                val targetType = if (msgBox == 1) 137 else 151
                var fallbackAddress = ""
                while (cursor.moveToNext()) {
                    val addr = cursor.getString(addressIdx) ?: continue
                    val type = cursor.getInt(typeIdx)
                    if (type == targetType) {
                        address = addr
                        break
                    }
                    if (fallbackAddress.isEmpty() && addr.isNotBlank() && !addr.contains("insert-address")) {
                        fallbackAddress = addr
                    }
                }
                if (address.isEmpty()) {
                    address = fallbackAddress
                }
            }
        } catch (e: Exception) {
            // Ignore
        }
        return if (address.isBlank() || address.contains("insert-address")) "Unknown" else address
    }

    private fun getMmsBody(mmsId: String): String {
        val uri = Uri.parse("content://mms/part")
        val projection = arrayOf("ct", "text")
        val selection = "mid = ?"
        val selectionArgs = arrayOf(mmsId)
        var body = ""
        var hasMedia = false
        try {
            contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
                val ctIdx = cursor.getColumnIndexOrThrow("ct")
                val textIdx = cursor.getColumnIndexOrThrow("text")
                while (cursor.moveToNext()) {
                    val ct = cursor.getString(ctIdx) ?: continue
                    if (ct == "text/plain") {
                        body = cursor.getString(textIdx) ?: ""
                    } else if (ct.startsWith("image/") || ct.startsWith("video/") || ct.startsWith("audio/")) {
                        hasMedia = true
                    }
                }
            }
        } catch (e: Exception) {
            // Ignore
        }
        if (body.isEmpty() && hasMedia) {
            return "[Multimedia Message]"
        }
        return body
    }

    private fun getAllSms(): List<Map<String, Any>> {
        val combinedList = mutableListOf<Map<String, Any>>()
        
        // 1. Fetch SMS
        val smsUri: Uri = Telephony.Sms.CONTENT_URI
        val smsProjection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ,
            Telephony.Sms.THREAD_ID,
        )

        try {
            contentResolver.query(smsUri, smsProjection, null, null, null)?.use { cursor ->
                val idIndex = cursor.getColumnIndexOrThrow(Telephony.Sms._ID)
                val addressIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val bodyIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val dateIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
                val typeIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.TYPE)
                val readIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.READ)
                val threadIdIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)

                while (cursor.moveToNext()) {
                    val address = cursor.getString(addressIndex) ?: "Unknown"
                    combinedList.add(mapOf(
                        "id" to "sms_" + cursor.getString(idIndex),
                        "address" to address,
                        "body" to (cursor.getString(bodyIndex) ?: ""),
                        "date" to cursor.getLong(dateIndex),
                        "type" to cursor.getInt(typeIndex),
                        "read" to cursor.getInt(readIndex),
                        "thread_id" to (cursor.getString(threadIdIndex) ?: "")
                    ))
                }
            }
        } catch (e: Exception) {
            // Ignore/log
        }

        // 2. Fetch MMS
        val mmsUri = Uri.parse("content://mms")
        val mmsProjection = arrayOf(
            "_id",
            "date",
            "msg_box",
            "read",
            "thread_id"
        )

        try {
            contentResolver.query(mmsUri, mmsProjection, null, null, null)?.use { cursor ->
                val idIdx = cursor.getColumnIndexOrThrow("_id")
                val dateIdx = cursor.getColumnIndexOrThrow("date")
                val msgBoxIdx = cursor.getColumnIndexOrThrow("msg_box")
                val readIdx = cursor.getColumnIndexOrThrow("read")
                val threadIdIdx = cursor.getColumnIndexOrThrow("thread_id")

                while (cursor.moveToNext()) {
                    val mmsId = cursor.getString(idIdx)
                    val msgBox = cursor.getInt(msgBoxIdx)
                    val address = getMmsAddress(mmsId, msgBox)
                    val body = getMmsBody(mmsId)
                    val date = cursor.getLong(dateIdx)
                    combinedList.add(mapOf(
                        "id" to "mms_" + mmsId,
                        "address" to address,
                        "body" to body,
                        "date" to (date * 1000), // MMS dates are in seconds
                        "type" to msgBox,
                        "read" to cursor.getInt(readIdx),
                        "thread_id" to (cursor.getString(threadIdIdx) ?: "")
                    ))
                }
            }
        } catch (e: Exception) {
            // Ignore/log
        }

        // 3. Perform native PhoneLookup for unique addresses
        val uniqueAddresses = combinedList.map { it["address"] as String }.distinct()
        val contactsMap = mutableMapOf<String, String>()
        for (addr in uniqueAddresses) {
            val name = getContactName(context, addr)
            if (name != null) {
                contactsMap[addr] = name
            }
        }

        // 4. Attach sender_name
        val finalList = combinedList.map { item ->
            val address = item["address"] as String
            val senderName = contactsMap[address] ?: address
            item.toMutableMap().apply {
                put("sender_name", senderName)
            }
        }

        return finalList.sortedByDescending { (it["date"] as Long) }
    }

    private fun deleteThread(threadId: String): Int {
        // Delete all SMS in this thread natively from the provider
        val smsUri = Uri.parse("content://sms")
        val deleted = contentResolver.delete(smsUri, "thread_id = ?", arrayOf(threadId))
        // MMS cleanup (best-effort)
        try {
            val mmsUri = Uri.parse("content://mms")
            contentResolver.delete(mmsUri, "thread_id = ?", arrayOf(threadId))
        } catch (_: Exception) {}
        return deleted
    }

    private fun deleteSms(messageId: String): Int {
        return if (messageId.startsWith("mms_")) {
            val id = messageId.substringAfter("mms_")
            val uri = Uri.parse("content://mms/$id")
            contentResolver.delete(uri, null, null)
        } else {
            val id = messageId.substringAfter("sms_")
            val uri = Uri.parse("content://sms/$id")
            contentResolver.delete(uri, null, null)
        }
    }

    private fun markThreadAsRead(threadId: String) {
        val values = android.content.ContentValues()
        values.put("read", 1)
        values.put("seen", 1)
        contentResolver.update(
            Uri.parse("content://sms"),
            values,
            "thread_id = ? AND read = 0",
            arrayOf(threadId)
        )
        try {
            contentResolver.update(
                Uri.parse("content://mms"),
                values,
                "thread_id = ? AND read = 0",
                arrayOf(threadId)
            )
        } catch (_: Exception) {}
    }

    private fun getContacts(): List<Map<String, String>> {
        val contacts = mutableListOf<Map<String, String>>()
        val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
        )
        val cursor = contentResolver.query(
            uri, projection, null, null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
        )
        cursor?.use {
            val nameIndex = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIndex = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (it.moveToNext()) {
                val name = it.getString(nameIndex) ?: ""
                val number = it.getString(numberIndex) ?: ""
                if (number.isNotBlank()) {
                    contacts.add(mapOf("name" to name, "number" to number))
                }
            }
        }
        return contacts
    }

    private fun sendSms(address: String, body: String, result: MethodChannel.Result) {
        try {
            val smsManager: SmsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            // Write the message to the sent folder first to get an ID for status updates
            val messageUri = writeSmsToSentFolder(context, address, body)
            val messageId = messageUri?.lastPathSegment ?: ""

            // Build sent/delivered PendingIntents for status tracking
            val sentIntent = Intent(SmsStatusReceiver.ACTION_SMS_SENT).apply {
                setClass(this@MainActivity, SmsStatusReceiver::class.java)
                putExtra(SmsStatusReceiver.EXTRA_MESSAGE_ID, "sms_$messageId")
            }
            val deliveredIntent = Intent(SmsStatusReceiver.ACTION_SMS_DELIVERED).apply {
                setClass(this@MainActivity, SmsStatusReceiver::class.java)
                putExtra(SmsStatusReceiver.EXTRA_MESSAGE_ID, "sms_$messageId")
            }
            val requestCode = System.currentTimeMillis().toInt()
            val sentPendingIntent = PendingIntent.getBroadcast(
                this, requestCode, sentIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val deliveredPendingIntent = PendingIntent.getBroadcast(
                this, requestCode + 1, deliveredIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val parts = smsManager.divideMessage(body)
            if (parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent>(parts.size).also { list ->
                    repeat(parts.size) { list.add(sentPendingIntent) }
                }
                smsManager.sendMultipartTextMessage(address, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(address, null, body, sentPendingIntent, deliveredPendingIntent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("SEND_SMS_ERROR", e.message, null)
        }
    }

    private fun writeSmsToSentFolder(context: Context, address: String, body: String): android.net.Uri? {
        return try {
            val values = android.content.ContentValues().apply {
                put(Telephony.Sms.ADDRESS, address)
                put(Telephony.Sms.BODY, body)
                put(Telephony.Sms.DATE, System.currentTimeMillis())
                put(Telephony.Sms.READ, 1)
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
                put("status", Telephony.Sms.STATUS_NONE) // pending
            }
            context.contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
        } catch (_: Exception) { null }
    }
}

