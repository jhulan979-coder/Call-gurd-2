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
    if "'spamAnswerSus'" not in s:
        s = s.replace("'spamAnswer': false,", "'spamAnswer': false,\n  'spamAnswerSus': false,\n  'spamAnswerAll': false,", 1)
        rows = """          _sw('spamAnswerSus', 'Shak wali calls bhi uthao', 'Spam risk zyada wali calls (chhupa, videshi, baar baar aane wali). Upar wala switch on ho tabhi', enabled: _v['spamAnswer'] ?? false),
          _sw('spamAnswerAll', 'Har unknown number uthao (savdhan)', 'Contacts me na hone wale har number ko chup rehke uthayega. Zaroori call (delivery, doctor) bhi chhut sakti hai', enabled: _v['spamAnswer'] ?? false),
"""
        m = re.search(r"[ ]*_sw\('spamAnswer'[^\n]*\n", s)
        if m:
            s = s[:m.end()] + rows + s[m.end():]
            print('SETTINGS STRONG PATCH OK')
        else:
            print('SETTINGS STRONG MISS: spamAnswer row nahi mili')
    else:
        print('SETTINGS STRONG ALREADY')
    k = 0
    methods = """  String _spamLevel = 'med';

  Future<void> _loadLevel() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _spamLevel = p.getString('spamLevel') ?? 'med');
  }

  Future<void> _pickLevel() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Spam sensitivity'),
        children: [
          for (final e in const [
            ['low', 'Kam (sirf pakka spam)'],
            ['med', 'Beech ka'],
            ['high', 'Zyada (shak par bhi)'],
          ])
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                final p = await SharedPreferences.getInstance();
                await p.setString('spamLevel', e[0]);
                if (mounted) setState(() => _spamLevel = e[0]);
              },
              child: Text(e[1]),
            ),
        ],
      ),
    );
  }

"""
    tile = """          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Spam sensitivity'),
            subtitle: Text(_spamLevel == 'low' ? 'Kam (sirf pakka spam)' : (_spamLevel == 'high' ? 'Zyada (shak par bhi)' : 'Beech ka')),
            onTap: _pickLevel,
          ),
"""
    a1 = '    _load();\n    _checkDefault();'
    if a1 in s:
        s = s.replace(a1, a1 + '\n    _loadLevel();', 1)
        k += 1
    else:
        print('SENSITIVITY MISS: initState')
    a2 = '  Future<void> _set(String k, bool x) async {'
    if a2 in s:
        s = s.replace(a2, methods + a2, 1)
        k += 1
    else:
        print('SENSITIVITY MISS: methods')
    a3 = "_head('Awaaz aur ring'),"
    if a3 in s:
        s = s.replace(a3, tile + '          ' + a3, 1)
        k += 1
    else:
        print('SENSITIVITY MISS: row')
    open(p, 'w', encoding='utf-8').write(s)
    print('SENSITIVITY PATCH OK: ' + str(k))
PY
python3 - << 'PY'
import os
import re
if os.path.exists('lib/applock.dart'):
    p = 'pubspec.yaml'
    s = open(p, encoding='utf-8').read()
    if 'local_auth:' in s:
        print('LOCAL_AUTH ALREADY')
    else:
        t = re.sub(r'(\n  flutter_tts:[^\n]*)', r'\1\n  local_auth: ^2.3.0', s, count=1)
        if t != s:
            open(p, 'w', encoding='utf-8').write(t)
            print('LOCAL_AUTH ADDED')
        else:
            print('LOCAL_AUTH MISS: flutter_tts line nahi mili')
PY
