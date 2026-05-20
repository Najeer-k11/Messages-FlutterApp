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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerSmsObserver()
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

    private fun getAllSms(): List<Map<String, Any>> {
        val smsList = mutableListOf<Map<String, Any>>()
        val uri: Uri = Telephony.Sms.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ,
            Telephony.Sms.THREAD_ID,
        )

        val cursor: Cursor? = contentResolver.query(uri, projection, null, null, Telephony.Sms.DEFAULT_SORT_ORDER)

        cursor?.use {
            val idIndex = it.getColumnIndexOrThrow(Telephony.Sms._ID)
            val addressIndex = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyIndex = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateIndex = it.getColumnIndexOrThrow(Telephony.Sms.DATE)
            val typeIndex = it.getColumnIndexOrThrow(Telephony.Sms.TYPE)
            val readIndex = it.getColumnIndexOrThrow(Telephony.Sms.READ)
            val threadIdIndex = it.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)

            while (it.moveToNext()) {
                val smsMap = mapOf(
                    "id" to it.getString(idIndex),
                    "address" to (it.getString(addressIndex) ?: "Unknown"),
                    "body" to (it.getString(bodyIndex) ?: ""),
                    "date" to it.getLong(dateIndex),
                    "type" to it.getInt(typeIndex),
                    "read" to it.getInt(readIndex),
                    "thread_id" to it.getString(threadIdIndex)
                )
                smsList.add(smsMap)
            }
        }
        return smsList
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
        val uri = Uri.parse("content://sms/$messageId")
        return contentResolver.delete(uri, null, null)
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
            val smsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(body)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(address, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(address, null, body, null, null)
            }
            writeSmsToSentFolder(context, address, body)
            result.success(true)
        } catch (e: Exception) {
            result.error("SEND_SMS_ERROR", e.message, null)
        }
    }

    private fun writeSmsToSentFolder(context: Context, address: String, body: String) {
        try {
            val values = android.content.ContentValues().apply {
                put(Telephony.Sms.ADDRESS, address)
                put(Telephony.Sms.BODY, body)
                put(Telephony.Sms.DATE, System.currentTimeMillis())
                put(Telephony.Sms.READ, 1) // 1 = read
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
            }
            context.contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
        } catch (e: Exception) {
            // Ignore if write fails (e.g. not default SMS app)
        }
    }
}
