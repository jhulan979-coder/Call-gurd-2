import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _crCh = MethodChannel('callguard/native');

class CallReportTile extends StatelessWidget {
  const CallReportTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.fact_check_outlined),
      title: const Text('Pichli calls ka hisaab'),
      subtitle: const Text('Call Guard ne har call par kya kiya'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CallReportPage()),
      ),
    );
  }
}

class CallReportPage extends StatefulWidget {
  const CallReportPage({super.key});

  @override
  State<CallReportPage> createState() => _CallReportPageState();
}

class _CallReportPageState extends State<CallReportPage> {
  String _log = '';
  bool _isDefault = false;
  bool _spamAnswer = false;
  bool _assistant = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    bool d = false;
    try {
      d = await _crCh.invokeMethod<bool>('isDefaultDialer') ?? false;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _log = p.getString('cg_log') ?? '';
      _spamAnswer = p.getBool('spamAnswer') ?? false;
      _assistant = p.getBool('assistant') ?? false;
      _isDefault = d;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('cg_log');
    await _load();
  }

  Widget _row(String t, bool v) {
    return ListTile(
      dense: true,
      leading: Icon(v ? Icons.check_circle : Icons.cancel,
          color: v ? Colors.green : Colors.red),
      title: Text(t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = _log.isEmpty ? <String>[] : _log.split('\n').reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pichli calls ka hisaab'),
        actions: [
         IconButton(
            tooltip: 'Report copy karo',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                  text:
                      'Pehredaar log\nDefault: $_isDefault\nSpamAnswer: $_spamAnswer\nAssistant: $_assistant\n\n$_log'));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report copy ho gayi')));
              }
            },
            icon: const Icon(Icons.copy),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _clear, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _row('Call Guard default Phone app hai', _isDefault),
                _row('Spam call apne aap uthao: on', _spamAnswer),
                _row('AI assistant: on', _assistant),
                const Divider(),
                if (lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'Abhi koi record nahi. Kisi call ke baad dobara kholo. INCALL wali lines tabhi aati hain jab Call Guard default Phone app ho.'),
                  )
                else
                  SelectableText(
                    lines.join('\n'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
              ],
            ),
    );
  }
}
