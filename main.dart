import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'core.dart';
import 'tabs.dart';
import 'ai_tab.dart';
import 'calls_tab.dart';

const kSaffron = Color(0xFFFF9933);
const kCharcoal = Color(0xFF16191C);

ThemeData pehredaarTheme() {
  final base = ColorScheme.fromSeed(
      seedColor: kSaffron, brightness: Brightness.dark);
  final cs = base.copyWith(
    primary: kSaffron,
    onPrimary: const Color(0xFF1A1100),
    primaryContainer: const Color(0xFF3A2A14),
    onPrimaryContainer: const Color(0xFFFFD9A8),
    secondary: const Color(0xFFFFB866),
    surface: kCharcoal,
    onSurface: const Color(0xFFECEFF1),
    surfaceContainerLowest: const Color(0xFF101315),
    surfaceContainerLow: const Color(0xFF1C2024),
    surfaceContainer: const Color(0xFF23282D),
    surfaceContainerHigh: const Color(0xFF2B3035),
    surfaceContainerHighest: const Color(0xFF30363C),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: kCharcoal,
    appBarTheme: const AppBarTheme(
      backgroundColor: kCharcoal,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: Color(0xFF3A2A14),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kSaffron,
      foregroundColor: Color(0xFF1A1100),
    ),
  );
}

void main() => runApp(const CallGuardApp());

class CallGuardApp extends StatelessWidget {
  const CallGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Guard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: pehredaarTheme(),
      darkTheme: pehredaarTheme(),
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
        title: const Row(
          children: [
            Icon(Icons.shield, color: kSaffron),
            SizedBox(width: 8),
            Text('Call Guard', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
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
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => showDialPad(context),
              child: const Icon(Icons.dialpad),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.call_outlined), label: 'Calls'),
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
}

void showDialPad(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const DialPadSheet(),
  );
}

class DialPadSheet extends StatefulWidget {
  const DialPadSheet({super.key});

  @override
  State<DialPadSheet> createState() => _DialPadSheetState();
}

class _DialPadSheetState extends State<DialPadSheet> {
  String _num = '';

  void _add(String d) => setState(() => _num += d);

  void _back() {
    if (_num.isNotEmpty) {
      setState(() => _num = _num.substring(0, _num.length - 1));
    }
  }

  Future<void> _call() async {
    if (_num.isEmpty) return;
    await FlutterPhoneDirectCaller.callNumber(_num);
  }

  Widget _key(String d) {
    return Expanded(
      child: InkWell(
        onTap: () => _add(d),
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(d,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  Widget _row(List<String> d) {
    return Row(children: d.map((x) => _key(x)).toList());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _num.isEmpty ? 'Number daalo' : _num,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: _num.isEmpty ? cs.outline : null),
                ),
              ),
              IconButton(
                  onPressed: _back,
                  icon: const Icon(Icons.backspace_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          _row(['1', '2', '3']),
          _row(['4', '5', '6']),
          _row(['7', '8', '9']),
          _row(['*', '0', '#']),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _call,
            icon: const Icon(Icons.call),
            label: const Text('Call karo'),
            style: FilledButton.styleFrom(minimumSize: const Size(220, 54)),
          ),
        ],
      ),
    );
  }
}

