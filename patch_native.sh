M=android/app/src/main/AndroidManifest.xml
K=android/app/src/main/kotlin/com/example/call_guard
R=android/app/src/main/res
sed -i 's/android:label="Call Guard"/android:label="Pehredaar"/' $M
for g in android/app/build.gradle.kts android/app/build.gradle; do [ -f $g ] && sed -i 's/com\.jhulan\.callguard/com.jhulan.pehredaar/' $g; done
sed -i 's/#1565C0/#212529/' $R/values/cg_colors.xml
sed -i 's/#FFFFFF/#FF9933/; s/#1565C0/#212529/' $R/drawable/cg_icon_fg.xml
sed -i 's/Call Guard/Pehredaar/g' $K/*.kt lib/*.dart
sed -i 's/#0D1B2A/#16191C/g; s/#1B3A5C/#2B3035/g; s/#1E88E5/#FF9933/g; s/#90CAF9/#FFCC80/g' $K/InCallActivity.kt
sed -i -E 's/(seedColor|colorSchemeSeed): *(const )?(Color\([^)]*\)|[A-Za-z0-9_.]+(\[[0-9]+\])?)/\1: const Color(0xFFFF9933)/' lib/main.dart
grep -q 0xFFFF9933 lib/main.dart || echo "WARNING: theme rang nahi laga"
echo "REBRAND DONE"
sed -i -E 's/gemini-[0-9][0-9a-z.-]*/gemini-flash-latest/g' lib/core.dart $K/CircleLookup.kt $K/AiGuess.kt
grep -q spamWhy $K/MainActivity.kt || sed -i 's#"requestNotificationPermission" -> requestNotif(result)#"requestNotificationPermission" -> requestNotif(result)\n                    "spamWhy" -> { val sr = SpamBrain.evaluate(this, call.argument<String>("number") ?: ""); result.success(sr.badge + ": " + sr.reasons.joinToString(", ")) }#' $K/MainActivity.kt
echo "AI UPDATE DONE"
grep -q hasSms $K/MainActivity.kt || sed -i 's#"requestNotificationPermission" -> requestNotif(result)#"requestNotificationPermission" -> requestNotif(result)\n                    "hasSms" -> result.success(checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED)\n                    "requestSms" -> { requestPermissions(arrayOf(Manifest.permission.SEND_SMS), 1012); result.success(true) }\n                    "canOverlay" -> result.success(android.provider.Settings.canDrawOverlays(this))\n                    "requestOverlay" -> { startActivity(android.content.Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION, android.net.Uri.parse("package:" + packageName))); result.success(true) }#' $K/MainActivity.kt
grep -q SEND_SMS android/app/src/main/AndroidManifest.xml || sed -i 's#<application#<uses-permission android:name="android.permission.SEND_SMS"/>\n    <application#' android/app/src/main/AndroidManifest.xml
grep -q SYSTEM_ALERT_WINDOW android/app/src/main/AndroidManifest.xml || sed -i 's#<application#<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>\n    <application#' android/app/src/main/AndroidManifest.xml
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
python3 - << 'PY'
import os
base = 'android/app/src/main/'
n = 0
p = base + 'kotlin/com/example/call_guard/MainActivity.kt'
if os.path.exists(p):
    s = open(p, encoding='utf-8').read()
    if 'FlutterFragmentActivity' not in s:
        s = s.replace('import io.flutter.embedding.android.FlutterActivity', 'import io.flutter.embedding.android.FlutterFragmentActivity')
        s = s.replace(': FlutterActivity()', ': FlutterFragmentActivity()')
        open(p, 'w', encoding='utf-8').write(s)
    if 'FlutterFragmentActivity()' in s:
        n += 1
    else:
        print('BIO MISS: MainActivity')
else:
    print('BIO MISS: MainActivity file nahi mili')
