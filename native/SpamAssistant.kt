package com.example.call_guard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Locale

object SpamAssistant {
    private val h = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = null
    private var rec: MediaRecorder? = null
    private var recFile: File? = null
    private var info = ""
    private var active = false
    private var player: MediaPlayer? = null

    fun start(svc: InCallService, call: Call, who: String): Boolean {
        val ctx = svc.applicationContext
        val p = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!p.getBoolean("flutter.assistant", false)) return false
        if (active) return true
        active = true
        info = who
        val name = p.getString("flutter.assistantName", "Rakesh") ?: "Rakesh"
        try {
            svc.setMuted(false)
            svc.setAudioRoute(CallAudioState.ROUTE_SPEAKER)
            val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            am.setStreamVolume(
                AudioManager.STREAM_VOICE_CALL,
                am.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL),
                0
            )
        } catch (e: Throwable) {
        }
        h.postDelayed({ speak(ctx, name) }, 900)
        return true
    }

    private fun speak(ctx: Context, name: String) {
        if (!active) return
        try {
            var t: TextToSpeech? = null
            t = TextToSpeech(ctx) { st ->
                val tt = t
                if (st != TextToSpeech.SUCCESS || tt == null) {
                    h.post { startRec(ctx) }
                } else {
                    try {
                        tt.setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                .build()
                        )
                    } catch (e: Throwable) {
                    }
                    val text: String
                    if (tt.isLanguageAvailable(Locale("hi", "IN")) >= TextToSpeech.LANG_AVAILABLE) {
                        tt.language = Locale("hi", "IN")
                        text = "नमस्ते। मैं " + name + " का असिस्टेंट बोल रहा हूँ। यह कॉल रिकॉर्ड हो रही है। आपको क्या काम है?"
                    } else {
                        tt.language = Locale("en", "IN")
                        text = "Hello. I am " + name + "'s assistant. This call is being recorded. How can I help you?"
                    }
                    tt.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) {
                        }

                        override fun onDone(utteranceId: String?) {
                            h.post { startRec(ctx) }
                        }

                        override fun onError(utteranceId: String?) {
                            h.post { startRec(ctx) }
                        }
                    })
                    tt.speak(text, TextToSpeech.QUEUE_FLUSH, null, "cgassist")
                }
            }
            tts = t
        } catch (e: Throwable) {
            h.post { startRec(ctx) }
        }
    }

    private fun startRec(ctx: Context) {
        if (!active || rec != null) return
        try {
            if (ctx.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return
            val dir = File(ctx.filesDir, "recs")
            dir.mkdirs()
            val f = File(dir, "rec_" + System.currentTimeMillis() + ".aac")
            val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(ctx) else MediaRecorder()
            r.setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            r.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioSamplingRate(16000)
            r.setAudioEncodingBitRate(48000)
            r.setMaxDuration(30000)
            r.setOutputFile(f.absolutePath)
            r.prepare()
            r.start()
            rec = r
            recFile = f
        } catch (e: Throwable) {
            rec = null
            recFile = null
        }
    }

    fun stop(ctx: Context) {
        if (!active) return
        active = false
        try {
            tts?.stop()
        } catch (e: Throwable) {
        }
        try {
            tts?.shutdown()
        } catch (e: Throwable) {
        }
        tts = null
        val r = rec
        val f = recFile
        rec = null
        recFile = null
        var ok = false
        if (r != null) {
            try {
                r.stop()
                ok = true
            } catch (e: Throwable) {
            }
            try {
                r.release()
            } catch (e: Throwable) {
            }
        }
        if (ok && f != null && f.exists() && f.length() > 2000) {
            addMeta(ctx, f)
            notifyDone(ctx)
        } else {
            try {
                f?.delete()
            } catch (e: Throwable) {
            }
        }
    }

    private fun metaFile(ctx: Context): File {
        return File(ctx.filesDir, "recs.json")
    }

    private fun readMeta(ctx: Context): JSONArray {
        try {
            val f = metaFile(ctx)
            if (f.exists()) return JSONArray(f.readText())
        } catch (e: Throwable) {
        }
        return JSONArray()
    }

    private fun addMeta(ctx: Context, f: File) {
        try {
            val old = readMeta(ctx)
            val arr = JSONArray()
            val o = JSONObject()
            o.put("p", f.absolutePath)
            o.put("i", info)
            o.put("t", System.currentTimeMillis())
            o.put("s", f.length())
            arr.put(o)
            for (i in 0 until old.length()) arr.put(old.get(i))
            metaFile(ctx).writeText(arr.toString())
        } catch (e: Throwable) {
        }
    }

    fun list(ctx: Context): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        try {
            val arr = readMeta(ctx)
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val path = o.optString("p")
                if (File(path).exists()) {
                    out.add(
                        mapOf(
                            "path" to path,
                            "info" to o.optString("i"),
                            "ts" to o.optLong("t"),
                            "size" to o.optLong("s")
                        )
                    )
                }
            }
        } catch (e: Throwable) {
        }
        return out
    }

    fun delete(ctx: Context, path: String): Boolean {
        try {
            stopPlay()
            val arr = readMeta(ctx)
            val keep = JSONArray()
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                if (o.optString("p") != path) keep.put(o)
            }
            metaFile(ctx).writeText(keep.toString())
            val f = File(path)
            if (f.absolutePath.startsWith(File(ctx.filesDir, "recs").absolutePath)) f.delete()
            return true
        } catch (e: Throwable) {
        }
        return false
    }

    fun play(ctx: Context, path: String): Int {
        try {
            stopPlay()
            val mp = MediaPlayer()
            mp.setDataSource(path)
            mp.prepare()
            mp.setOnCompletionListener {
                try {
                    it.release()
                } catch (e: Throwable) {
                }
                if (player === it) player = null
            }
            mp.start()
            player = mp
            return mp.duration
        } catch (e: Throwable) {
        }
        return 0
    }

    fun stopPlay() {
        try {
            player?.stop()
        } catch (e: Throwable) {
        }
        try {
            player?.release()
        } catch (e: Throwable) {
        }
        player = null
    }

    private fun notifyDone(ctx: Context) {
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel("cg_rec", "AI assistant recordings", NotificationManager.IMPORTANCE_DEFAULT)
                )
            }
            val b = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(ctx, "cg_rec")
            } else {
                Notification.Builder(ctx)
            }
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            b.setSmallIcon(android.R.drawable.ic_btn_speak_now)
            b.setContentTitle("AI assistant ki recording tayyar")
            b.setContentText(info)
            b.setAutoCancel(true)
            if (launch != null) {
                b.setContentIntent(PendingIntent.getActivity(ctx, 3, launch, flags))
            }
            nm.notify(7200 + (System.currentTimeMillis() % 50).toInt(), b.build())
        } catch (e: Throwable) {
        }
    }
}
