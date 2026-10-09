package com.example.call_guard

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telecom.VideoProfile
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray

class InCallActivity : Activity() {
    private var avatar: TextView? = null
    private var nameView: TextView? = null
    private var numView: TextView? = null
    private var stateView: TextView? = null
    private var cardView: TextView? = null
    private var mid: LinearLayout? = null
    private var bottom: LinearLayout? = null
    private var muted = false
    private var speaker = false
    private val handler = Handler(Looper.getMainLooper())

    private val tick = object : Runnable {
        override fun run() {
            updateText()
            handler.postDelayed(this, 1000)
        }
    }

    private val cb = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            refresh()
        }
    }

    private fun dp(v: Int): Int {
        return (v * resources.displayMetrics.density).toInt()
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

        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.gravity = Gravity.CENTER_HORIZONTAL
        root.background = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(Color.parseColor("#0D1B2A"), Color.parseColor("#1B3A5C"))
        )
        root.setPadding(dp(24), dp(72), dp(24), dp(40))

        val a = TextView(this)
        a.textSize = 44f
        a.setTextColor(Color.WHITE)
        a.gravity = Gravity.CENTER
        a.layoutParams = LinearLayout.LayoutParams(dp(120), dp(120))
        avatar = a
        root.addView(a)

        val n = TextView(this)
        n.textSize = 28f
        n.setTextColor(Color.WHITE)
        n.gravity = Gravity.CENTER
        n.setPadding(0, dp(20), 0, 0)
        nameView = n
        root.addView(n)

        val m = TextView(this)
        m.textSize = 16f
        m.setTextColor(Color.parseColor("#B0BEC5"))
        m.gravity = Gravity.CENTER
        m.setPadding(0, dp(6), 0, 0)
        numView = m
        root.addView(m)

        val s = TextView(this)
        s.textSize = 16f
        s.setTextColor(Color.parseColor("#90CAF9"))
        s.gravity = Gravity.CENTER
        s.setPadding(0, dp(10), 0, 0)
        stateView = s
        root.addView(s)
                val cd = TextView(this)
        cd.textSize = 15f
        cd.setTextColor(Color.WHITE)
        cd.gravity = Gravity.CENTER
        cd.setPadding(dp(16), dp(12), dp(16), dp(12))
        cd.visibility = View.GONE
        cardView = cd
        val cdp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        cdp.topMargin = dp(24)
        root.addView(cd, cdp)

        val gap = View(this)
        root.addView(gap, LinearLayout.LayoutParams(1, 0, 1f))

        val md = LinearLayout(this)
        md.orientation = LinearLayout.HORIZONTAL
        md.gravity = Gravity.CENTER
        mid = md
        root.addView(
            md,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )

        val bt = LinearLayout(this)
        bt.orientation = LinearLayout.HORIZONTAL
        bt.gravity = Gravity.CENTER
        bt.setPadding(0, dp(32), 0, 0)
        bottom = bt
        root.addView(
            bt,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )
        setContentView(root)
    }

    override fun onResume() {
        super.onResume()
        CallOverlay.hide()
        CallHolder.call?.registerCallback(cb)
        refresh()
        handler.removeCallbacks(tick)
        handler.postDelayed(tick, 1000)
    }

    override fun onPause() {
        super.onPause()
        CallOverlay.showLast(applicationContext)
        handler.removeCallbacks(tick)
        try {
            CallHolder.call?.unregisterCallback(cb)
        } catch (e: Exception) {
        }
    }

    private fun circle(sym: String, label: String, color: Int, size: Int, onClick: () -> Unit): LinearLayout {
        val box = LinearLayout(this)
        box.orientation = LinearLayout.VERTICAL
        box.gravity = Gravity.CENTER_HORIZONTAL
        val c = TextView(this)
        c.text = sym
        c.textSize = 24f
        c.setTextColor(Color.WHITE)
        c.gravity = Gravity.CENTER
        val bg = GradientDrawable()
        bg.shape = GradientDrawable.OVAL
        bg.setColor(color)
        c.background = bg
        c.layoutParams = LinearLayout.LayoutParams(dp(size), dp(size))
        c.setOnClickListener { onClick() }
        box.addView(c)
        if (label.isNotEmpty()) {
            val l = TextView(this)
            l.text = label
            l.textSize = 13f
            l.setTextColor(Color.parseColor("#CFD8DC"))
            l.gravity = Gravity.CENTER
            l.setPadding(0, dp(6), 0, 0)
            box.addView(l)
        }
        box.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        return box
    }private fun spamLabel(num: String): String? {
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
    }

    private fun accountList(c: Call): List<PhoneAccountHandle> {
        val out = ArrayList<PhoneAccountHandle>()
        try {
            val ex = c.details.extras
            val l = ex?.getParcelableArrayList<PhoneAccountHandle>("selectPhoneAccountAccounts")
            if (l != null) out.addAll(l)
        } catch (e: Throwable) {
        }
        if (out.isEmpty()) {
            try {
                val tm = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                out.addAll(tm.callCapablePhoneAccounts)
            } catch (e: Throwable) {
            }
        }
        return out
    }

    private fun updateText() {
        val c = CallHolder.call ?: return
        val state = c.state
        val raw = c.details.handle?.schemeSpecificPart ?: ""
        val num = raw.filter { it.isDigit() }.takeLast(10)
        val tag = spamLabel(num)
        var base = when (state) {
            Call.STATE_RINGING -> "Incoming call"
            Call.STATE_DIALING, Call.STATE_CONNECTING -> "Calling..."
            Call.STATE_ACTIVE -> "Connected"
            Call.STATE_HOLDING -> "On hold"
            Call.STATE_SELECT_PHONE_ACCOUNT -> "SIM chuno"
            else -> "..."
        }
        if (state == Call.STATE_ACTIVE) {
            val t = c.details.connectTimeMillis
            if (t > 0) {
                val sec = ((System.currentTimeMillis() - t) / 1000).toInt()
                base = "Connected  " + String.format("%02d:%02d", sec / 60, sec % 60)
            }
        }
        stateView?.text = if (tag != null) base + "  |  SPAM - " + tag else base
    }

    private fun showKeypad(c: Call) {
        val col = LinearLayout(this)
        col.orientation = LinearLayout.VERTICAL
        col.setPadding(dp(16), dp(16), dp(16), dp(8))
        val keys = arrayOf("123", "456", "789", "*0#")
        for (rowKeys in keys) {
            val r = LinearLayout(this)
            r.orientation = LinearLayout.HORIZONTAL
            for (ch in rowKeys) {
                val b = TextView(this)
                b.text = ch.toString()
                b.textSize = 26f
                b.gravity = Gravity.CENTER
                b.setPadding(0, dp(14), 0, dp(14))
                b.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                b.setOnClickListener {
                    c.playDtmfTone(ch)
                    handler.postDelayed({ c.stopDtmfTone() }, 150)
                }
                r.addView(b)
            }
            col.addView(r)
        }
        AlertDialog.Builder(this).setView(col).setPositiveButton("Band karo", null).show()
    }

    private fun refresh() {
        val c = CallHolder.call
        if (c == null) {
            finish()
            return
        }
        val state = c.state
        if (state == Call.STATE_DISCONNECTED) {
            try {
                val cause = c.details.disconnectCause
                if (cause != null && cause.code != 2 && cause.code != 3 && cause.code != 4) {
                    Toast.makeText(
                        applicationContext,
                        "Call nahi lagi: code " + cause.code + " " + (cause.reason ?: ""),
                        Toast.LENGTH_LONG
                    ).show()
                }
            } catch (e: Throwable) {
            }
            finish()
            return
        }
        val raw = c.details.handle?.schemeSpecificPart ?: ""
        val num = raw.filter { it.isDigit() }.takeLast(10)
        val tag = spamLabel(num)
        val spam = tag != null
        val name = CallHolder.label(this, c)
        val accent = if (spam) Color.parseColor("#E53935") else Color.parseColor("#1E88E5")

        val av = avatar
        if (av != null) {
            av.text = (if (name.isNotEmpty() && name[0].isLetter()) name.substring(0, 1) else "#").uppercase()
            val bg = GradientDrawable()
            bg.shape = GradientDrawable.OVAL
            bg.setColor(accent)
            av.background = bg
        }
        nameView?.text = name
        nameView?.setTextColor(if (spam) Color.parseColor("#FF8A80") else Color.WHITE)
        numView?.text = if (name == raw) "" else raw
                try {
            val r = SpamBrain.evaluate(this, raw)
            val cdv = cardView
            if (cdv != null) {
                if (r.score <= 0) {
                    cdv.visibility = View.GONE
                } else {
                    val circ = CallHolder.circles[num]
                    val bg2 = GradientDrawable()
                    bg2.cornerRadius = dp(16).toFloat()
                    bg2.setColor(
                        if (r.score >= 65) Color.parseColor("#B71C1C")
                        else if (r.score >= 35) Color.parseColor("#E65100")
                        else Color.parseColor("#37474F")
                    )
                    cdv.background = bg2
                    cdv.text = r.badge + (if (circ != null) "  |  " + circ else "") + "\n" + r.reasons.joinToString(", ") + "\n\n" + CallAdvice.text(r.score)
                    cdv.visibility = View.VISIBLE
                }
            }
        } catch (e: Throwable) {
        }
        updateText()

        val m = mid
        val b = bottom
        if (m != null && b != null) {
            m.removeAllViews()
            b.removeAllViews()
            val red = Color.parseColor("#C62828")
            val green = Color.parseColor("#2E7D32")
            val grey = Color.parseColor("#37474F")
            val blue = Color.parseColor("#1E88E5")
            if (state == Call.STATE_RINGING) {
                b.addView(circle("✖", "Reject", red, 72) {
                    c.reject(false, null)
                })
                b.addView(circle("✆", "Answer", green, 72) {
                    c.answer(VideoProfile.STATE_AUDIO_ONLY)
                })
            } else if (state == Call.STATE_SELECT_PHONE_ACCOUNT) {
                var i = 0
                for (h in accountList(c)) {
                    i++
                    val idx = i
                    m.addView(circle(idx.toString(), "SIM " + idx, blue, 64) {
                        c.phoneAccountSelected(h, false)
                    })
                }
                b.addView(circle("✖", "Cancel", red, 72) {
                    c.disconnect()
                })
            } else {
                m.addView(circle("🎤", if (muted) "Unmute" else "Mute", if (muted) blue else grey, 64) {
                    muted = !muted
                    CallHolder.service?.setMuted(muted)
                    refresh()
                })
                m.addView(circle("123", "Keypad", grey, 64) {
                    showKeypad(c)
                })
                m.addView(circle("🔊", if (speaker) "Earpiece" else "Speaker", if (speaker) blue else grey, 64) {
                    speaker = !speaker
                    CallHolder.service?.setAudioRoute(
                        if (speaker) CallAudioState.ROUTE_SPEAKER else CallAudioState.ROUTE_EARPIECE
                    )
                    refresh()
                })
                b.addView(circle("✖", "End", red, 72) {
                    c.disconnect()
                })
            }
        }
    }
}
