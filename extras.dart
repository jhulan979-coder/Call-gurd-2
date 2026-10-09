import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'core.dart';

const _xn = MethodChannel('callguard/native');

class VoiceDialPage extends StatefulWidget {
  const VoiceDialPage({super.key});

  @override
  State<VoiceDialPage> createState() => _VoiceDialPageState();
}

class _VoiceDialPageState extends State<VoiceDialPage> {
  final SpeechToText _stt = SpeechToText();
  final _typed = TextEditingController();
  bool _ready = false;
  bool _listening = false;
  String _lang = 'en-IN';
  String _heard = '';
  String? _msg;
  List<Map<String, String>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _ready = await _stt.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _listening = false;
              _msg = 'Mic error: ${e.errorMsg}';
            });
          }
        },
      );
    } catch (_) {
      _ready = false;
    }
    await _loadContacts();
    if (mounted) setState(() {});
  }

  Future<void> _loadContacts() async {
    try {
      var has = await _xn.invokeMethod<bool>('hasContactsPermission') ?? false;
      if (!has) {
        await _xn.invokeMethod<bool>('requestContactsPermission');
        has = await _xn.invokeMethod<bool>('hasContactsPermission') ?? false;
      }
      if (!has) {
        _msg = 'Contacts ki permission do, phir ye page dobara kholo.';
        return;
      }
      final raw = await _xn.invokeMethod<List<dynamic>>('getContacts') ?? [];
      final seen = <String>{};
      final list = <Map<String, String>>[];
      for (final r in raw) {
        final m = Map<String, dynamic>.from(r as Map);
        final n = last10((m['number'] ?? '') as String);
        final name = (m['name'] ?? '') as String;
        if (n.length < 10 || name.isEmpty || seen.contains(n)) continue;
        seen.add(n);
        list.add({'name': name, 'number': n});
      }
      _contacts = list;
    } catch (e) {
      _msg = 'Contacts nahi khul paaye: $e';
    }
  }

  String _extractName(String s) {
    var t = s.toLowerCase().trim();
    for (final w in const [
      'ko call lagao',
      'ko call karo',
      'ko call kar do',
      'ko phone lagao',
      'ko phone karo',
      'call lagao',
      'call karo',
      'call kar do',
      'phone lagao',
      'phone karo',
      'ko call',
      'call',
      'phone',
      'lagao',
      'karo',
      'kar do',
      'please',
    ]) {
      t = t.replaceAll(w, ' ');
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<Map<String, String>> _match(String name) {
    if (name.isEmpty) return [];
    final q = name.toLowerCase();
    final exact =
        _contacts.where((c) => c['name']!.toLowerCase() == q).toList();
    if (exact.isNotEmpty) return exact;
    final part =
        _contacts.where((c) => c['name']!.toLowerCase().contains(q)).toList();
    if (part.isNotEmpty) return part;
    for (final w in q.split(' ')) {
      if (w.length < 3) continue;
      final hit =
          _contacts.where((c) => c['name']!.toLowerCase().contains(w)).toList();
      if (hit.isNotEmpty) return hit;
    }
    return [];
  }

  void _handle(String text) {
    final name = _extractName(text);
    final m = _match(name);
    if (m.isEmpty) {
      setState(() => _msg = '"$name" naam ka contact nahi mila');
      return;
    }
    if (m.length == 1) {
      _confirm(m.first);
    } else {
      _pick(m);
    }
  }

  Future<void> _confirm(Map<String, String> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c['name'] ?? ''),
        content: Text(c['number'] ?? ''),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Call karo')),
        ],
      ),
    );
    if (ok == true) {
      await FlutterPhoneDirectCaller.callNumber(c['number'] ?? '');
    }
  }

  void _pick(List<Map<String, String>> list) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        children: [
          for (final c in list.take(8))
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(c['name'] ?? ''),
              subtitle: Text(c['number'] ?? ''),
              onTap: () {
                Navigator.pop(ctx);
                _confirm(c);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _listen() async {
    if (!_ready) {
      setState(() => _msg =
          'Mic ya speech service available nahi hai. Neeche naam likh kar bhi chal sakta hai.');
      return;
    }
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _heard = '';
      _msg = null;
    });
    await _stt.listen(
      localeId: _lang,
      onResult: (r) {
        if (!mounted) return;
        setState(() => _heard = r.recognizedWords);
        if (r.finalResult) {
          setState(() => _listening = false);
          _handle(r.recognizedWords);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bol ke call lagao')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('English'),
                selected: _lang == 'en-IN',
                onSelected: (_) => setState(() => _lang = 'en-IN'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Hindi'),
                selected: _lang == 'hi-IN',
                onSelected: (_) => setState(() => _lang = 'hi-IN'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
              'Contacts ke naam English me hain to English chuno. Hindi me naam Devanagari me aata hai.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _listen,
            icon: Icon(_listening ? Icons.stop : Icons.mic),
            label: Text(_listening ? 'Sun raha hun...' : 'Mic dabao aur bolo'),
          ),
          const SizedBox(height: 8),
          const Text('Jaise: "Ravi ko call lagao"'),
          if (_heard.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Suna: $_heard'),
            ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_msg!),
            ),
          const SizedBox(height: 24),
          TextField(
            controller: _typed,
            decoration: const InputDecoration(
              hintText: 'Ya naam likho',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (v) => _handle(v),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _handle(_typed.text),
            child: const Text('Dhundo'),
          ),
        ],
      ),
    );
  }
}

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _paste = TextEditingController();
  int _count = 0;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<List<dynamic>> _read() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final s = p.getString('blocked_v2');
    if (s == null || s.isEmpty) return [];
    try {
      final d = jsonDecode(s);
      if (d is List) return d;
    } catch (_) {}
    return [];
  }

  Future<void> _refresh() async {
    final l = await _read();
    if (mounted) setState(() => _count = l.length);
  }

  Future<void> _copy() async {
    final l = await _read();
    if (l.isEmpty) {
      setState(() => _msg = 'Block list khali hai');
      return;
    }
    await Clipboard.setData(
        ClipboardData(text: 'CALLGUARD_BACKUP\n' + jsonEncode(l)));
    if (mounted) {
      setState(() => _msg =
          '${l.length} numbers copy ho gaye. Kisi chat ya notes me paste karke save kar lo.');
    }
  }

  Future<void> _restore() async {
    var t = _paste.text.trim();
    if (t.startsWith('CALLGUARD_BACKUP')) {
      t = t.substring('CALLGUARD_BACKUP'.length).trim();
    }
    try {
      final d = jsonDecode(t);
      if (d is! List) throw Exception('list nahi');
      final cur = await _read();
      final seen = <String>{};
      for (final o in cur) {
        if (o is Map) seen.add('${o['n']}');
      }
      var added = 0;
      for (final o in d) {
        if (o is Map && o['n'] != null && !seen.contains('${o['n']}')) {
          seen.add('${o['n']}');
          cur.add(o);
          added++;
        }
      }
      final p = await SharedPreferences.getInstance();
      await p.setString('blocked_v2', jsonEncode(cur));
      store.load();
      _paste.clear();
      await _refresh();
      if (mounted) {
        setState(() => _msg =
            '$added naye numbers jude. App band karke dobara kholo to list poori dikhegi.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _msg =
            'Ye backup sahi nahi lag raha. Pura copy kiya hua text paste karo.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Block list backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Abhi block list me $_count numbers hain.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy),
            label: const Text('Backup copy karo'),
          ),
          const SizedBox(height: 24),
          const Text('Restore: pehle backup wala text yahan paste karo'),
          const SizedBox(height: 8),
          TextField(
            controller: _paste,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'CALLGUARD_BACKUP ...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _restore,
            icon: const Icon(Icons.restore),
            label: const Text('Restore karo'),
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_msg!),
            ),
        ],
      ),
    );
  }
}
