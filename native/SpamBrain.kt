package com.example.call_guard

import android.content.Context
import android.content.pm.PackageManager
import android.provider.CallLog
import org.json.JSONArray
import java.util.Calendar

object SpamBrain {
    class Result(val score: Int, val reasons: List<String>) {
        val badge: String
            get() = "Spam risk " + score + "%"
    }

    private fun brain(ctx: Context) = ctx.getSharedPreferences("cg_brain", Context.MODE_PRIVATE)

    private fun flutter(ctx: Context) =
        ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun last10(raw: String): String {
        val d = raw.filter { it.isDigit() }
        return if (d.length > 10) d.substring(d.length - 10) else d
    }

    fun threshold(ctx: Context): Int {
        val lv = flutter(ctx).getString("flutter.spamLevel", "med")
        if (lv == "low") return 80
        if (lv == "high") return 50
        return 65
    }

    private fun inBlockList(ctx: Context, n: String): Boolean {
        try {
            val s = flutter(ctx).getString("flutter.blocked_v2", null) ?: return false
            val arr = JSONArray(s)
            for (i in 0 until arr.length()) {
                if (arr.getJSONObject(i).optString("n") == n) return true
            }
        } catch (e: Throwable) {
        }
        return false
    }

    private fun recentBad(ctx: Context, n: String): Int {
        var c = 0
        try {
            if (ctx.checkSelfPermission(android.Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) return 0
            val since = System.currentTimeMillis() - 24L * 3600L * 1000L
            val cur = ctx.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.TYPE),
                CallLog.Calls.NUMBER + " LIKE ? AND " + CallLog.Calls.DATE + " > ?",
                arrayOf("%" + n, since.toString()),
                null
            )
            cur?.use {
                while (it.moveToNext()) {
                    val t = it.getInt(0)
                    if (t == CallLog.Calls.MISSED_TYPE ||
                        t == CallLog.Calls.REJECTED_TYPE ||
                        t == CallLog.Calls.BLOCKED_TYPE
                    ) {
                        c++
                    }
                }
            }
        } catch (e: Throwable) {
        }
        return c
    }

    private fun trusted(ctx: Context, n: String): Boolean {
        try {
            if (ctx.checkSelfPermission(android.Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) return false
            val cur = ctx.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.TYPE, CallLog.Calls.DURATION),
                CallLog.Calls.NUMBER + " LIKE ?",
                arrayOf("%" + n),
                null
            )
            cur?.use {
                while (it.moveToNext()) {
                    val t = it.getInt(0)
                    val d = it.getLong(1)
                    if (t == CallLog.Calls.OUTGOING_TYPE ||
                        (t == CallLog.Calls.INCOMING_TYPE && d >= 20)
                    ) {
                        return true
                    }
                }
            }
        } catch (e: Throwable) {
        }
        return false
    }

    fun evaluate(ctx: Context, raw: String): Result {
        val reasons = ArrayList<String>()
        val n = last10(raw)
        try {
            val saved = CallHolder.lookup(ctx, raw)
            if (!saved.isNullOrEmpty()) return Result(0, listOf("saved contact"))
        } catch (e: Throwable) {
        }
        if (n.length == 10 && inBlockList(ctx, n)) {
            return Result(100, listOf("aapki block list"))
        }
        var score = 10
        reasons.add("contact me nahi")
        if (raw.isEmpty()) {
            score += 55
            reasons.add("chhupa number")
        }
        if (n.startsWith("140")) {
            score += 75
            reasons.add("telemarketing 140")
        } else if (n.startsWith("160")) {
            score += 30
            reasons.add("160 series")
        }
        if (raw.startsWith("1800") || raw.startsWith("1860")) {
            score += 25
            reasons.add("toll free")
        }
        if (raw.startsWith("+") && !raw.startsWith("+91")) {
            score += 45
            reasons.add("videshi number")
        }
        if (raw.isNotEmpty() && !raw.startsWith("+") && n.length != 10) {
            score += 35
            reasons.add("ajeeb lambai")
        }
        if (n.length == 10 && n[0] in '0'..'5') {
            score += 35
            reasons.add("mobile series galat")
        }
        if (n.length >= 7 && Regex("(\\d)\\1{6,}").containsMatchIn(n)) {
            score += 40
            reasons.add("ek jaise digit")
        }
        val b = brain(ctx)
        val r = b.getInt("r_" + n, 0)
        val sh = b.getInt("s_" + n, 0)
        if (r >= 2) {
            score += 55
            reasons.add("aapne baar baar reject kiya")
        } else if (r == 1) {
            score += 30
            reasons.add("aapne pehle reject kiya")
        }
        if (sh >= 2) {
            score += 45
            reasons.add("chhoti calls baar baar")
        } else if (sh == 1) {
            score += 25
            reasons.add("pehle chhoti call rahi")
        }
        val bad = recentBad(ctx, n)
        if (bad > 0) {
            score += minOf(bad * 15, 45)
            reasons.add("24 ghante me " + bad + " miss ya reject")
        }
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        if (hour >= 22 || hour < 7) {
            score += 10
            reasons.add("raat ki call")
        }
        if (n.length == 10 && trusted(ctx, n)) {
            score -= 55
            reasons.add("pehle baat ho chuki")
        }
        if (score < 0) score = 0
        if (score > 99) score = 99
        return Result(score, reasons)
    }

    fun learn(
        ctx: Context,
        raw: String,
        wasIncoming: Boolean,
        answered: Boolean,
        auto: Boolean,
        cause: Int,
        connectMs: Long
    ) {
        try {
            if (!wasIncoming || auto) return
            val n = last10(raw)
            if (n.length != 10) return
            val b = brain(ctx)
            val e = b.edit()
            if (!answered && cause == android.telecom.DisconnectCause.REJECTED) {
                e.putInt("r_" + n, b.getInt("r_" + n, 0) + 1)
            }
            if (answered && connectMs > 0) {
                val dur = System.currentTimeMillis() - connectMs
                if (dur in 1..7000) {
                    e.putInt("s_" + n, b.getInt("s_" + n, 0) + 1)
                }
            }
            e.apply()
        } catch (ex: Throwable) {
        }
    }
}
