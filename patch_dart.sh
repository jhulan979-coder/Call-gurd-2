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