m = base + 'AndroidManifest.xml'
t = open(m, encoding='utf-8').read()
if 'USE_BIOMETRIC' not in t:
    t = t.replace('<application', '<uses-permission android:name="android.permission.USE_BIOMETRIC"/>\n    <application', 1)
    open(m, 'w', encoding='utf-8').write(t)
if 'USE_BIOMETRIC' in t:
    n += 1
for f in ('res/values/styles.xml', 'res/values-night/styles.xml'):
    q = base + f
    if os.path.exists(q):
        x = open(q, encoding='utf-8').read()
        y = x.replace('parent="@android:style/Theme.Light.NoTitleBar"', 'parent="Theme.AppCompat.Light.NoActionBar"')
        y = y.replace('parent="@android:style/Theme.Black.NoTitleBar"', 'parent="Theme.AppCompat.NoActionBar"')
        if y != x:
            open(q, 'w', encoding='utf-8').write(y)
            n += 1
for g in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    if os.path.exists(g):
        c = open(g, encoding='utf-8').read()
        if 'androidx.appcompat:appcompat' not in c:
            c += '\ndependencies {\n    implementation("androidx.appcompat:appcompat:1.7.0")\n}\n'
            open(g, 'w', encoding='utf-8').write(c)
        n += 1
print('BIOMETRIC SETUP DONE: ' + str(n))
PY
python3 - << 'PY'
import os
base = 'android/app/src/main/kotlin/com/example/call_guard/'
if not os.path.exists(base + 'SpamAssistant.kt'):
    print('ASSISTANT FILE NAHI HAI, skip')
else:
    ok = 0
    p = base + 'CallGuardInCallService.kt'
    s = open(p, encoding='utf-8').read()
    if 'SpamAssistant' not in s:
        a = 's.setMuted(true)'
        if a in s:
            s = s.replace(a, 'if (SpamAssistant.start(s, call, s.infoMap[call] ?: "Unknown")) { s.openUi() } else { s.setMuted(true) }', 1)
            ok += 1
        else:
            print('ASSISTANT MISS: setMuted')
        if '}, 30000)' in s:
            s = s.replace('}, 30000)', '}, 45000)', 1)
            ok += 1
        else:
            print('ASSISTANT MISS: 30000')
        b = 'val wasIncoming = incomingCalls.remove(call)'
        if b in s:
            s = s.replace(b, 'SpamAssistant.stop(this)\n        ' + b, 1)
            ok += 1
        else:
            print('ASSISTANT MISS: onCallRemoved')
        open(p, 'w', encoding='utf-8').write(s)
    m = base + 'MainActivity.kt'
    t = open(m, encoding='utf-8').read()
    if 'listRecs' not in t:
        key = '"requestNotificationPermission" -> requestNotif(result)'
        if key in t:
            add = key + '\n'
            add += '                    "listRecs" -> result.success(SpamAssistant.list(this))\n'
            add += '                    "deleteRec" -> result.success(SpamAssistant.delete(this, call.argument<String>("path") ?: ""))\n'
            add += '                    "playRec" -> result.success(SpamAssistant.play(this, call.argument<String>("path") ?: ""))\n'
            add += '                    "stopRec" -> { SpamAssistant.stopPlay(); result.success(true) }\n'
            add += '                    "requestMic" -> { if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) { result.success(true) } else { requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1011); result.success(false) } }'
            t = t.replace(key, add, 1)
            open(m, 'w', encoding='utf-8').write(t)
            ok += 1
        else:
            print('ASSISTANT MISS: MainActivity key')
    print('ASSISTANT NATIVE OK: ' + str(ok))
