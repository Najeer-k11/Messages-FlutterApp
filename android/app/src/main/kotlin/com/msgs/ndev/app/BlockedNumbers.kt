package com.msgs.ndev.app

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.provider.BlockedNumberContract
import android.provider.BlockedNumberContract.BlockedNumbers as Table

/**
 * The system block list (shared with the Phone app). Only the default SMS app, the default dialer
 * and carrier apps may read or write it, so every call degrades to "not blocked" / no-op otherwise.
 * The telephony stack itself drops SMS from numbers on this list; we also check it ourselves so
 * MMS and existing history from blocked senders stay out of the inbox.
 */
object BlockedNumbers {
    private val supported get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N

    fun canBlock(context: Context): Boolean =
        supported && try { BlockedNumberContract.canCurrentUserBlockNumbers(context) } catch (_: Exception) { false }

    fun isBlocked(context: Context, address: String): Boolean =
        supported && address.isNotBlank() &&
            try { BlockedNumberContract.isBlocked(context, address) } catch (_: Exception) { false }

    fun block(context: Context, address: String): Boolean {
        if (!supported || address.isBlank()) return false
        if (isBlocked(context, address)) return true
        val values = ContentValues().apply { put(Table.COLUMN_ORIGINAL_NUMBER, address) }
        return context.contentResolver.insert(Table.CONTENT_URI, values) != null
    }

    fun unblock(context: Context, address: String): Boolean {
        if (!supported || address.isBlank()) return false
        return BlockedNumberContract.unblock(context, address) > 0
    }

    fun list(context: Context): List<String> {
        if (!supported) return emptyList()
        val out = mutableListOf<String>()
        context.contentResolver.query(
            Table.CONTENT_URI, arrayOf(Table.COLUMN_ORIGINAL_NUMBER), null, null, Table.COLUMN_ID + " DESC",
        )?.use { c ->
            val i = c.getColumnIndexOrThrow(Table.COLUMN_ORIGINAL_NUMBER)
            while (c.moveToNext()) c.getString(i)?.takeIf { it.isNotBlank() }?.let(out::add)
        }
        return out
    }
}
