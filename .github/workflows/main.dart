import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const categories = ['Spam', 'Scam / Fraud', 'Telemarketing', 'Other'];

const aiSystem =
    'Tum Call Guard app ke AI helper ho. Hinglish me chhote aur saaf jawab do (zyada se zyada 6-7 line). '
    'Spam, scam aur telemarketing calls pehchanne aur unse bachne me madad karo. '
    'Kisi khaas phone number ke baare me tum pakka nahi bata sakte, isliye sirf sambhavna aur salah do. '
    'Kabhi OTP, PIN, CVV ya bank details share karne ko mat kaho.';

class Entry {
  final String number;
  final String label;
  final int ts;
  Entry(this.number, this.label, this.ts);

  Map<String, dynamic> toJson() => {'n': number, 'l': label, 't': ts};

  factory Entry.fromJson(Map<String, dynamic> j) =>
      Entry(j['n'] as String, j['l'] as String, j['t'] as int);
}

String last10(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

String timeAgo(int ts) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
  if (d.inMinutes < 1) return 'abhi';
  if (d.inMinutes < 60) return '${d.inMinutes} min pehle';
  if (d.inHours < 24) return '${d.inHours} ghante pehle';
  return '${d.inDays} din pehle';
}

class Store extends ChangeNotifier {
  List<Entry> blocked = [];
  List<Entry> history = [];
  String apiKey = '';
  bool loaded = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    blocked = _decode(p.getString('blocked_v2'));
    history = _decode(p.getString('history_v2'));
    apiKey = p.getString('api_key') ?? '';
    loaded = true;
    notifyListeners();
  }

  List<Entry> _decode(String? s) {
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'blocked_v2', jsonEncode(blocked.map((e) => e.toJson()).toList()));
    await p.setString(
        'history_v2', jsonEncode(history.map((e) => e.toJson()).toList()));
    await p.setString('api_key', apiKey);
  }

  Entry? findBlocked(String number) {
    final n = last10(number);
    for (final e in blocked) {
      if (e.number == n) return e;
    }
    return null;
  }

  void block(String number, String label) {
    final n = last10(number);
    if (n.length < 10 || findBlocked(n) != null) return;
    blocked.insert(0, Entry(n, label, DateTime.now().millisecondsSinceEpoch));
    notifyListeners();
    _persist();
  }

  void unblock(String number) {
    blocked.removeWhere((e) => e.number == number);
    notifyListeners();
    _persist();
  }

  void addHistory(String number, String verdict) {
    final n = last10(number);
    history.removeWhere((e) => e.number == n);
    history.insert(0, Entry(n, verdict, DateTime.now().millisecondsSinceEpoch));
    if (history.length > 20) history = history.sublist(0, 20);
    notifyListeners();
    _persist();
  }

  void setKey(String k) {
    apiKey = k;
    notifyListeners();
    _persist();
  }

  Future<void> clearAll() async {
    blocked = [];
    history = [];
    apiKey = '';
    notifyListeners();
    await _persist();
  }
}

final store = Store();

Future<String> askAI(String system, List<Map<String, String>> messages) async {
  if (store.apiKey.isEmpty) {
    throw Exception('Pehle AI tab me API key daalo');
  }
  final res = await http.post(
    Uri.parse('https://api.anthropic.com/v1/messages'),
    headers: {
      'content-type': 'application/json',
      'x-api-key': store.apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: jsonEncode({
      'model': 'claude-haiku-4-5-20251001',
      'max_tokens': 600,
      'system': system,
      'messages': messages,
    }),
  );
  final data = jsonDecode(utf8.decode(res.bodyBytes));
  if (res.statusCode != 200) {
    String msg = 'Error ${res.statusCode}';
    if (data is Map && data['error'] is Map) {
      msg = '${data['error']['message']}';
    }
    throw Exception(msg);
  }
  return (data['content'] as List).map((c) => c['text'] ?? '').join();
}

void main() => runApp(const CallGuardApp());

class CallGuardApp extends StatelessWidget {
  const CallGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Guard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          brightness: Brightness.light),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          brightness: Brightness.dark),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    store.load();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saara data delete karo?'),
        content: const Text('Block list, history aur API key sab hat jayenge.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nahi')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Haan, delete karo')),
        ],
      ),
    );
    if (ok == true) await store.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Guard'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _confirmClear();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Saara data delete karo')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(onGo: (i) => setState(() => _tab = i)),
          const CheckTab(),
          const BlockedTab(),
          const AiTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Check'),
          NavigationDestination(icon: Icon(Icons.block), label: 'Blocked'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'AI'),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;
  const StatCard(
      {super.key,
      required this.icon,
      required this.value,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  final void Function(int) onGo;
  const HomeTab({super.key, required this.onGo});

  static const tips = [
    'OTP, PIN ya CVV kisi ko kabhi mat batao, chahe bank ka naam le.',
    'Lottery ya inaam ka call hamesha fraud hota hai.',
    'Unknown link ya APK file kabhi install mat karo.',
    'Shak ho to call kaato aur bank ke official number par khud call karo.',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.shield, size: 44, color: cs.primary),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aap surakshit rahein',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Unknown number ko pehle check karo, phir call uthao.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.block,
                    value: '${store.blocked.length}',
                    label: 'Blocked',
                    onTap: () => onGo(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    icon: Icons.search,
                    value: '${store.history.length}',
                    label: 'Checks',
                    onTap: () => onGo(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Aakhri checks', style: Theme.of(context).textTheme.titleMedium),
            if (store.history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Abhi koi check nahi hua'),
              ),
            ...store.history.take(5).map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(e.number),
                  subtitle: Text(e.label),
                  trailing: Text(timeAgo(e.ts)),
                )),
            const SizedBox(height: 16),
            Text('Safety tips', style: Theme.of(context).textTheme.titleMedium),
            ...tips.map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.tips_and_updates_outlined),
                  title: Text(t),
                )),
            const SizedBox(height: 16),
            const Center(child: Text('Call Guard v2', style: TextStyle(fontSize: 12))),
          ],
        );
      },
    );
  }
}

