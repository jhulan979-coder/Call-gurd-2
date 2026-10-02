package com.example.call_guard

import android.Manifest
import android.annotation.TargetApi
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.telecom.Call
import android.telecom.CallScreeningService
import android.telecom.CallScreeningService.CallResponse
import org.json.JSONArray

@TargetApi(29)
class CallGuardScreeningService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        var response = CallResponse.Builder().build()
        try {
            if (callDetails.callDirection == Call.Details.DIRECTION_INCOMING) {
                val raw = callDetails.handle?.schemeSpecificPart ?: ""
                val digits = raw.filter { it.isDigit() }
                val n = if (digits.length > 10) digits.substring(digits.length - 10) else digits
                val name = findName(callDetails, raw)
                val shown = if (!name.isNullOrEmpty()) name else n
                val label = if (n.length == 10) findLabel(n) else null
                if (label != null) {
                    response = CallResponse.Builder()
                        .setDisallowCall(true)
                        .setRejectCall(true)
                        .setSkipNotification(true)
                        .build()
                    show("callguard_alerts", "Call Guard alerts", "Call block hua", "$shown ($label) ko block kiya gaya")
                } else {
                    val spam = n.startsWith("140") || n.startsWith("160")
                    val status = if (spam) {
                        "Shak: telemarketing number"
                    } else if (!name.isNullOrEmpty()) {
                        "Naam mil gaya"
                    } else {
                        "Unknown number"
                    }
                    val title = if (!name.isNullOrEmpty()) name else "Unknown caller"
                    val numText = if (raw.isNotEmpty()) raw else "Number chhupa hua hai"
                    if (spam) speakSpam()
                    show("callguard_info", "Caller ka naam", title, "$numText  |  $status")
                }
            }
        } catch (e: Exception) {
        }
        respondToCall(callDetails, response)
    }

    private fun speakSpam() {
        try {
            var tts: android.speech.tts.TextToSpeech? = null
            tts = android.speech.tts.TextToSpeech(applicationContext) { st ->
                if (st == android.speech.tts.TextToSpeech.SUCCESS) {
                    tts?.language = java.util.Locale("en", "IN")
                    tts?.speak("Spam caller", android.speech.tts.TextToSpeech.QUEUE_FLUSH, null, "spam")
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({ tts?.shutdown() }, 8000)
                }
            }
        } catch (e: Exception) {
        }
    }

    private fun findName(d: Call.Details, raw: String): String? {
        try {
            val a = d.callerDisplayName
            if (!a.isNullOrEmpty()) return a
        } catch (e: Throwable) {
        }
        return lookupContact(raw)
    }

    private fun lookupContact(raw: String): String? {
        if (raw.isEmpty()) return null
        if (checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) return null
        try {
            val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(raw))
            val c = contentResolver.query(uri, arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null)
            c?.use {
                if (it.moveToFirst()) return it.getString(0)
            }
        } catch (e: Exception) {
        }
        return null
    }

    private fun findLabel(n: String): String? {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val s = prefs.getString("flutter.blocked_v2", null) ?: return null
        val arr = JSONArray(s)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optString("n") == n) return o.optString("l", "Spam")
        }
        return null
    }

    private fun show(channelId: String, channelName: String, title: String, text: String) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
                )
            }
            val b = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(this, channelId)
            } else {
                Notification.Builder(this)
            }
            b.setSmallIcon(android.R.drawable.ic_menu_call)
            b.setContentTitle(title)
            b.setContentText(text)
            b.setAutoCancel(true)
            b.setVisibility(Notification.VISIBILITY_PUBLIC)
            if (Build.VERSION.SDK_INT >= 26) {
                b.setTimeoutAfter(60000)
            }
            nm.notify((System.currentTimeMillis() % 100000).toInt(), b.build())
        } catch (e: Exception) {
        }
    }
}
