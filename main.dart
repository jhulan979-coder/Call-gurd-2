import 'package:flutter/material.dart';
import 'core.dart';
import 'tabs.dart';
import 'ai_tab.dart';
import 'settings_page.dart';

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
