package com.example.call_guard

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.VideoProfile
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONArray

class InCallActivity : Activity() {
    private var nameView: TextView? = null
    private var numView: TextView? = null
    private var stateView: TextView? = null
    private var row: LinearLayout? = null
    private var muted = false
    private var speaker = false

    private val cb = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            refresh()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val d = resources.displayMetrics.density
        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.gravity = Gravity.CENTER_HORIZONTAL
        root.setBackgroundColor(Color.parseColor("#0D1B2A"))
        root.setPadding((24 * d).toInt(), (100 * d).toInt(), (24 * d).toInt(), (48 * d).toInt())

        val n = TextView(this)
        n.textSize = 30f
        n.setTextColor(Color.WHITE)
        n.gravity = Gravity.CENTER
        nameView = n
        root.addView(n)

        val m = TextView(this)
        m.textSize = 16f
        m.setTextColor(Color.parseColor("#B0BEC5"))
        m.gravity = Gravity.CENTER
        m.setPadding(0, (6 * d).toInt(), 0, 0)
        numView = m
        root.addView(m)

        val s = TextView(this)
        s.textSize = 18f
        s.setTextColor(Color.parseColor("#90CAF9"))
        s.gravity = Gravity.CENTER
        s.setPadding(0, (12 * d).toInt(), 0, 0)
        stateView = s
        root.addView(s)

        val gap = View(this)
        root.addView(gap, LinearLayout.LayoutParams(1, 0, 1f))

        val r = LinearLayout(this)
        r.orientation = LinearLayout.HORIZONTAL
        row = r
        root.addView(
            r,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )
        setContentView(root)
    }

    override fun onResume() {
        super.onResume()
        CallHolder.call?.registerCallback(cb)
        refresh()
    }

    override fun onPause() {
        super.onPause()
        try {
            CallHolder.call?.unregisterCallback(cb)
        } catch (e: Exception) {
        }
    }

    private fun btn(text: String, color: String, onClick: () -> Unit): Button {
        val d = resources.displayMetrics.density
        val b = Button(this)
        b.text = text
        b.setTextColor(Color.WHITE)
        b.setBackgroundColor(Color.parseColor(color))
        val lp = LinearLayout.LayoutParams(0, (56 * d).toInt(), 1f)
        lp.setMargins(8, 8, 8, 8)
        b.layoutParams = lp
        b.setOnClickListener { onClick() }
        return b
    }

    private fun spamLabel(num: String): String? {
        if (num.startsWith("140") || num.startsWith("160")) return "Telemarketing"
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val s = prefs.getString("flutter.blocked_v2", null) ?: return null
            val arr = JSONArray(s)
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                if (o.optString("n") == num) return o.optString("l", "Spam")
            }
        } catch (e: Exception) {
        }
        return null
    }private fun refresh() {
        val c = CallHolder.call
        if (c == null) {
            finish()
            return
        }
        val state = c.state
        if (state == Call.STATE_DISCONNECTED) {
            finish()
            return
        }
        val raw = c.details.handle?.schemeSpecificPart ?: ""
        val num = raw.filter { it.isDigit() }.takeLast(10)
        val tag = spamLabel(num)
        nameView?.text = CallHolder.label(this, c)
        nameView?.setTextColor(if (tag != null) Color.parseColor("#FF5252") else Color.WHITE)
        numView?.text = numView?.text = CallHolder.where(raw)
        val base = when (state) {
            Call.STATE_RINGING -> "Incoming call"
            Call.STATE_DIALING, Call.STATE_CONNECTING -> "Calling..."
            Call.STATE_ACTIVE -> "Connected"
            Call.STATE_HOLDING -> "On hold"
            else -> ""
        }
        stateView?.text = if (tag != null) base + "  |  SPAM - " + tag else base

        val r = row
        if (r != null) {
            r.removeAllViews()
            if (state == Call.STATE_RINGING) {
                r.addView(btn("Answer", "#2E7D32") {
                    c.answer(VideoProfile.STATE_AUDIO_ONLY)
                })
                r.addView(btn("Reject", "#C62828") {
                    c.reject(false, null)
                })
            } else {
                r.addView(btn(if (muted) "Unmute" else "Mute", "#37474F") {
                    muted = !muted
                    CallHolder.service?.setMuted(muted)
                    refresh()
                })
                r.addView(btn(if (speaker) "Earpiece" else "Speaker", "#37474F") {
                    speaker = !speaker
                    CallHolder.service?.setAudioRoute(
                        if (speaker) CallAudioState.ROUTE_SPEAKER else CallAudioState.ROUTE_EARPIECE
                    )
                    refresh()
                })
                r.addView(btn("End", "#C62828") {
                    c.disconnect()
                })
            }
        }
    }
}
