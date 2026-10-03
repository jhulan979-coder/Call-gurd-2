import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sn = MethodChannel('callguard/native');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final Map<String, bool> _v = {
    'autoBlock': true,
    'announce': true,
    'spamVoice': true,
    'flip': true,
    'infoPopup': true,
    'blockNotif': true,
  };
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _checkDefault();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _checkDefault();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      for (final k in _v.keys.toList()) {
        _v[k] = p.getBool(k) ?? true;
      }
    });
  }

  Future<void> _checkDefault() async {
    bool d = false;
    try {
      d = await _sn.invokeMethod<bool>('isDefaultDialer') ?? false;
    } catch (_) {}
    if (mounted) setState(() => _isDefault = d);
  }

  Future<void> _makeDefault() async {
    try {
      await _sn.invokeMethod<bool>('requestDialerRole');
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
    _checkDefault();
  }

  Future<void> _set(String k, bool x) async {
    setState(() => _v[k] = x);
    final p = await SharedPreferences.getInstance();
    await p.setBool(k, x);
  }

  Widget _sw(String k, String title, String sub) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(sub),
      value: _v[k] ?? true,
      onChanged: (x) => _set(k, x),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_isDefault ? Colors.green : Colors.orange)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_isDefault ? Icons.check_circle : Icons.warning_amber,
                        color: _isDefault ? Colors.green : Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isDefault
                            ? 'Call Guard default Phone app hai'
                            : 'Call Guard default Phone app nahi hai',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Naam bolna, flip to silence aur Call Guard ki call screen tabhi chalti hain jab ye default ho.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                if (!_isDefault) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _makeDefault,
                    icon: const Icon(Icons.phone_in_talk),
                    label: const Text('Default Phone app banao'),
                  ),
                ],
              ],
            ),
          ),
          _sw('autoBlock', 'Auto call blocking',
              'Block list wale numbers ki call apne aap reject'),
          _sw('announce', 'Naam bolna',
              'Call aane par naam ya Unknown number bolna'),
          _sw('spamVoice', 'Spam caller awaaz',
              '140 ya 160 wale numbers par Spam caller bolna'),
          _sw('flip', 'Flip to silence',
              'Ring ke dauran phone ulta karne par ringtone band'),
          _sw('infoPopup', 'Unknown caller ka chhota popup',
              'Call aane par Call Guard ka notification'),
          _sw('blockNotif', 'Block hui call ka notification',
              'Call reject hone par notification'),
        ],
      ),
    );
  }
}
