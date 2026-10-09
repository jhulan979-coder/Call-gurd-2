package com.example.call_guard

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telecom.Call
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView

object CallOverlay {
    private val h = Handler(Looper.getMainLooper())
    private var view: TextView? = null
    private var callRef: Call? = null

    fun prepare(call: Call) {
        callRef = call
    }

    fun clear() {
        callRef = null
        hide()
    }

    fun hide() {
        h.post {
            try {
                val v = view ?: return@post
                val wm = v.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                wm.removeView(v)
            } catch (e: Throwable) {
            }
            view = null
        }
    }

    fun showLast(ctx: Context) {
        h.post {
            try {
                val c = callRef ?: return@post
                if (c.state == Call.STATE_DISCONNECTED || view != null) return@post
                if (!Settings.canDrawOverlays(ctx)) {
                    try { CgLog.add(ctx, "OVERLAY permission nahi") } catch (e: Throwable) {}
                    return@post
                }
                val raw = c.details.handle?.schemeSpecificPart ?: ""
                val r = SpamBrain.evaluate(ctx, raw)
                if (r.score <= 0) return@post
                val circ = CallHolder.circles[SpamBrain.last10(raw)]
                val dm = ctx.resources.displayMetrics
                val dp = dm.density
                val tv = TextView(ctx)
                tv.text = r.badge + (if (circ != null) "  |  " + circ else "") + "\n" + r.reasons.joinToString(", ")
                tv.textSize = 15f
                tv.setTextColor(Color.WHITE)
                tv.gravity = Gravity.CENTER
                tv.setPadding((16 * dp).toInt(), (12 * dp).toInt(), (16 * dp).toInt(), (12 * dp).toInt())
                val bg = GradientDrawable()
                bg.cornerRadius = 16 * dp
                bg.setColor(
                    if (r.score >= 65) Color.parseColor("#B71C1C")
                    else if (r.score >= 35) Color.parseColor("#E65100")
                    else Color.parseColor("#37474F")
                )
                tv.background = bg
                tv.setOnClickListener { hide() }
                val type = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else WindowManager.LayoutParams.TYPE_PHONE
                val lp = WindowManager.LayoutParams(
                    dm.widthPixels - (24 * dp).toInt(),
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    type,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                    PixelFormat.TRANSLUCENT
                )
                lp.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                lp.y = (80 * dp).toInt()
                val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                wm.addView(tv, lp)
                view = tv
            } catch (e: Throwable) {
            }
        }
    }
}
