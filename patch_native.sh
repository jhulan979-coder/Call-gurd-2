python3 - << 'PY'
import os
p = 'android/app/src/main/kotlin/com/example/call_guard/CallGuardInCallService.kt'
if not os.path.exists(p):
    print('INCALL FILE NAHI MILI')
else:
    s = open(p, encoding='utf-8').read()
    n = 0

    def rep(a, b):
        global s, n
        if a in s:
            s = s.replace(a, b, 1)
            n += 1
        else:
            print('BRAIN PATCH MISS: ' + a[:50])

    rep('    val circles = HashMap<String, String>()\n',
        '    val circles = HashMap<String, String>()\n    val risks = HashMap<String, String>()\n')

    a = s.find('    fun circleFor(num: String): String {')
    b = s.find('    fun lookup(ctx: Context, raw: String): String? {')
    if a >= 0 and b > a:
        new_cf = r'''    fun circleFor(num: String): String {
        var out = ""
        val c = circles[num]
        if (c != null) out += "  |  " + c
        val r = risks[num]
        if (r != null) out += "  |  " + r
        return out
    }

'''
        s = s[:a] + new_cf + s[b:]
        n += 1
    else:
        print('BRAIN PATCH MISS: circleFor')

    rep('        if (call.state == Call.STATE_RINGING) {\n            incomingCalls.add(call)',
        r'''        try {
            val raw3 = call.details.handle?.schemeSpecificPart ?: ""
            val dg = raw3.filter { it.isDigit() }
            val n3 = if (dg.length > 10) dg.substring(dg.length - 10) else dg
            val br = SpamBrain.evaluate(this, raw3)
            if (br.score >= 35) {
                CallHolder.risks[n3] = br.badge
                infoMap[call] = (infoMap[call] ?: "") + "  |  " + br.badge
            }
        } catch (e: Throwable) {
        }
        if (call.state == Call.STATE_RINGING) {
            incomingCalls.add(call)''')

    rep('        if (wasIncoming && !answered && !auto &&',
        r'''        try {
            val rawL = call.details.handle?.schemeSpecificPart ?: ""
            SpamBrain.learn(this, rawL, wasIncoming, answered, auto, cause, call.details.connectTimeMillis)
        } catch (e: Throwable) {
        }
        if (wasIncoming && !answered && !auto &&''')

    a2 = s.find('    private fun shouldAutoAnswer(call: Call): Boolean {')
    b2 = s.find('    private fun startAutoAnswer(call: Call) {')
    if a2 >= 0 and b2 > a2:
        new_sa = r'''    private var lastReason = ""

    private fun shouldAutoAnswer(call: Call): Boolean {
        try {
            val p = prefs()
            if (!p.getBoolean("flutter.spamAnswer", false)) return false
            val raw = call.details.handle?.schemeSpecificPart ?: ""
            val n = SpamBrain.last10(raw)
            val dn = call.details.callerDisplayName
            if (!dn.isNullOrEmpty()) return false
            val saved = CallHolder.lookup(this, raw)
            if (!saved.isNullOrEmpty()) return false
            val br = SpamBrain.evaluate(this, raw)
            lastReason = br.badge + ": " + br.reasons.joinToString(", ")
            if (n.length == 10 && isSpamNum(n)) return true
            if (p.getBoolean("flutter.spamAnswerSus", false) && br.score >= SpamBrain.threshold(this)) return true
            if (p.getBoolean("flutter.spamAnswerAll", false)) return true
        } catch (e: Throwable) {
        }
        return false
    }

'''
        s = s[:a2] + new_sa + s[b2:]
        n += 1
    else:
        print('BRAIN PATCH MISS: shouldAutoAnswer')

    rep('info("Spam call apne aap uthayi", CallHolder.label(this, call))',
        'info("Spam call apne aap uthayi", CallHolder.label(this, call) + "  |  " + lastReason)')
    open(p, 'w', encoding='utf-8').write(s)
    print('BRAIN PATCH OK: ' + str(n))
PY
