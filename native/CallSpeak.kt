package com.example.call_guard

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import java.util.Locale

object CallSpeak {
    fun say(ctx: Context, info: String, auto: Boolean, answered: Boolean) {
        try {
            val fp = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (!fp.getBoolean("flutter.announce", true)) return
            val m = Regex("Spam risk (\\d+)%").find(info) ?: return
            val risk = m.groupValues[1]
            val who = info.substringBefore("|").trim()
            val nm = if (who.isEmpty() || who[0] == '+' || who[0].isDigit()) "Unknown number" else who
            val text = if (auto) {
                nm + " ki spam call thi. Spam risk " + risk + " percent. Call apne aap uthayi gayi."
            } else if (answered) {
                nm + " se call khatam hui. Spam risk " + risk + " percent tha."
            } else {
                nm + " ki spam call aayi thi. Spam risk " + risk + " percent."
            }
            var t: TextToSpeech? = null
            t = TextToSpeech(ctx.applicationContext) { st ->
                val tt = t
                if (st == TextToSpeech.SUCCESS && tt != null) {
                    tt.language = Locale("hi", "IN")
                    tt.speak(text, TextToSpeech.QUEUE_FLUSH, null, "cgsum")
                    Handler(Looper.getMainLooper()).postDelayed({ tt.shutdown() }, 12000)
                }
            }
        } catch (e: Throwable) {
        }
    }
}
