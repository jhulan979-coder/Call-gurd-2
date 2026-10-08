package com.example.call_guard

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object CgLog {
    fun add(ctx: Context, msg: String) {
        try {
            val p = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val old = p.getString("flutter.cg_log", "") ?: ""
            val t = SimpleDateFormat("dd/MM HH:mm:ss", Locale.getDefault()).format(Date())
            val lines = (old + "\n" + t + "  " + msg).split("\n").filter { it.isNotBlank() }
            p.edit().putString("flutter.cg_log", lines.takeLast(30).joinToString("\n")).apply()
        } catch (e: Throwable) {
        }
    }
}
