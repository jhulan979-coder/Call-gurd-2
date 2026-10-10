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
        title: Row(
          children: [
            const Icon(Icons.shield, color: kSaffron),
            const SizedBox(width: 8),
            const Text('Call Guard',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
          padding: const EdgeInsets.symmet
