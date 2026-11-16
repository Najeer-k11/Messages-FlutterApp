package com.msgs.ndev.app

import android.app.role.RoleManager
import android.content.Context
import android.os.Build
import android.provider.Telephony

/**
 * Whether this app is the default SMS app. On Android 10+ the SMS role is the source of truth;
 * the legacy `sms_default_application` setting read by [Telephony.Sms.getDefaultSmsPackage] can lag
 * behind or be unset (e.g. when the role is granted through `cmd role` / device policy).
 */
object DefaultSmsApp {
    fun isDefault(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val rm = context.getSystemService(RoleManager::class.java)
            if (rm != null && rm.isRoleAvailable(RoleManager.ROLE_SMS)) return rm.isRoleHeld(RoleManager.ROLE_SMS)
        }
        return Telephony.Sms.getDefaultSmsPackage(context) == context.packageName
    }
}