PY
python3 - << 'PY'
import os
base = 'android/app/src/main/kotlin/com/example/call_guard/'
n = 0
p = base + 'CallGuardInCallService.kt'
if os.path.exists(p) and os.path.exists(base + 'CgLog.kt'):
    s = open(p, encoding='utf-8').read()
    if 'CgLog' not in s:
        i = s.find('private fun shouldAutoAnswer(call: Call): Boolean {')
        j = s.find('val dn = call.details.callerDisplayName', i) if i >= 0 else -1
        if i >= 0 and j > i:
            s = s[:j] + 'if (n.length == 10 && isSpamNum(n)) return true\n            ' + s[j:]
            n += 1
        else:
            print('BLOCKFIX MISS')
        a = 'if (shouldAutoAnswer(call)) {'
        if a in s:
            s = s.replace(a, 'val autoDec = shouldAutoAnswer(call)\n            CgLog.add(this, "INCALL " + (infoMap[call] ?: "?") + " auto=" + autoDec + " spamAnswer=" + prefs().getBoolean("flutter.spamAnswer", false) + " assistant=" + prefs().getBoolean("flutter.assistant", false))\n            if (autoDec) {', 1)
            n += 1
        else:
            print('LOG MISS: shouldAutoAnswer call')
        open(p, 'w', encoding='utf-8').write(s)
q = base + 'CallGuardScreeningService.kt'
if os.path.exists(q) and os.path.exists(base + 'CgLog.kt'):
    t = open(q, encoding='utf-8').read()
    if 'CgLog' not in t:
        a = 'override fun onScreenCall(callDetails: Call.Details) {'
        if a in t:
            t = t.replace(a, a + '\n        try { CgLog.add(this, "SCREEN " + (callDetails.handle?.schemeSpecificPart ?: "hidden")) } catch (e: Throwable) {}', 1)
            n += 1
        else:
            print('LOG MISS: onScreenCall')
        b = 'respondToCall(callDetails, response)'
        if b in t:
            t = t.replace(b, 'try { CgLog.add(this, "SCREEN result reject=" + response.disallowCall) } catch (e: Throwable) {}\n        ' + b, 1)
            n += 1
        else:
            print('LOG MISS: respondToCall')
        open(q, 'w', encoding='utf-8').write(t)
r = base + 'SpamAssistant.kt'
if os.path.exists(r) and os.path.exists(base + 'CgLog.kt'):
    u = open(r, encoding='utf-8').read()
    if 'CgLog' not in u:
        def rep(a, b):
            global u, n
            if a in u:
                u = u.replace(a, b, 1)
                n += 1
            else:
                print('ASSIST LOG MISS: ' + a[:45])
        rep('if (!p.getBoolean("flutter.assistant", false)) return false',
            'if (!p.getBoolean("flutter.assistant", false)) { CgLog.add(ctx, "ASSISTANT band hai, Settings me on karo"); return false }')
        rep('        active = true\n        info = who',
            '        active = true\n        CgLog.add(ctx, "ASSISTANT start")\n        info = who')
        rep('if (ctx.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return',
            'if (ctx.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) { CgLog.add(ctx, "REC mic permission nahi"); return }')
        rep('            r.start()\n            rec = r\n            recFile = f',
            '            r.start()\n            rec = r\n            recFile = f\n            CgLog.add(ctx, "REC start ok")')
        rep('        } catch (e: Throwable) {\n            rec = null\n            recFile = null\n        }',
            '        } catch (e: Throwable) {\n            CgLog.add(ctx, "REC start FAIL " + e.toString())\n            rec = null\n            recFile = null\n        }')
        rep('        if (ok && f != null && f.exists() && f.length() > 2000) {',
            '        CgLog.add(ctx, "REC stop ok=" + ok + " size=" + (f?.length() ?: -1))\n        if (ok && f != null && f.exists() && f.length() > 2000) {')
        open(r, 'w', encoding='utf-8').write(u)
print('REPORT NATIVE DONE: ' + str(n))
PY
python3 - << 'PY'
import os
base = 'android/app/src/main/kotlin/com/example/call_guard/'
n = 0

