package com.example.call_guard

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telecom.TelecomManager

object DialerRole {
    fun isDefault(ctx: Context): Boolean {
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                val rm = ctx.getSystemService(Context.ROLE_SERVICE) as RoleManager
                return rm.isRoleHeld(RoleManager.ROLE_DIALER)
            }
            val tm = ctx.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            return ctx.packageName == tm.defaultDialerPackage
        } catch (e: Throwable) {
        }
        return false
    }

    fun request(act: Activity) {
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                val rm = act.getSystemService(Context.ROLE_SERVICE) as RoleManager
                if (rm.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                    act.startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_DIALER), 2002)
                    return
                }
            }
            val i = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
            i.putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, act.packageName)
            act.startActivity(i)
        } catch (e: Throwable) {
        }
    }
}
