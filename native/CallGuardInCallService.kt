package com.example.call_guard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
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
import android.telecom.InCallService
import android.telecom.TelecomManager
import android.widget.Toast
import com.google.i18n.phonenumbers.PhoneNumberUtil
import com.google.i18n.phonenumbers.geocoding.PhoneNumberOfflineGeocoder
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
            if (state != Call.STATE_RINGING) {
                cancelNotif()
                stopFlip()
            }
            if (state == Call.STATE_ACTIVE) {
                this@CallGuardInCallService.stopSpeech()
                try {
                    this@CallGuardInCallService.setMuted(false)
                } catch (x: Throwable) {
                }
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
            announce(call)
            startFlip()
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
        stopFlip()
        stopSpeech()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopFlip()
        stopSpeech()
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
            val p = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (!p.getBoolean("flutter.announce", true)) return
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
            val p = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (!p.getBoolean("flutter.onlineCircle", true) || n.length != 10) {
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
            b.setContentText(CallHolder.label(this, call) + (if (circ != null) "  |  " + circ else ""))
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