m = base + 'MainActivity.kt'
if os.path.exists(m):
    t = open(m, encoding='utf-8').read()
    if 'CallLog.Calls.DURATION' not in t:
        a = 'CallLog.Calls.DATE, CallLog.Calls.TYPE)'
        b = '"type" to it.getInt(3)'
        if a in t and b in t:
            t = t.replace(a, 'CallLog.Calls.DATE, CallLog.Calls.TYPE, CallLog.Calls.DURATION)', 1)
            t = t.replace(b, '"type" to it.getInt(3),\n                    "dur" to it.getLong(4)', 1)
            open(m, 'w', encoding='utf-8').write(t)
            n += 1
        else:
            print('DURATION MISS: MainActivity readCalls')

p = base + 'CallGuardInCallService.kt'
if os.path.exists(p):
    s = open(p, encoding='utf-8').read()
    if 'postEnded' not in s:
        fn = r'''    private fun postEnded(info: String, sec: Long) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel("cg_ended", "Call khatam", NotificationManager.IMPORTANCE_DEFAULT)
                )
            }
            val b = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(this, "cg_ended")
            } else {
                Notification.Builder(this)
            }
            val mm = sec / 60
            val ss = sec % 60
            val d = if (mm > 0) mm.toString() + " min " + ss.toString() + " sec" else ss.toString() + " sec"
            b.setSmallIcon(android.R.drawable.ic_menu_call)
            b.setContentTitle("Call khatam  |  " + d)
            b.setContentText(info)
            b.setAutoCancel(true)
            val launch = packageManager.getLaunchIntentForPackage(packageName)
            if (launch != null) {
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                b.setContentIntent(PendingIntent.getActivity(this, 4, launch, flags))
            }
            nm.notify(7300 + (System.currentTimeMillis() % 40).toInt(), b.build())
        } catch (e: Throwable) {
        }
    }

'''
        a1 = '    private fun postMissed(info: String) {'
        if a1 in s:
            s = s.replace(a1, fn + a1, 1)
            n += 1
        else:
            print('ENDED MISS: postMissed')
        a2 = '        if (wasIncoming && !answered && !auto &&'
        blk = r'''        try {
            val ct = call.details.connectTimeMillis
            if (answered && !auto && ct > 0) {
                postEnded(info, (System.currentTimeMillis() - ct) / 1000)
            }
        } catch (e: Throwable) {
        }
'''
        if a2 in s:
            s = s.replace(a2, blk + a2, 1)
            n += 1
        else:
            print('ENDED MISS: onCallRemoved')
        open(p, 'w', encoding='utf-8').write(s)

r = base + 'SpamAssistant.kt'
if os.path.exists(r) and os.path.exists(base + 'CallSummary.kt'):
    u = open(r, encoding='utf-8').read()
    if 'CallSummary' not in u:
        def rep(a, b):
            global u, n
            if a in u:
                u = u.replace(a, b, 1)
                n += 1
            else:
                print('SUMMARY MISS: ' + a[:45])
        rep('    private var player: MediaPlayer? = null',
            '    private var player: MediaPlayer? = null\n    private var recStartMs = 0L')
        rep('            rec = r\n            recFile = f',
            '            rec = r\n            recFile = f\n            recStartMs = System.currentTimeMillis()')
        rep('            o.put("s", f.length())',
            '            o.put("s", f.length())\n            o.put("d", (System.currentTimeMillis() - recStartMs) / 1000)')
        rep('"size" to o.optLong("s")',
            '"size" to o.optLong("s"),\n                            "summary" to o.optString("m"),\n                            "dur" to o.optLong("d")')
        rep('            addMeta(ctx, f)\n            notifyDone(ctx)',
            '            addMeta(ctx, f)\n            notifyDone(ctx)\n            CallSummary.run(ctx, f.absolutePath, info)')
        open(r, 'w', encoding='utf-8').write(u)
print('DURATION AND SUMMARY NATIVE DONE: ' + str(n))
PY
