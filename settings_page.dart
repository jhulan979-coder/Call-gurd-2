import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core.dart';
import 'lang.dart';
import 'recordings.dart';

const _sn = MethodChannel('callguard/native');

const _defaults = <String, bool>{
  'autoBlock': true,
  'announce': true,
  'spamVoice': true,
  'flip': true,
  'infoPopup': true,
  'blockNotif': true,
  'onlineCircle': true,
  'blockTele': false,
  'blockHidden': false,
  'blockIntl': false,
  'assistant': false,
  'autoSms': false,
};

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final Map<String, bool> _v = Map<String, bool>.from(_defaults);
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
      for (final k in _defaults.keys) {
        _v[k] = p.getBool(k) ?? _defaults[k]!;
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
    if (k == 'assistant' && x) {
      try {
        await _sn.invokeMethod<bool>('requestMic');
      } catch (_) {}
    }
  }

  String get _langName {
    final l = langNotifier.value;
    if (l == 'en') return 'English';
    if (l == 'or') return 'ଓଡ଼ିଆ (Odia)';
    return 'Hinglish';
  }

  Future<void> _pickLang() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Language / Bhasha'),
        children: [
          for (final e in const [
            ['hi', 'Hinglish'],
            ['en', 'English'],
            ['or', 'ଓଡ଼ିଆ (Odia)'],
          ])
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                await setLang(e[0]);
                if (mounted) setState(() {});
              },
              child: Text(e[1]),
            ),
        ],
      ),
    );
  }

  Future<void> _editKey() async {
    final c = TextEditingController(text: store.apiKey);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini API key'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            hintText: 'API key',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      store.setKey(c.text.trim());
      if (mounted) setState(() {});
    }
  }

  String get _keyText {
    final k = store.apiKey;
    if (k.isEmpty) return 'Daali nahi gayi';
    final tail = k.length > 4 ? k.substring(k.length - 4) : k;
    return '••••' + tail;
  }

  Widget _head(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        t,
        style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _sw(String k, String title, String sub, {bool enabled = true}) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(sub),
      value: _v[k] ?? false,
      onChanged: enabled ? (x) => _set(k, x) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blockOn = _v['autoBlock'] ?? true;
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
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language / Bhasha'),
            subtitle: Text(_langName),
            onTap: _pickLang,
          ),
          _head('Call blocking'),
          _sw('autoBlock', 'Auto call blocking',
              'Block list wale numbers ki call apne aap reject'),
          _sw('blockTele', 'Telemarketing numbers block karo',
              '140 aur 160 se shuru hone wale numbers. Kuch bank bhi 160 se call karte hain',
              enabled: blockOn),
          _sw('blockHidden', 'Chhupe hue number block karo',
              'Jinka number dikhta nahi (hidden / private)',
              enabled: blockOn),
          _sw('blockIntl', 'Videsh ke numbers block karo',
              '+91 ke alawa kisi bhi desh ka number',
              enabled: blockOn),
          _sw('blockNotif', 'Block hui call ka notification',
              'Call reject hone par notification'),
          _head('Awaaz aur ring'),
          _sw('announce', 'Naam bolna',
              'Call aane par naam ya Unknown number bolna'),
          _sw('spamVoice', 'Spam caller awaaz',
              '140 ya 160 wale numbers par Spam caller bolna'),
          _sw('flip', 'Flip to silence',
              'Ring ke dauran phone ulta karne par ringtone band'),
          _sw('onlineCircle', 'Unknown number ka state (online AI)',
              'Gemini API key se. Number Google ko jata hai'),
          _head('Notification'),
          _sw('infoPopup', 'Unknown caller ka chhota popup',
              'Call aane par Call Guard ka notification'),
          _head('AI assistant'),
          _sw('spamAnswer', 'Spam call apne aap uthao', 'Spam number ki call khud uthegi'),
          _sw('assistant', 'AI assistant', 'Uthayi hui call par assistant bolega aur recording karega'),
           ListTile(
            leading: const Icon(Icons.mic_none),
            title: const Text('AI assistant recordings'),
            subtitle: const Text('Suno ya delete karo'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecordingsPage())),
          ),
          _head('AI'),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Gemini API key'),
            subtitle: Text(_keyText),
            onTap: _editKey,
          ),
          _head('About'),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy'),
            subtitle: Text(
                'Block list aur history sirf aapke phone me rehti hai. AI se poochho ya state wale switch par number Google Gemini ko jata hai.'),
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
