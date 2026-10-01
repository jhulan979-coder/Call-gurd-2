import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core.dart';
import 'tabs.dart';
import 'ai_tab.dart';
import 'calls_tab.dart';

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
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.blue,
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool autoBlock = false;
  bool popup = true;
  bool smsSpam = true;
  bool autoReply = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      autoBlock = p.getBool('autoBlock') ?? false;
      popup = p.getBool('popup') ?? true;
      smsSpam = p.getBool('smsSpam') ?? true;
      autoReply = p.getBool('autoReply') ?? false;
    });
  }

  Future<void> _save(String k, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(k, v);
  }

  Widget _tile(String t, bool v, String k, void Function(bool) set) {
    return SwitchListTile(
      title: Text(t),
      value: v,
      onChanged: (x) {
        set(x);
        _save(k, x);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _tile('Auto call blocking', autoBlock, 'autoBlock',
              (x) => setState(() => autoBlock = x)),
          _tile('Incoming call warning popup', popup, 'popup',
              (x) => setState(() => popup = x)),
          _tile('SMS spam detection', smsSpam, 'smsSpam',
              (x) => setState(() => smsSpam = x)),
          _tile('Auto SMS reply to blocked callers', autoReply, 'autoReply',
              (x) => setState(() => autoReply = x)),
        ],
      ),
    );
  }
}class HomeStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const HomeStat(
      {super.key,
      required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const HomeBtn(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: cs.primaryContainer, shape: BoxShape.circle),
                child: Icon(icon, color: cs.primary, size: 28),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

const _hn = MethodChannel('callguard/native');

class HomeTab extends StatefulWidget {
  final void Function(int) onGo;
  const HomeTab({super.key, required this.onGo});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<CallItem> _calls = [];
  bool _ok = true;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final has =
          await _hn.invokeMethod<bool>('hasCallLogPermission') ?? false;
      _ok = has;
      if (has) {
        final raw =
            await _hn.invokeMethod<List<dynamic>>('getRecentCalls') ?? [];
        final list = <CallItem>[];
        for (final r in raw) {
          final m = Map<String, dynamic>.from(r as Map);
          final n = last10((m['number'] ?? '') as String);
          if (n.length < 10) continue;
          list.add(CallItem(n, (m['name'] ?? '') as String,
              (m['date'] ?? 0) as int, (m['type'] ?? 0) as int));
        }
        _calls = list;
      }
    } catch (e) {
      _ok = false;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _ask() async {
    try {
      await _hn.invokeMethod<bool>('requestCallLogPermission');
    } catch (e) {}
    await _load();
  }

  bool _isSpam(CallItem c) =>
      store.findBlocked(c.number) != null ||
      c.number.startsWith('140') ||
      c.number.startsWith('160');

  bool _isToday(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final today = _calls.where((c) => _isToday(c.date)).toList();
        final blockedToday =
            today.where((c) => store.findBlocked(c.number) != null).length;
        final alertsToday = today.where(_isSpam).length;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield, size: 48, color: Colors.white),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Call Guard',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Aap surakshit hain',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: HomeStat(
                        icon: Icons.block,
                        value: '$blockedToday',
                        label: 'Aaj blocked',
                        color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: HomeStat(
                        icon: Icons.warning_amber_rounded,
                        value: '$alertsToday',
                        label: 'Spam alerts',
                        color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  HomeBtn(
                      icon: Icons.search,
                      label: 'Check',
                      onTap: () => widget.onGo(1)),
                  HomeBtn(
                      icon: Icons.block,
                      label: 'Block',
                      onTap: () => widget.onGo(2)),
                  HomeBtn(
                      icon: Icons.call,
                      label: 'Call',
                      onTap: () => launchUrl(Uri.parse('tel:'))),
                  HomeBtn(
                      icon: Icons.settings,
                      label: 'Settings',
                      onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsPage()),
                          )),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text('Recent calls',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                      onPressed: _load, icon: const Icon(Icons.refresh)),
                ],
              ),
              if (!_ok)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                            'Recent calls dekhne ke liye call log ki permission do.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton(
                            onPressed: _ask,
                            child: const Text('Permission do')),
                      ],
                    ),
                  ),
                ),
              if (_ok && _busy)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_ok && !_busy && _calls.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Koi recent call nahi mili')),
                ),
              ...(_calls.take(8).map((c) {
                final spam = _isSpam(c);
                final label = store.findBlocked(c.number)?.label;
                final tag = label != null ? ' - $label' : '';
                return Card(
                  color: spam ? Colors.red.withOpacity(0.08) : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: spam
                          ? Colors.red.withOpacity(0.15)
                          : cs.primaryContainer,
                      child: Icon(
                          spam ? Icons.warning_amber_rounded : Icons.call,
                          color: spam ? Colors.red : cs.primary),
                    ),
                    title: Text(
                      c.name.isNotEmpty ? c.name : c.number,
                      style: TextStyle(
                          color: spam ? Colors.red : null,
                          fontWeight: spam ? FontWeight.bold : null),
                    ),
                    subtitle: Text(
                        spam ? 'SPAM$tag  |  ${c.number}' : c.number),
                    trailing: Text(timeAgo(c.date)),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => CallSheet(item: c),
                    ),
                  ),
                );
              })),
              const SizedBox(height: 16),
              const Center(
                  child: Text('Call Guard v2', style: TextStyle(fontSize: 12))),
            ],
          ),
        );
      },
    );
  }
}
