import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core.dart';

const _aiCh = MethodChannel('callguard/native');

const _scamSystem =
    'Tum ek scam jaanch helper ho. User ek message ya link paste karega. '
    'Sabse pehli line me exactly is format me likho: VERDICT: SAFE ya VERDICT: SUSPICIOUS ya VERDICT: SCAM. '
    'Phir 3-5 chhoti lines me wajah batao (kaunse shabd ya link shak wale hain) aur ek line me batao kya karna chahiye. '
    'Kabhi OTP, PIN, CVV ya bank details bhejne ko mat kaho aur kisi link ko kholne ko mat kaho. '
    'Pakka na ho to saaf bolo ki ye sirf andaza hai.';

Color _verdictColor(String r) {
  final u = r.toUpperCase();
  if (u.contains('VERDICT: SCAM')) return Colors.red;
  if (u.contains('VERDICT: SUSPICIOUS')) return Colors.orange;
  if (u.contains('VERDICT: SAFE')) return Colors.green;
  return Colors.blueGrey;
}

class AiToolsCard extends StatelessWidget {
  const AiToolsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: cs.primary),
                const SizedBox(width: 8),
                const Text('AI Tools',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mark_email_unread_outlined),
            title: const Text('Message / link scam checker'),
            subtitle: const Text('Shak wala message paste karo'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScamCheckPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Hafte ki spam report'),
            subtitle: const Text('Pichle 7 din ki calls ka hisaab'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeeklyReportPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class ScamCheckPage extends StatefulWidget {
  const ScamCheckPage({super.key});

  @override
  State<ScamCheckPage> createState() => _ScamCheckPageState();
}

class _ScamCheckPageState extends State<ScamCheckPage> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _res;

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    if (d != null && d.text != null) {
      setState(() => _c.text = d.text!);
    }
  }

  Future<void> _check() async {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _res = null;
    });
    try {
      final r = await askAI(_scamSystem, [
        {'role': 'user', 'content': 'Ye message jaanch karo:\n' + t}
      ]);
      if (!mounted) return;
      setState(() => _res = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _res = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final res = _res;
    return Scaffold(
      appBar: AppBar(title: const Text('Message / link scam checker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _c,
            minLines: 5,
            maxLines: 9,
            decoration: const InputDecoration(
              hintText: 'Shak wala message ya link yahan paste karo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _check,
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('AI se check karo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (res != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _verdictColor(res).withOpacity(0.1),
                border: Border.all(color: _verdictColor(res).withOpacity(0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(res),
            ),
          const SizedBox(height: 12),
          const Text(
            'Ye AI ka andaza hai, pakka nahi. Link kholne se pehle sochna, aur OTP ya PIN kisi ko mat batana.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  bool _loading = true;
  bool _ok = true;
  int _total = 0;
  int _spam = 0;
  int _missed = 0;
  int _unknown = 0;
  int _rejected = 0;
  int _outgoing = 0;
  List<MapEntry<String, int>> _top = [];
  bool _aiBusy = false;
  String? _ai;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isSpamNum(String n) =>
      store.findBlocked(n) != null ||
      n.startsWith('140') ||
      n.startsWith('160');

  Future<void> _load() async {
    setState(() => _loading = true);
    bool ok = false;
    int t = 0, s = 0, m = 0, u = 0, r = 0, o = 0;
    final counts = <String, int>{};
    try {
      ok = await _aiCh.invokeMethod<bool>('hasCallLogPermission') ?? false;
      if (ok) {
        final raw =
            await _aiCh.invokeMethod<List<dynamic>>('getRecentCalls') ?? [];
        final cut = DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch;
        for (final e in raw) {
          final mp = Map<String, dynamic>.from(e as Map);
          final date = (mp['date'] ?? 0) as int;
          if (date < cut) continue;
          final n = last10((mp['number'] ?? '') as String);
          final name = (mp['name'] ?? '') as String;
          final type = (mp['type'] ?? 0) as int;
          t++;
          if (type == 3) m++;
          if (type == 5 || type == 6) r++;
          if (type == 2) o++;
          if (name.isEmpty && type != 2) u++;
          if (type != 2 && n.length >= 10 && _isSpamNum(n)) {
            s++;
            counts[n] = (counts[n] ?? 0) + 1;
          }
        }
      }
    } catch (_) {
      ok = false;
    }
    final list = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (!mounted) return;
    setState(() {
      _ok = ok;
      _total = t;
      _spam = s;
      _missed = m;
      _unknown = u;
      _rejected = r;
      _outgoing = o;
      _top = list.take(3).toList();
      _loading = false;
    });
  }

  Future<void> _advice() async {
    setState(() {
      _aiBusy = true;
      _ai = null;
    });
    final summary =
        'Pichle 7 din me total $_total calls aayin ya gayin: $_spam spam ya shak wali, $_missed missed, $_rejected reject ya block hui, $_unknown aisi jo contacts me nahi thi, $_outgoing maine ki.';
    try {
      final r = await askAI(aiSystem, [
        {
          'role': 'user',
          'content':
              summary + ' Meri call safety ke liye chhoti salaah do (4-5 line).'
        }
      ]);
      if (!mounted) return;
      setState(() => _ai = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ai = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _aiBusy = false);
  }

  Widget _stat(String label, int v, Color c, IconData i) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: c.withOpacity(0.15),
        child: Icon(i, color: c),
      ),
      title: Text(label),
      trailing: Text(
        '$v',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hafte ki spam report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_ok
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Call log ki permission nahi mili. Home screen par Permission do dabao, phir yahan wapas aao.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _stat('Total calls', _total, cs.primary, Icons.call),
                    _stat('Spam / shak wali', _spam, Colors.red,
                        Icons.warning_amber_rounded),
                    _stat('Missed', _missed, Colors.orange, Icons.call_missed),
                    _stat('Reject / block hui', _rejected, Colors.red,
                        Icons.block),
                    _stat('Contacts me nahi thi', _unknown, Colors.blueGrey,
                        Icons.person_off_outlined),
                    _stat('Aapne ki', _outgoing, Colors.green,
                        Icons.call_made),
                    if (_top.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Sabse zyada spam wale numbers',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      ..._top.map((e) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.warning_amber_rounded,
                                color: Colors.red),
                            title: Text(e.key),
                            trailing: Text('${e.value} baar'),
                          )),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _aiBusy ? null : _advice,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('AI se salaah lo'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI ko sirf ginti jaati hai, koi number nahi. Ginti call log ki aakhri 100 calls me se hai.',
                      style: TextStyle(fontSize: 12),
                    ),
                    if (_aiBusy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_ai != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SelectableText(_ai!),
                      ),
                  ],
                ),
    );
  }
}
