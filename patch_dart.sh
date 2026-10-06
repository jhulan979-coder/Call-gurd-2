python3 - << 'PY'
import os
p = 'lib/p2pcall.dart'
if os.path.exists(p):
    s = open(p, encoding='utf-8').read()
    n = 0

    def rep(a, b):
        global s, n
        if a in s:
            s = s.replace(a, b, 1)
            n += 1
        else:
            print('PATCH MISS: ' + a[:40])

    rep("if (mounted) setState(() => _status = s);",
        "if (mounted) { final t = (_status + '\\n' + s).split('\\n'); setState(() => _status = t.sublist(t.length > 7 ? t.length - 7 : 0).join('\\n')); }")
    rep("_pc = pc;",
        "_pc = pc;\n    pc.onIceConnectionState = (RTCIceConnectionState s) {\n      _say('ICE: ' + s.toString().split('.').last);\n    };")
    rep("_say('Dost ke jawab ka intezaar...');",
        "_say('Dost ke jawab ka intezaar... Mere candidates: ' + cgCand(d?.sdp));")
    rep("_send({'t': 'answer', 'sdp': d?.sdp, 'type': d?.type});",
        "_send({'t': 'answer', 'sdp': d?.sdp, 'type': d?.type});\n        _say('Jawab bheja. Mere candidates: ' + cgCand(d?.sdp));")
    s += "\nString cgCand(String? sdp) {\n  final ips = <String>[];\n  for (final l in (sdp ?? '').split('\\n')) {\n    if (l.startsWith('a=candidate:')) {\n      final p = l.trim().split(' ');\n      if (p.length > 4) ips.add(p[4]);\n    }\n  }\n  return ips.length.toString() + ' [' + ips.toSet().join(', ') + ']';\n}\n"
    open(p, 'w', encoding='utf-8').write(s)
    print('P2P DEBUG PATCH OK: ' + str(n))
else:
    print('P2P FILE NAHI HAI, debug skip')
PY
python3 - << 'PY'
import os
p = 'lib/main.dart'
if os.path.exists(p):
    t = open(p, encoding='utf-8').read()
    m = 0

    def rep2(a, b):
        global t, m
        if a in t:
            t = t.replace(a, b, 1)
            m += 1
        else:
            print('HOME PATCH MISS: ' + a[:40])

    rep2("class _HomeTabState extends State<HomeTab> {",
         "class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {")
    rep2("    super.initState();\n    _load();",
         "    super.initState();\n    WidgetsBinding.instance.addObserver(this);\n    _load();\n    Future.delayed(const Duration(seconds: 2), () {\n      _hn.invokeMethod<bool>('requestNotificationPermission').catchError((_) => false);\n    });")
    rep2("  Future<void> _ask() async {",
         "  @override\n  void didChangeAppLifecycleState(AppLifecycleState s) {\n    if (s == AppLifecycleState.resumed) _load();\n  }\n\n  @override\n  void dispose() {\n    WidgetsBinding.instance.removeObserver(this);\n    super.dispose();\n  }\n\n  Future<void> _ask() async {")
    open(p, 'w', encoding='utf-8').write(t)
    print('HOME PATCH OK: ' + str(m))
PY
