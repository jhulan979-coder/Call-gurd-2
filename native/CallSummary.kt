package com.example.call_guard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

object CallSummary {
    private var lastErr = ""

    fun run(ctx0: Context, path: String, info: String) {
        val ctx = ctx0.applicationContext
        Thread {
            lastErr = ""
            val txt = ask(ctx, path)
            if (txt != null) {
                save(ctx, path, txt)
            }
            postNotif(ctx, info, txt, lastErr)
        }.start()
    }

    private fun ask(ctx: Context, path: String): String? {
        try {
            val p = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val key = p.getString("flutter.api_key", "") ?: ""
            if (key.isEmpty()) {
                lastErr = "Settings me Gemini API key nahi hai"
                return null
            }
            val f = File(path)
            if (!f.exists() || f.length() < 1500) {
                lastErr = "recording bahut chhoti hai"
                return null
            }
            val lang = p.getString("flutter.lang", "hi") ?: "hi"
            var q = "Ye ek unknown ya spam caller ki phone recording hai. Pehle assistant bolta hai, phir caller. " +
                "Hinglish me 3 chhoti line me batao: caller ne kya kaha, wo kya chahta hai, aur ye spam ya scam lagta hai ya nahi. " +
                "Agar recording me caller ki awaaz na ho ya khali ho to saaf likho: Caller ki awaaz recording me nahi mili. Kuch gadho mat."
            if (lang == "en") {
                q = "This is a phone recording of an unknown or spam caller. The assistant speaks first, then the caller. " +
                    "In simple English, in 3 short lines tell me: what the caller said, what they want, and whether it looks like spam or a scam. " +
                    "If the caller's voice is missing or the recording is empty, say so clearly. Do not guess."
            } else if (lang == "or") {
                q = "ଏହା ଏକ ଅଜଣା କିମ୍ବା ସ୍ପାମ୍ କଲରର ଫୋନ୍ ରେକର୍ଡିଂ। ପ୍ରଥମେ ଆସିଷ୍ଟାଣ୍ଟ କହେ, ତା'ପରେ କଲର୍। " +
                    "ଓଡ଼ିଆ ଅକ୍ଷରରେ 3 ଛୋଟ ଧାଡ଼ିରେ କୁହ: କଲର୍ କଣ କହିଲା, କଣ ଚାହେଁ, ଏବଂ ଏହା ସ୍ପାମ୍ କି ନୁହେଁ। " +
                    "କଲରର ସ୍ୱର ନ ଥିଲେ ସ୍ପଷ୍ଟ କୁହ। କିଛି ଅନୁମାନ କର ନାହିଁ।"
            }
            val b64 = Base64.encodeToString(f.readBytes(), Base64.NO_WRAP)
            val part1 = JSONObject().put("text", q)
            val part2 = JSONObject().put(
                "inline_data",
                JSONObject().put("mime_type", "audio/aac").put("data", b64)
            )
            val body = JSONObject().put(
                "contents",
                JSONArray().put(JSONObject().put("parts", JSONArray().put(part1).put(part2)))
            )
            val conn = URL("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent")
                .openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 8000
            conn.readTimeout = 45000
            conn.doOutput = true
            conn.setRequestProperty("content-type", "application/json")
            conn.setRequestProperty("x-goog-api-key", key)
            conn.outputStream.use { it.write(body.toString().toByteArray()) }
            if (conn.responseCode != 200) {
                lastErr = "Google ne jawab me error " + conn.responseCode + " diya"
                return null
            }
            val txt = conn.inputStream.bufferedReader().readText()
            val parts = JSONObject(txt)
                .getJSONArray("candidates")
                .getJSONObject(0)
                .getJSONObject("content")
                .getJSONArray("parts")
            val sb = StringBuilder()
            for (i in 0 until parts.length()) {
                sb.append(parts.getJSONObject(i).optString("text", ""))
            }
            val r = sb.toString().trim()
            if (r.isEmpty()) {
                lastErr = "AI ne khali jawab diya"
                return null
            }
            return r
        } catch (e: Throwable) {
            lastErr = "internet ya network ki dikkat"
        }
        return null
    }

    private fun save(ctx: Context, path: String, text: String) {
        try {
            val f = File(ctx.filesDir, "recs.json")
            if (!f.exists()) return
            val arr = JSONArray(f.readText())
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                if (o.optString("p") == path) {
                    o.put("m", text)
                }
            }
            f.writeText(arr.toString())
        } catch (e: Throwable) {
        }
    }

    private fun postNotif(ctx: Context, info: String, text: String?, err: String) {
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel("cg_summary", "AI assistant saar", NotificationManager.IMPORTANCE_HIGH)
                )
            }
            val b = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(ctx, "cg_summary")
            } else {
                Notification.Builder(ctx)
            }
            val title = if (text != null) "AI assistant: baat ka saar" else "AI assistant: recording tayyar"
            val body = text ?: ("Saar nahi bana (" + err + "). Recording sunne ke liye Home > AI assistant ki recordings kholo.")
            b.setSmallIcon(android.R.drawable.ic_btn_speak_now)
            b.setContentTitle(title)
            b.setContentText(info + "  |  " + body.replace("\n", " "))
            b.setStyle(Notification.BigTextStyle().bigText(info + "\n\n" + body))
            b.setAutoCancel(true)
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            if (launch != null) {
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                b.setContentIntent(PendingIntent.getActivity(ctx, 5, launch, flags))
            }
            nm.notify(7400 + (System.currentTimeMillis() % 50).toInt(), b.build())
        } catch (e: Throwable) {
        }
    }
}
