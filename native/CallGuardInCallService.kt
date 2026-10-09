
package com.example.call_guard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.speech.tts.TextToSpeech
import android.telecom.Call
import android.telecom.DisconnectCause
import android.telecom.InCallService
import android.telecom.TelecomManager
import android.telecom.VideoProfile
import android.widget.Toast
import com.google.i18n.phonenumbers.PhoneNumberUtil
import com.google.i18n.phonenumbers.geocoding.PhoneNumberOfflineGeocoder
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

const val CG_NOTIF_ID = 7001

object CallHolder {
    var call: Call? = null
    var service: InCallService? = null
    val circles = HashMap<String, String>()

    fun circleFor(num: String): String {
        val c = circles[num] ?: return ""
        return "  |  " + c
    }

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

    fun circle(raw: String): String? {
        try {
            if (raw.isEmpty()) return null
            val p = PhoneNumberUtil.getInstance().parse(raw, "IN")
            val s = PhoneNumberOfflineGeocoder.getInstance().getDescriptionForNumber(p, Locale.ENGLISH)
            if (!s.isNullOrEmpty() && !s.equals("India", true)) return s
        } catch (e: Throwable) {
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
    private var sm: SensorManager? = null
    private var ttsRef: TextToSpeech? = null
    private val autoCalls = HashSet<Call>()
    private val incomingCalls = HashSet<Call>()
    private val answeredCalls = HashSet<Call>()
    private val infoMap = HashMap<Call, String>()
    private var missedCounter = 0
    private val h = Handler(Looper.getMainLooper())

    private fun prefs(): SharedPreferences {
        return getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    private fun flipOn(): Boolean {
        return prefs().getBoolean("flutter.flip", true)
    }

    private val flip = object : SensorEventListener {
        override fun onSensorChanged(e: SensorEvent) {
            if (e.values.size > 2 && e.values[2] < -6.0f) {
                stopFlip()
                var ok = true
                try {
                    val tm = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                    tm.silenceRinger()
                } catch (x: Throwable) {
                    ok = false
                }
                try {
                    Toast.makeText(
                        applicationContext,
                        if (ok) "Silenced" else "Silence failed",
                        Toast.LENGTH_SHORT
                    ).show()
                } catch (x: Throwable) {
                }
            }
        }

        override fun onAccuracyChanged(s: Sensor?, a: Int) {
        }
    }

    private val cb = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            val s = this@CallGuardInCallService
            if (state != Call.STATE_RINGING) {
                s.stopFlip()
            }
            if (state == Call.STATE_ACTIVE) {
                s.answeredCalls.add(call)
                if (s.autoCalls.contains(call)) {
                    try {
                        s.setMuted(true)
                    } catch (x: Throwable) {
                    }
                    s.h.postDelayed({
                        try {
                            call.disconnect()
                        } catch (x: Throwable) {
                        }
                    }, 30000)
                } else {
                    s.stopSpeech()
                    try {
                        s.setMuted(false)
                    } catch (x: Throwable) {
                    }
                }
            }
            if (state == Call.STATE_ACTIVE || state == Call.STATE_DIALING ||
                state == Call.STATE_CONNECTING || state == Call.STATE_HOLDING
            ) {
                if (!s.autoCalls.contains(call)) {
                    s.postOngoing(call, state)
                }
            }
        }
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        CallHolder.call = call
        CallHolder.service = this
        call.registerCallback(cb)
        try {
            val raw = call.details.handle?.schemeSpecificPart ?: ""
            val lab = CallHolder.label(this, call)
            infoMap[call] = if (raw.isEmpty() || lab == raw) lab else lab + "  |  " + raw
        } catch (e: Throwable) {
        }
        if (call.state == Call.STATE_RINGING) {
            incomingCalls.add(call)
           AiGuess.check(applicationContext, call)
            if (shouldAutoAnswer(call)) {
                startAutoAnswer(call)
            } else {
                showIncoming(call)
                announce(call)
                if (flipOn()) startFlip()
            }
        } else {
            openUi()
            postOngoing(call, call.state)
        }
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        try {
            call.unregisterCallback(cb)
        } catch (e: Exception) {
        }
        val wasIncoming = incomingCalls.remove(call)
        val answered = answeredCalls.remove(call)
        val auto = autoCalls.remove(call)
        val info = infoMap.remove(call) ?: "Unknown"
        var cause = -1
        try {
            cause = call.details.disconnectCause?.code ?: -1
        } catch (e: Throwable) {
        }
        if (CallHolder.call == call) {
            CallHolder.call = null
        }
        cancelNotif()
        stopFlip()
        stopSpeech()
        if (wasIncoming && !answered && !auto &&
            cause != DisconnectCause.REJECTED && cause != DisconnectCause.LOCAL
        ) {
            postMissed(info)
            AutoSms.reply(this, call)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopFlip()
        stopSpeech()
    }

    private fun isSpamNum(n: String): Boolean {
        if (n.startsWith("140") || n.startsWith("160")) return true
        try {
            val s = prefs().getString("flutter.blocked_v2", null) ?: return false
            val arr = JSONArray(s)
            for (i in 0 until arr.length()) {
                if (arr.getJSONObject(i).optString("n") == n) return true
            }
        } catch (e: Throwable) {
        }
        return false
    }

    private fun shouldAutoAnswer(call: Call): Boolean {
        try {
            if (!prefs().getBoolean("flutter.spamAnswer", false)) return false
            val raw = call.details.handle?.schemeSpecificPart ?: ""
            val digits = raw.filter { it.isDigit() }
            val n = if (digits.length > 10) digits.substring(digits.length - 10) else digits
            if (n.length != 10) return false
            val dn = call.details.callerDisplayName
            if (!dn.isNullOrEmpty()) return false
            val saved = CallHolder.lookup(this, raw)
            if (!saved.isNullOrEmpty()) return false
            return isSpamNum(n)
        } catch (e: Throwable) {
        }
        return false
    }

    private fun startAutoAnswer(call: Call) {
        autoCalls.add(call)
        try {
            val tm = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            tm.silenceRinger()
        } catch (x: Throwable) {
        }
        info("Spam call apne aap uthayi", CallHolder.label(this, call))
        h.postDelayed({
            try {
                call.answer(VideoProfile.STATE_AUDIO_ONLY)
            } catch (x: Throwable) {
            }
        }, 600)
    }

    private fun info(title: String, text: String) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel("cg_auto", "Spam auto answer", NotificationManager.IMPORTANCE_DEFAULT)
                )
            }
            val b = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(this, "cg_auto")
            } else {
                Notification.Builder(this)
            }
            b.setSmallIcon(android.R.drawable.ic_menu_call)
            b.setContentTitle(title)
            b.setContentText(text)
            b.setAutoCancel(true)
            nm.notify((System.currentTimeMillis() % 100000).toInt() + 100, b.build())
        } catch (e: Exception) {
        }
    }

    private fun startFlip() {
        try {
            sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            val s = sm?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            if (s != null) {
                sm?.registerListener(flip, s, SensorManager.SENSOR_DELAY_NORMAL)
            }
        } catch (e: Throwable) {
        }
    }

    private fun stopFlip() {
        try {
            sm?.unregisterListener(flip)
        } catch (e: Throwable) {
        }
    }

    private fun stopSpeech() {
        try {
            ttsRef?.stop()
        } catch (e: Throwable) {
        }
        try {
            ttsRef?.shutdown()
        } catch (e: Throwable) {
        }
        ttsRef = null
    }

    private fun speak(text: String) {
        try {
            if (!prefs().getBoolean("flutter.announce", true)) return
            stopSpeech()
            var t: TextToSpeech? = null
            t = TextToSpeech(applicationContext) { st ->
                if (st == TextToSpeech.SUCCESS) {
                    if (CallHolder.call?.state != Call.STATE_ACTIVE) {
                        t?.language = Locale("en", "IN")
                        t?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "cg")
                        Handler(Looper.getMainLooper()).postDelayed({ t?.shutdown() }, 8000)
                    } else {
                        t?.shutdown()
                    }
                }
            }
            ttsRef = t
        } catch (e: Throwable) {
        }
    }

    private fun announce(call: Call) {
        try {
            val raw = call.details.handle?.schemeSpecificPart ?: ""
            val digits = raw.filter { it.isDigit() }
            val n = if (digits.length > 10) digits.substring(digits.length - 10) else digits
            if (n.startsWith("140") || n.startsWith("160")) return
            val name = call.details.callerDisplayName
            val saved = if (!name.isNullOrEmpty()) name else CallHolder.lookup(this, raw)
            if (!saved.isNullOrEmpty()) {
                speak(saved + " calling")
                return
            }
            val off = CallHolder.circle(raw)
            if (off != null) {
                CallHolder.circles[n] = off
                speak("Unknown number from " + off)
                return
            }
            if (!prefs().getBoolean("flutter.onlineCircle", false) || n.length != 10) {
                speak("Unknown number")
                return
            }
            val ctx = applicationContext
            Thread {
                val c = CircleLookup.get(ctx, n)
                Handler(Looper.getMainLooper()).post {
                    if (c != null) {
                        CallHolder.circles[n] = c + " (AI)"
                    }
                    if (call.state == Call.STATE_RINGING) {
                        speak(if (c != null) "Unknown number from " + c else "Unknown number")
                    }
                }
            }.start()
        } catch (e: Throwable) {
        }
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
            val raw = call.details.handle?.schemeSpecificPart ?: ""
            val circ = CallHolder.circle(raw)
            b.setSmallIcon(android.R.drawable.ic_menu_call)
            b.setContentTitle("Incoming call")
            b.setContentText((infoMap[call] ?: CallHolder.label(this, call)) + (if (circ != null) "  |  " + circ else ""))
            b.setContentIntent(pi)
            b.setFullScreenIntent(pi, true)
            b.setOngoing(true)
            b.setCategory(Notification.CATEGORY_CALL)
            b.setVisibility(Notification.VISIBILITY_PUBLIC)
            nm.notify(CG_NOTIF_ID, b.build())
        } catch (e: Exception) {
        }
        openUi()
    }

    private fun postOngoing(call: Call, state: Int) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel("cg_active", "Ongoing call", NotificationManager.IMPORTANCE_LOW)
                )
            }
            val i = Intent(this, InCallActivity::class.java)
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pi = PendingIntent.getActivity(this, 1, i, flags)
            val b = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(this, "cg_active")
            } else {
                Notification.Builder(this)
            }
            val st = when (state) {
                Call.STATE_ACTIVE -> "Call chal rahi hai"
                Call.STATE_HOLDING -> "On hold"
                else -> "Calling..."
            }
            b.setSmallIcon(android.R.drawable.ic_menu_call)
            b.setContentTitle(st)
            b.setContentText(infoMap[call] ?: CallHolder.label(this, call))
            b.setContentIntent(pi)
            b.setOngoing(true)
            b.setOnlyAlertOnce(true)
            b.setCategory(Notification.CATEGORY_CALL)
            b.setVisibility(Notification.VISIBILITY_PUBLIC)
            val t = call.details.connectTimeMillis
            if (state == Call.STATE_ACTIVE && t > 0) {
                b.setWhen(t)
                b.setUsesChronometer(true)
            }
            nm.notify(CG_NOTIF_ID, b.build())
        } catch (e: Exception) {
        }
    }

    private fun postMissed(info: String) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel("cg_missed", "Missed calls", NotificationManager.IMPORTANCE_HIGH)
                )
            }
            val launch = packageManager.getLaunchIntentForPackage(packageName)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val b = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(this, "cg_missed")
            } else {
                Notification.Builder(this)
            }
            val time = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date())
            b.setSmallIcon(android.R.drawable.sym_call_missed)
            b.setContentTitle("Missed call")
            b.setContentText(info + "  |  " + time)
            b.setStyle(Notification.BigTextStyle().bigText(info + "\n" + time))
            if (launch != null) {
                b.setContentIntent(PendingIntent.getActivity(this, 2, launch, flags))
            }
            b.setAutoCancel(true)
            b.setVisibility(Notification.VISIBILITY_PUBLIC)
            missedCounter++
            nm.notify(7100 + (missedCounter % 40), b.build())
        } catch (e: Exception) {
        }
    }

    private fun cancelNotif() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(CG_NOTIF_ID)
        } catch (e: Exception) {
        }
    }
}
