import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Map<String, bool> _v = {
    'autoBlock': true,
    'announce': true,
    'spamVoice': true,
    'flip': true,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      for (final k in _v.keys.toList()) {
        _v[k] = p.getBool(k) ?? true;
      }
    });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sw('autoBlock', 'Auto call blocking',
              'Block list wale numbers ki call apne aap reject'),
          _sw('announce', 'Naam bolna',
              'Call aane par naam ya Unknown number bolna'),
          _sw('spamVoice', 'Spam caller awaaz',
              '140 ya 160 wale numbers par Spam caller bolna'),
          _sw('flip', 'Flip to silence',
              'Ring ke dauran phone ulta karne par ringtone band'),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.phone_android),
            title: Text('Default Phone app'),
            subtitle: Text(
                'Phone Settings > Apps > Default apps > Phone app > Call Guard. Naam bolna aur flip isi ke baad chalte hain.'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Call Guard v2'),
          ),
        ],
      ),
    );
  }
}