class CheckTab extends StatefulWidget {
  const CheckTab({super.key});

  @override
  State<CheckTab> createState() => _CheckTabState();
}

class _CheckTabState extends State<CheckTab> {
  final _c = TextEditingController();
  String? _verdict;
  Color _color = Colors.grey;
  IconData _icon = Icons.help_outline;
  String _number = '';
  String _cat = categories[0];
  bool _aiLoading = false;
  String? _aiText;

  bool get _isBlocked => _number.isNotEmpty && store.findBlocked(_number) != null;

  void _check() {
    FocusScope.of(context).unfocus();
    final raw = _c.text.trim();
    final n = last10(raw);
    if (n.length < 10) {
      setState(() {
        _number = '';
        _aiText = null;
        _verdict = 'Poora 10 digit number daalo';
        _color = Colors.orange;
        _icon = Icons.warning_amber;
      });
      return;
    }
    String v;
    Color c;
    IconData i;
    final b = store.findBlocked(n);
    if (b != null) {
      v = 'Aapki block list me hai (${b.label})';
      c = Colors.red;
      i = Icons.block;
    } else if (n.startsWith('140') || n.startsWith('160')) {
      v = 'Shak: telemarketing / promotional number';
      c = Colors.orange;
      i = Icons.campaign;
    } else if (raw.startsWith('+') && !raw.startsWith('+91')) {
      v = 'International number, savdhan rahein';
      c = Colors.orange;
      i = Icons.public;
    } else if (RegExp(r'^(\d)\1{9}$').hasMatch(n)) {
      v = 'Shak: sabhi digit ek jaise hain';
      c = Colors.orange;
      i = Icons.warning_amber;
    } else {
      v = 'Koi spam report nahi mili';
      c = Colors.green;
      i = Icons.verified_user;
    }
    store.addHistory(n, v);
    setState(() {
      _number = n;
      _aiText = null;
      _verdict = v;
      _color = c;
      _icon = i;
    });
  }

  Future<void> _askAi() async {
    setState(() {
      _aiLoading = true;
      _aiText = null;
    });
    try {
      final r = await askAI(aiSystem, [
        {
          'role': 'user',
          'content':
              'Ye phone number mujhe call kar raha hai: $_number. App ka basic check: $_verdict. '
                  'Kya ye spam ya scam ho sakta hai? Chhota jawab do aur batao mujhe kya karna chahiye.'
        }
      ]);
      if (!mounted) return;
      setState(() => _aiText = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiText = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _aiLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _c,
          keyboardType: TextInputType.phone,
          onSubmitted: (_) => _check(),
          decoration: InputDecoration(
            labelText: 'Phone number',
            prefixIcon: const Icon(Icons.phone),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _c.clear();
                setState(() {
                  _verdict = null;
                  _number = '';
                  _aiText = null;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _check,
          icon: const Icon(Icons.search),
          label: const Text('Number check karo'),
        ),
        const SizedBox(height: 16),
        if (_verdict != null)
          Card(
            color: _color.withOpacity(0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_icon, color: _color, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _verdict!,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _color),
                        ),
                      ),
                    ],
                  ),
                  if (_number.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (!_isBlocked) ...[
                      const Text('Category chuno:'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: categories
                            .map((x) => ChoiceChip(
                                  label: Text(x),
                                  selected: _cat == x,
                                  onSelected: (_) => setState(() => _cat = x),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          store.block(_number, _cat);
                          setState(() {
                            _verdict = 'Aapki block list me hai ($_cat)';
                            _color = Colors.red;
                            _icon = Icons.block;
                          });
                        },
                        icon: const Icon(Icons.block),
                        label: const Text('Block list me daalo'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _aiLoading ? null : _askAi,
                      icon: const Icon(Icons.smart_toy_outlined),
                      label: const Text('AI se poochho'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (_aiText != null || _aiLoading)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _aiLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SelectableText(_aiText ?? ''),
            ),
          ),
      ],
    );
  }
}

class BlockedTab extends StatefulWidget {
  const BlockedTab({super.key});

  @override
  State<BlockedTab> createState() => _BlockedTabState();
}

class _BlockedTabState extends State<BlockedTab> {
  String _q = '';

  void _addDialog() {
    final c = TextEditingController();
    String cat = categories[0];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Number block karo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: c,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '10 digit number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: categories
                    .map((x) => ChoiceChip(
                          label: Text(x),
                          selected: cat == x,
                          onSelected: (_) => setD(() => cat = x),
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  store.block(c.text, cat);
                  Navigator.pop(ctx);
                },
                child: const Text('Block')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items =
              store.blocked.where((e) => e.number.contains(_q)).to
