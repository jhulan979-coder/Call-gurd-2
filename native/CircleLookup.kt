package com.example.call_guard

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object CircleLookup {
    private val cache = HashMap<String, String>()

    fun get(ctx: Context, number10: String): String? {
        val hit = cache[number10]
        if (hit != null) return hit
        try {
            val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val key = prefs.getString("flutter.api_key", "") ?: ""
            if (key.isEmpty()) return null
            val conn = URL("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent")
                .openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 4000
            conn.readTimeout = 7000
            conn.doOutput = true
            conn.setRequestProperty("content-type", "application/json")
            conn.setRequestProperty("x-goog-api-key", key)
            val prompt = "Indian mobile number " + number10 +
                " kis telecom circle (state) ka hai? Sirf state ya circle ka naam do, 1 se 3 shabd, English me. " +
                "Pakka na ho to sirf UNKNOWN likho."
            val body = JSONObject().put(
                "contents",
                JSONArray().put(
                    JSONObject().put(
                        "parts",
                        JSONArray().put(JSONObject().put("text", prompt))
                    )
                )
            )
            conn.outputStream.use { it.write(body.toString().toByteArray()) }
            if (conn.responseCode != 200) return null
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
            val t = sb.toString().replace("\n", " ").trim()
            if (t.isEmpty() || t.uppercase().contains("UNKNOWN") || t.length > 40) return null
            cache[number10] = t
            return t
        } catch (e: Throwable) {
        }
        return null
    }
}
