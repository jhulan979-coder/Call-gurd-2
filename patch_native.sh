python3 - << 'PY'
import os
p = 'android/app/src/main/kotlin/com/example/call_guard/CallGuardInCallService.kt'
if not os.path.exists(p):
    print('INCALL FILE NAHI MILI')
else:
    s = open(p, encoding='utf-8').read()
    a = s.find('    private fun shouldAutoAnswer(call: Call): Boolean {')
    b = s.find('    private fun startAutoAnswer(call: Call) {')
    if a < 0 or b < 0 or b < a:
        print('STRONG PATCH MISS: functions nahi mile')
    else:
        new = r'''    private var lastReason = ""

    private fun repeatCount(n: String): Int {
        var c = 0
        try {
            if (checkSelfPermission(android.Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) return 0
            val since = System.currentTimeMillis() - 24L * 3600L * 1000L
            val cur = contentResolver.query(
                android.provider.CallLog.Calls.CONTENT_URI,
                arrayOf(android.provider.CallLog.Calls.TYPE),
                android.provider.CallLog.Calls.NUMBER + " LIKE ? AND " + android.provider.CallLog.Calls.DATE + " > ?",
                arrayOf("%" + n, since.toString()),
                null
            )
            cur?.use {
                while (it.moveToNext()) {
                    val t = it.getInt(0)
                    if (t == android.provider.CallLog.Calls.MISSED_TYPE ||
                        t == android.provider.CallLog.Calls.REJECTED_TYPE ||
                        t == android.provider.CallLog.Calls.BLOCKED_TYPE
                    ) {
                        c++
                    }
                }
            }
        } catch (e: Throwable) {
        }
        return c
    }

    private fun shouldAutoAnswer(call: Call): Boolean {
        try {
            val p = prefs()
            if (!p.getBoolean("flutter.spamAnswer", false)) return false
            val raw = call.details.handle?.schemeSpecificPart ?: ""
            val digits = raw.filter { it.isDigit() }
            val n = if (digits.length > 10) digits.substring(digits.length - 10) else digits
            val dn = call.details.callerDisplayName
            if (!dn.isNullOrEmpty()) return false
            val saved = CallHolder.lookup(this, raw)
            if (!saved.isNullOrEmpty()) return false
            if (n.length == 10 && isSpamNum(n)) {
                lastReason = if (n.startsWith("140") || n.startsWith("160")) "telemarketing series" else "block list"
                return true
            }
            if (p.getBoolean("flutter.spamAnswerSus", false)) {
                if (raw.isEmpty()) {
                    lastReason = "chhupa number"
                    return true
                }
                if (raw.startsWith("+") && !raw.startsWith("+91")) {
                    lastReason = "videshi number"
                    return true
                }
                if (n.length != 10) {
                    lastReason = "ajeeb lambai ka number"
                    return true
                }
                if (Regex("(\\d)\\1{6,}").containsMatchIn(n)) {
                    lastReason = "ek jaise digit"
                    return true
                }
                if (repeatCount(n) >= 2) {
                    lastReason = "baar baar aane wala number"
                    return true
                }
            }
            if (p.getBoolean("flutter.spamAnswerAll", false)) {
                lastReason = "unknown number"
                return true
            }
        } catch (e: Throwable) {
        }
        return false
    }

'''
        s = s[:a] + new + s[b:]
        old = 'info("Spam call apne aap uthayi", CallHolder.label(this, call))'
        if old in s:
            s = s.replace(old, 'info("Spam call apne aap uthayi", CallHolder.label(this, call) + "  |  " + lastReason)', 1)
        else:
            print('REASON TEXT MISS')
        open(p, 'w', encoding='utf-8').write(s)
        print('STRONG SPAM PATCH OK')
PY