class HomeStat extends StatelessWidget {
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
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
  List<CallItem> _contacts = [];
  bool _ok = true;
  bool _def = true;
  bool _busy = true;
  bool _cAsked = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final isDef =
          await _hn.invokeMethod<bool>('isDefaultDialer') ?? false;
      _def = isDef;
      final has = isDef &&
          (await _hn.invokeMethod<bool>('hasCallLogPermission') ?? false);
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
      } else {
        _calls = [];
      }
    } catch (e) {
      _ok = false;
    }
    await _loadContacts();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _loadContacts() async {
    try {
      final has =
          await _hn.invokeMethod<bool>('hasContactsPermission') ?? false;
      if (!has) return;
      final raw = await _hn.invokeMethod<List<dynamic>>('getContacts') ?? [];
      final seen = <String>{};
      final list = <CallItem>[];
      for (final r in raw) {
        final m = Map<String, dynamic>.from(r as Map);
        final n = last10((m['number'] ?? '') as String);
        if (n.length < 10 || seen.contains(n)) continue;
        seen.add(n);
        list.add(CallItem(n, (m['name'] ?? '') as String, 0, 0));
      }
      _contacts = list;
    } catch (e) {}
  }

  Future<void> _needContacts() async {
    if (_contacts.isNotEmpty || _cAsked) return;
    _cAsked = true;
    try {
      await _hn.invokeMethod<bool>('requestContactsPermission');
    } catch (e) {}
    await _loadContacts();
    if (mounted) setState(() {});
  }

  Future<void> _ask() async {
    try {
      final isDef = await _hn.invokeMethod<bool>('isDefaultDialer') ?? false;
      if (!isDef) {
        await _hn.invokeMethod<bool>('requestDialerRole');
      } else {
        await _hn.invokeMethod<bool>('requestCallLogPermission');
      }
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

  IconData _typeIcon(int t) {
    if (t == 1) return Icons.call_received;
    if (t == 2) return Icons.call_made;
    if (t == 3) return Icons.call_missed;
    if (t == 5 || t == 6) return Icons.block;
    return Icons.phone;
  }

  Color _typeColor(int t) {
    if (t == 3 || t == 5 || t == 6) return Colors.red;
    return Colors.green;
  }

  List<CallItem> _frequent() {
    final count = <String, int>{};
    final first = <String, CallItem>{};
    for (final c in _calls) {
      if (_isSpam(c)) continue;
      count[c.number] = (count[c.number] ?? 0) + 1;
      first.putIfAbsent(c.number, () => c);
    }
    final keys = count.keys.toList()
      ..sort((a, b) => count[b]!.compareTo(count[a]!));
    return keys.take(4).map((k) => first[k]!).toList();
  }

  Widget _hero(int blocked, int alerts) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B3035), Color(0xFF3A2A14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: kSaffron.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: kSaffron, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pehredaar chaukas hai',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Aaj $blocked block, $alerts spam alert',
                    style: const TextStyle(color: Color(0xFFFFD9A8))),
              ],
            ),
          ),
        ],
      ),
    );
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
        final q = _q.toLowerCase();
        final shown = _calls
            .where((c) =>
                q.isEmpty ||
                c.name.toLowerCase().contains(q) ||
                c.number.contains(q))
            .toList();
        final freq = q.isEmpty ? _frequent() : <CallItem>[];
        final callNums = shown.map((c) => c.number).toSet();
        final moreContacts = q.isEmpty
            ? <CallItem>[]
            : _contacts
                .where((c) =>
                    !callNums.contains(c.number) &&
                    (c.name.toLowerCase().contains(q) || c.number.contains(q)))
                .take(30)
                .toList();
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            children: [
              if (q.isEmpty) ...[
                _hero(blockedToday, alertsToday),
                const SizedBox(height: 12),
              ],
              TextField(
                onTap: _needContacts,
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Numbers, names search karo',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: cs.primaryContainer.withOpacity(0.4),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              if (freq.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: freq
                      .map((c) => InkWell(
                            onTap: () =>
                                FlutterPhoneDirectCaller.callNumber(c.number),
                            child: SizedBox(
                              width: 76,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: cs.primaryContainer,
                                    child: Text(
                                      (c.name.isNotEmpty
                                              ? c.name.substring(0, 1)
                                              : '#')
                                          .toUpperCase(),
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: cs.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    c.name.isNotEmpty
                                        ? c.name.split(' ').first
                                        : c.number,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
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
                        Text(
                            _def
                                ? 'Recent calls dekhne ke liye call log ki permission do.'
                                : 'Recent calls dekhne ke liye Call Guard ko default Phone app banao.',
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
              if (_ok && !_busy && shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Koi call nahi mili')),
                ),
              if (moreContacts.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 14, 0, 4),
                  child: Text('Contacts',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                ...moreContacts.map((c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                            (c.name.isNotEmpty ? c.name.substring(0, 1) : '#')
                                .toUpperCase(),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cs.primary)),
                      ),
                      title: Text(c.name.isNotEmpty ? c.name : c.number,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(c.number),
                      trailing: IconButton(
                        icon: Icon(Icons.call, color: cs.primary),
                        onPressed: () =>
                            FlutterPhoneDirectCaller.callNumber(c.number),
                      ),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CallSheet(item: c),
                        );
                      },
                    )),
              ],
              ...(shown.take(60).map((c) {
                final spam = _isSpam(c);
                final label = store.findBlocked(c.number)?.label;
                final tag = label != null ? ' - $label' : '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        spam ? Colors.red.withOpacity(0.15) : cs.primaryContainer,
                    child: spam
                        ? const Icon(Icons.warning_amber_rounded,
                            color: Colors.red)
                        : Text(
                            (c.name.isNotEmpty ? c.name.substring(0, 1) : '#')
                                .toUpperCase(),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cs.primary)),
                  ),
                  title: Text(
                    c.name.isNotEmpty ? c.name : c.number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 17,
                        color: spam ? Colors.red : null,
                        fontWeight: spam ? FontWeight.bold : FontWeight.w500),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(_typeIcon(c.type),
                          size: 16, color: _typeColor(c.type)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          spam
                              ? 'SPAM$tag  |  ${timeAgo(c.date)}'
                              : timeAgo(c.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: spam ? Colors.red : null),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.call, color: cs.primary),
                    onPressed: () =>
                        FlutterPhoneDirectCaller.callNumber(c.number),
                  ),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CallSheet(item: c),
                  ),
                );
              })),
            ],
          ),
        );
      },
    );
  }
}
