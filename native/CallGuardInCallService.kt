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
import com.google.i18n.phonenumbers.PhoneNumberUtil
import com.google.i18n.phonenumbers.geocoding.PhoneNumberOfflineGeocoder
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale

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

    fun where(raw: String): String {
        val c = circle(raw)
        return if (c != null) raw + "  |  " + c else raw
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
                speak(if (ok) "Silenced" else "Silence failed")
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
            CallOverlay.show(this, call)
            startFlip()
        } else {
            openUi()
        }
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        CallOverlay.hide()
        try {
            call.unregisterCallback(cb)
        } catch (e: Exception) {
        }
        if (CallHolder.call == call) {
            CallHolder.call = null
        }
        cancelNotif()
        stopFlip()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopFlip()
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

    private fun speak(text: String) {
        try {
            val p = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (!p.getBoolean("flutter.announce", true)) return
            var t: TextToSpeech? = null
            t = TextToSpeech(applicationContext) { st ->
                if (st == TextToSpeech.SUCCESS) {
                    t?.language = Locale("en", "IN")
                    t?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "cg")
                    Handler(Looper.getMainLooper()).postDelayed({ t?.shutdown() }, 8000)
                }
            }
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
            val text = if (!saved.isNullOrEmpty()) {
                saved + " calling"
            } else {
                val c = CallHolder.circle(raw)
                if (c != null) "Unknown number from " + c else "Unknown number"
            }
            speak(text)
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
object CallOverlay {
    private var view: View? = null
    private var wm: WindowManager? = null

    fun hide() {
        try {
            if (view != null) wm?.removeView(view)
        } catch (e: Throwable) {
        }
        view = null
    }

    fun show(ctx: Context, call: Call) {
        try {
            if (!Settings.canDrawOverlays(ctx)) return
            hide()
            val raw = call.details.handle?.schemeSpecificPart ?: ""
            val name = CallHolder.label(ctx, call)
            val circ = CallHolder.circle(raw)
            val digits = raw.filter { it.isDigit() }
            val n = if (digits.length > 10) digits.substring(digits.length - 10) else digits
            val tele = n.startsWith("140") || n.startsWith("160")
            val d = ctx.resources.displayMetrics.density

            fun pill(txt: String, bg: Int, fg: Int, click: () -> Unit): TextView {
                val t = TextView(ctx)
                t.text = txt
                t.setTextColor(fg)
                t.textSize = 14f
                t.gravity = Gravity.CENTER
                t.setPadding((16 * d).toInt(), (10 * d).toInt(), (16 * d).toInt(), (10 * d).toInt())
                val g = GradientDrawable()
                g.cornerRadius = 20 * d
                g.setColor(bg)
                t.background = g
                t.setOnClickListener { click() }
                return t
            }

            val box = LinearLayout(ctx)
            box.orientation = LinearLayout.VERTICAL
            box.setPadding((18 * d).toInt(), (14 * d).toInt(), (18 * d).toInt(), (14 * d).toInt())
            val bg = GradientDrawable()
            bg.cornerRadius = 20 * d
            bg.setColor(if (tele) Color.parseColor("#B3261E") else Color.parseColor("#1F4E79"))
            box.background = bg

            val title = TextView(ctx)
            title.text = name
            title.setTextColor(Color.WHITE)
            title.textSize = 20f
            box.addView(title)

            val sub = TextView(ctx)
            sub.text = if (circ != null) raw + "  |  " + circ else raw
            sub.setTextColor(Color.parseColor("#DDEBFF"))
            sub.textSize = 14f
            box.addView(sub)

            if (tele) {
                val badge = TextView(ctx)
                badge.text = "Telemarketing / Spam"
                badge.setTextColor(Color.WHITE)
                badge.textSize = 14f
                badge.setPadding(0, (6 * d).toInt(), 0, 0)
                box.addView(badge)
            }

            val row = LinearLayout(ctx)
            row.orientation = LinearLayout.HORIZONTAL
            row.setPadding(0, (12 * d).toInt(), 0, 0)
            val lp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            lp.rightMargin = (8 * d).toInt()
            row.addView(pill("Reject", Color.WHITE, Color.parseColor("#B3261E")) {
                try {
                    if (call.state == Call.STATE_RINGING) call.reject(false, null) else call.disconnect()
                } catch (e: Throwable) {
                }
                hide()
            }, lp)
            val lp2 = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            row.addView(pill("Band karo (X)", Color.parseColor("#33FFFFFF"), Color.WHITE) { hide() }, lp2)
            box.addView(row)

            val type = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE
            val w = ctx.resources.displayMetrics.widthPixels - (24 * d).toInt()
            val p = WindowManager.LayoutParams(
                w, WindowManager.LayoutParams.WRAP_CONTENT, type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT
            )
            p.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            p.y = (60 * d).toInt()
            wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm?.addView(box, p)
            view = box
        } catch (e: Throwable) {
        }
    }
}
