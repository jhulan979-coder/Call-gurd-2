import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _defaultLink =
    'https://play.google.com/store/apps/details?id=com.jhulan.callguard';

class InviteCard extends StatelessWidget {
  const InviteCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.group_add, color: cs.primary),
        ),
        title: const Text('Dost ko bulao'),
        subtitle: const Text('WhatsApp ya SMS se Call Guard bhejo'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InvitePage()),
        ),
      ),
    );
  }
}

class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  final _link = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('invite_link') ?? '';
    if (mounted) setState(() => _link.text = s);
  }

  Future<void> _save(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('invite_link', v.trim());
    if (mounted) setState(() {});
  }

  String _msg() {
    final l = _link.text.trim();
    final link = l.isEmpty ? _defaultLink : l;
    return 'Call Guard try karo: ye spam aur telemarketing calls block karta hai, '
            'call aane par naam bolta hai aur scam message check karta hai.\n'
            'Download: ' +
        link;
  }

  void _toast(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _open(Uri u, String fail) async {
    bool ok = false;
    try {
      ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) _toast(fail);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final msg = _msg();
    return Scaffold(
      appBar: AppBar(title: const Text('Dost ko bulao')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(msg),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _link,
            onChanged: _save,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Download link (khali chhodo to Play Store ka)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Play Store par app aane tak yahan apni APK ka Google Drive link paste karo.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _open(
              Uri.parse('https://wa.me/?text=' + Uri.encodeComponent(msg)),
              'WhatsApp nahi khul paaya',
            ),
            icon: const Icon(Icons.chat),
            label: const Text('WhatsApp se bhejo'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => _open(
              Uri.parse('sms:?body=' + Uri.encodeComponent(msg)),
              'Messages app nahi khul paaya',
            ),
            icon: const Icon(Icons.sms_outlined),
            label: const Text('SMS se bhejo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: msg));
              if (mounted) _toast('Message copy ho gaya');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Message copy karo'),
          ),
        ],
      ),
    );
  }
}
