package com.example.call_guard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.telecom.Call
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object AiGuess {
    private fun ask(ctx: Context, n: String): String? {
        val sp = ctx.getSharedPreferences("cg_aiguess", Context.MODE_PRIVATE)
        val hit = sp.getString(n, null)
        if (hit != null) return hit
        try {
            val fp = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val key = fp.getString("flutter.api_key", "") ?: ""
            if (key.isEmpty()) return null
            val conn = URL("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent")
                .openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 4000
            conn.readTimeout = 7000
            conn.doOutput = true
            conn.setRequestProperty("content-type", "application/json")
            conn.setRequestProperty("x-goog-api-key", key)
            val prompt = "Indian mobile number " + n +
                ". Sirf number ke pattern aur series se batao ki ye telemarketing ya sales spam lagta hai ya nahi. " +
                "Sirf ek shabd likho: SPAM, SAFE ya UNKNOWN."
            val body = JSONObject().put(
                "contents",
                JSONArray().put(
                    JSONObject().put("parts", JSONArray().put(JSONObject().put("text", prompt)))
                )
            )
            conn.outputStream.use { it.write(body.toString().toByteArray()) }
            if (conn.responseCode != 200) return null
            val txt = conn.inputStream.bufferedReader().readText()
            val parts = JSONObject(txt).getJSONArray("candidates").getJSONObject(0)
                .getJSONObject("content").getJSONArray("parts")
            val sb = StringBuilder()
            for (i in 0 until parts.length()) sb.append(parts.getJSONObject(i).optString("text", ""))
            val res = if (sb.toString().trim().uppercase().startsWith("SPAM")) "S" else "N"
            sp.edit().putString(n, res).apply()
            return res
        } catch (e: Throwable) {
        }
        return null
    }

    fun check(ctx: Context, call: Call) {
        try {
            val fp = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (!fp.getBoolean("flutter.onlineCircle", false)) return
            val raw = call.details.handle?.schemeSpecificPart ?: return
            val n = SpamBrain.last10(raw)
            if (n.length != 10) return
            val sc = SpamBrain.evaluate(ctx, raw).score
            if (sc < 35 || sc > 70) return
            val app = ctx.applicationContext
            Thread {
                val r = ask(app, n)
                try { CgLog.add(app, "AIGUESS " + n + " " + r) } catch (e: Throwable) {}
                if (r == "S" && call.state == Call.STATE_RINGING) post(app, n)
            }.start()
        } catch (e: Throwable) {
        }
    }

    private fun post(ctx: Context, n: String) {
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel("cg_aiguess", "AI andaza", NotificationManager.IMPORTANCE_DEFAULT)
                )
            }
            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, "cg_aiguess") else Notification.Builder(ctx)
            b.setSmallIcon(android.R.drawable.ic_menu_call)
            b.setContentTitle("AI andaza: spam lagta hai")
            b.setContentText(n + "  |  pakka nahi, sirf andaza")
            b.setAutoCancel(true)
            nm.notify(7400 + (System.currentTimeMillis() % 20).toInt(), b.build())
        } catch (e: Throwable) {
        }
    }
}
