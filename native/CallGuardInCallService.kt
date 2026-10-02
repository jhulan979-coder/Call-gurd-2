package com.example.call_guard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.telecom.Call
import android.telecom.InCallService

const val CG_NOTIF_ID = 7001

object CallHolder {
    var call: Call? = null
    var service: InCallService? = null

    fun lookup(ctx: Context, raw: String): String? {
        if (raw.isEmpty()) return null
        if (ctx.checkSelfPermission(android.Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) return null
        try {
            val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(raw))
            val cur = ctx.contentResolver.query(uri, arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null)
            cur?.use {
                if (it.moveToFirst()) return it.getString(0)
            }
        } catch (e: Exception) {
        }
        return null
    }

    fun label(ctx: Context, c: Call): String {
        try {
            val d = c.details
            val raw = d.handle?.schemeSpecificPart ?: ""
            val name = d.callerDisplayName
            if (!name.isNullOrEmpty()) return name
            val found = lookup(ctx, raw)
            if (!found.isNullOrEmpty()) return found
            if (raw.isNotEmpty()) return raw
        } catch (e: Exception) {
        }
        return "Unknown"
    }
}

class CallGuardInCallService : InCallService() {

    private val cb = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            if (state != Call.STATE_RINGING) {
                cancelNotif()
            }
        }
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        CallHolder.call = call
        CallHolder.service = this
        call.registerCallback(cb)
        if (call.state == Call.STATE_RINGING) {
            showIncoming(call)
        } else {
            openUi()
        }
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        try {
            call.unregisterCallback(cb)
        } catch (e: Exception) {
        }
        if (CallHolder.call == call) {
            CallHolder.call = null
        }
        cancelNotif()
    }

    private fun openUi() {
        try {
            val i = Intent(this, InCallActivity::class.java)
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(i)
        } catch (e: Exception) {
        }
    }

    private fun showIncoming(call: Call) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel("cg_incall", "Incoming calls", NotificationManager.IMPORTANCE_HIGH)
                )
            }
            val i = Intent(this, InCallActivity::class.java)
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pi = PendingIntent.getActivity(this, 0, i, flags)
            val b = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(this, "cg_incall")
            } else {
                Notification.Builder(this)
            }
            b.setSmallIcon(android.R.drawable.ic_menu_call)
            b.setContentTitle("Incoming call")
            b.setContentText(CallHolder.label(this, call))
            b.setContentIntent(pi)
            b.setFullScreenIntent(pi, true)
            b.setOngoing(true)
            b.setCategory(Notification.CATEGORY_CALL)
            nm.notify(CG_NOTIF_ID, b.build())
        } catch (e: Exception) {
        }
        openUi()
    }

    private fun cancelNotif() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(CG_NOTIF_ID)
        } catch (e: Exception) {
        }
    }
}
