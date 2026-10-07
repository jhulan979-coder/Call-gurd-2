python3 - << 'PY'
import os
p = 'lib/main.dart'
if os.path.exists(p):
    t = open(p, encoding='utf-8').read()
    i = t.find('class _HomeTabState extends State<HomeTab>')
    if i < 0:
        print('HOME PATCH MISS: HomeTab class nahi mili')
    else:
        head = t[:i]
        body = t[i:]
        m = 0

        def rep(a, b):
            global body, m
            if a in body:
                body = body.replace(a, b, 1)
                m += 1
            else:
                print('HOME PATCH MISS: ' + a[:40])

        rep('class _HomeTabState extends State<HomeTab> {',
            'class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {')
        rep('    super.initState();\n    _load();',
            '    super.initState();\n    WidgetsBinding.instance.addObserver(this);\n    _load();\n    Future.delayed(const Duration(seconds: 2), () {\n      _hn.invokeMethod<bool>(\'requestNotificationPermission\').catchError((_) => false);\n    });')
        rep('  Future<void> _ask() async {',
            '  @override\n  void didChangeAppLifecycleState(AppLifecycleState s) {\n    if (s == AppLifecycleState.resumed) _load();\n  }\n\n  @override\n  void dispose() {\n    WidgetsBinding.instance.removeObserver(this);\n    super.dispose();\n  }\n\n  Future<void> _ask() async {')
        open(p, 'w', encoding='utf-8').write(head + body)
        print('HOME PATCH OK: ' + str(m))
PY
python3 - << 'PY'
import os
import re
p = 'lib/settings_page.dart'
if os.path.exists(p):
    s = open(p, encoding='utf-8').read()
    if "'spamAnswerSus'" in s:
        print('SETTINGS STRONG ALREADY')
    else:
        s = s.replace("'spamAnswer': false,", "'spamAnswer': false,\n  'spamAnswerSus': false,\n  'spamAnswerAll': false,", 1)
        rows = """          _sw('spamAnswerSus', 'Shak wali calls bhi uthao', 'Chhupe, videshi, ajeeb ya baar baar aane wale unknown number. Upar wala switch on ho tabhi', enabled: _v['spamAnswer'] ?? false),
          _sw('spamAnswerAll', 'Har unknown number uthao (savdhan)', 'Contacts me na hone wale har number ko chup rehke uthayega. Zaroori call (delivery, doctor) bhi chhut sakti hai', enabled: _v['spamAnswer'] ?? false),
"""
        m = re.search(r"[ ]*_sw\('spamAnswer'[^\n]*\n", s)
        if m:
            s = s[:m.end()] + rows + s[m.end():]
            open(p, 'w', encoding='utf-8').write(s)
            print('SETTINGS STRONG PATCH OK')
        else:
            print('SETTINGS STRONG MISS: spamAnswer row nahi mili')
PY
