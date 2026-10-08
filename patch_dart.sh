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
python3 - << 'PY'
import os
if os.path.exists('lib/callreport.dart') and os.path.exists('lib/settings_page.dart'):
    q = 'lib/settings_page.dart'
    t = open(q, encoding='utf-8').read()
    if 'CallReportTile' in t:
        print('REPORT TILE ALREADY')
    else:
        t = t.replace("import 'core.dart';", "import 'core.dart';\nimport 'callreport.dart';", 1)
        if 'const AssistantSettingsTile(),' in t:
            t = t.replace('const AssistantSettingsTile(),', 'const AssistantSettingsTile(),\n          const CallReportTile(),', 1)
            print('REPORT TILE OK')
        elif "_head('AI')," in t:
            t = t.replace("_head('AI'),", "const CallReportTile(),\n          _head('AI'),", 1)
            print('REPORT TILE OK (AI ke upar)')
        else:
            print('REPORT TILE MISS')
        open(q, 'w', encoding='utf-8').write(t)
PY
python3 - << 'PY'
import os
n = 0

p = 'lib/core.dart'
if os.path.exists(p):
    s = open(p, encoding='utf-8').read()
    if 'String cgDur' not in s:
        s += "\nString cgDur(int s) {\n  if (s <= 0) return '';\n  final m = s ~/ 60;\n  final r = s % 60;\n  return m > 0 ? m.toString() + 'm ' + r.toString() + 's' : r.toString() + 's';\n}\n\nString cgAgo(int date, int dur) {\n  return timeAgo(date) + (dur > 0 ? '  |  ' + cgDur(dur) : '');\n}\n"
        open(p, 'w', encoding='utf-8').write(s)
        n += 1

q = 'lib/calls_tab.dart'
if os.path.exists(q):
    t = open(q, encoding='utf-8').read()
    if 'final int dur;' not in t:
        a = '  final int type;\n  CallItem(this.number, this.name, this.date, this.type);'
        b = "(m['date'] ?? 0) as int, (m['type'] ?? 0) as int));"
        if a in t and b in t:
            t = t.replace(a, '  final int type;\n  final int dur;\n  CallItem(this.number, this.name, this.date, this.type, [this.dur = 0]);', 1)
            t = t.replace(b, "(m['date'] ?? 0) as int, (m['type'] ?? 0) as int,\n          (m['dur'] ?? 0) as int));", 1)
            open(q, 'w', encoding='utf-8').write(t)
            n += 1
        else:
            print('DURATION MISS: calls_tab CallItem')

m = 'lib/main.dart'
if os.path.exists(m):
    x = open(m, encoding='utf-8').read()
    if 'cgAgo(' not in x:
        b = "(m['date'] ?? 0) as int, (m['type'] ?? 0) as int));"
        if b in x and 'timeAgo(c.date)' in x:
            x = x.replace(b, "(m['date'] ?? 0) as int, (m['type'] ?? 0) as int,\n              (m['dur'] ?? 0) as int));", 1)
            x = x.replace('timeAgo(c.date)', 'cgAgo(c.date, c.dur)')
            open(m, 'w', encoding='utf-8').write(x)
            n += 1
        else:
            print('DURATION MISS: main Home list')

r = 'lib/recordings.dart'
if os.path.exists(r):
    y = open(r, encoding='utf-8').read()
    if 'cgDur(' not in y:
        a1 = '      _items = list;\n      _loading = false;'
        a2 = "subtitle: Text(_when(r['ts'] as int)),"
        if a1 in y and a2 in y:
            y = y.replace(a1, "      _items = list;\n      for (final rr in list) {\n        final sm = (rr['summary'] ?? '') as String;\n        if (sm.isNotEmpty) _sum[rr['path'] as String] = sm;\n      }\n      _loading = false;", 1)
            y = y.replace(a2, "subtitle: Text(_when(r['ts'] as int) + (((r['dur'] ?? 0) as int) > 0 ? '  |  ' + cgDur((r['dur'] ?? 0) as int) : '')),", 1)
            open(r, 'w', encoding='utf-8').write(y)
            n += 1
        else:
            print('SUMMARY MISS: recordings page')
print('DURATION AND SUMMARY DART DONE: ' + str(n))
PY
