import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool autoBlock = false, popup = true, smsSpam = true, autoReply = false;

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

  Future<void> _save(String k, bool v) async =>
      (await SharedPreferences.getInstance()).setBool(k, v);

  Widget _tile(String t, bool v, String k, void Function(bool) set) =>
      SwitchListTile(
        title: Text(t),
        value: v,
        onChanged: (x) {
          set(x);
          _save(k, x);
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(children: [
          _tile('Auto call blocking', autoBlock, 'autoBlock',
              (x) => setState(() => autoBlock = x)),
          _tile('Incoming call warning popup', popup, 'popup',
              (x) => setState(() => popup = x)),
          _tile('SMS spam detection', smsSpam, 'smsSpam',
              (x) => setState(() => smsSpam = x)),
          _tile('Auto SMS reply to blocked callers', autoReply, 'autoReply',
              (x) => setState(() => autoReply = x)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Dosto ko share karo'),
            onTap: () => Share.share(
              'Call Guard try karo: spam calls block karo aur unknown number check karo!\nDownload: APP_LINK_YAHAN',
            ),
          ),
        ]),
      );
}
