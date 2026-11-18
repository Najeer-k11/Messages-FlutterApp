package com.msgs.ndev.app

import android.content.Context

/**
 * Conversations that must not notify: muted, or reported as spam. Flutter owns the real settings
 * (in Isar) and mirrors this list here, because broadcast receivers run without the Flutter engine
 * and cannot read the app database.
 */
object SilencedThreads {
    private const val PREFS = "thread_prefs"
    private const val KEY = "silenced"

    /** Same rules as SmsRepository.normalizeAddress in Dart, so both sides agree on keys. */
    fun normalize(address: String): String {
        val clean = address.trim()
        return if (clean.any { it.isLetter() }) clean.replace(Regex("\\s+"), "")
               else clean.replace(Regex("[\\s\\-()]+"), "")
    }

    fun set(context: Context, addresses: Collection<String>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putStringSet(KEY, addresses.map(::normalize).toSet())
            .apply()
    }

    fun isSilenced(context: Context, address: String): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY, emptySet())!!
            .contains(normalize(address))
}
