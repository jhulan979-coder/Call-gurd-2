package com.example.call_guard

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telecom.Call
import android.telephony.SmsManager

object AutoSms {
     private fun pick(): String {
        val hr = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
        if (hr >= 22 || hr < 7) {
            return "Abhi raat ka samay hai, isliye call nahi utha paaya. Subah wapas call karunga."
        }
        if (hr in 9..18) {
            return "Main abhi busy hun, call nahi utha paaya. Thodi der me wapas call karunga."
        }
        return "Main abhi call nahi utha paaya. Thodi der me wapas call karunga."
    }
    fun reply(ctx: Context, call: Call) {
        try {
            val fp = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (!fp.getBoolean("flutter.autoSms", false)) return
            val raw = call.details.handle?.schemeSpecificPart ?: return
            val digits = raw.filter { it.isDigit() }
            val n = if (digits.length > 10) digits.substring(digits.length - 10) else digits
            if (n.length != 10 || n.startsWith("140") || n.startsWith("160")) return
            if (ctx.checkSelfPermission(android.Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                CgLog.add(ctx, "SMS permission nahi hai")
                return
            }
            val sp = ctx.getSharedPreferences("cg_autosms", Context.MODE_PRIVATE)
            val last = sp.getLong(n, 0L)
            if (System.currentTimeMillis() - last < 3600000L) return
            val sm = if (Build.VERSION.SDK_INT >= 31) ctx.getSystemService(SmsManager::class.java) else SmsManager.getDefault()
            sm.sendTextMessage(raw, null, pick(), null, null)
            sp.edit().putLong(n, System.currentTimeMillis()).apply()
            CgLog.add(ctx, "SMS bheja " + n)
        } catch (e: Throwable) {
            try { CgLog.add(ctx, "SMS FAIL " + e.toString()) } catch (x: Throwable) {}
        }
    }
}
