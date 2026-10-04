import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kHash = 'applock_hash';
const _kSalt = 'applock_salt';

String _hash(String salt, String pin) {
  List<int> h = utf8.encode(salt + ':' + pin);
  for (var i = 0; i < 2000; i++) {
    h = sha256.convert(h).bytes;
  }
  return base64.encode(h);
}

Future<bool> pinIsSet() async {
  final p = await SharedPreferences.getInstance();
  return (p.getString(_kHash) ?? '').isNotEmpty;
}

Future<bool> pinCheck(String pin) async {
  final p = await SharedPreferences.getInstance();
  final salt = p.getString(_kSalt) ?? '';
  final h = p.getString(_kHash) ?? '';
  if (h.isEmpty) return true;
  return _hash(salt, pin) == h;
}

Future<void> pinSave(String pin) async {
  final p = await SharedPreferences.getInstance();
  final salt = Random.secure().nextInt(1 << 30).toString() +
      DateTime.now().microsecondsSinceEpoch.toString();
  await p.setString(_kSalt, salt);
  await p.setString(_kHash, _hash(salt, pin));
}

Future<void> pinClear() async {
  final p = await SharedPreferences.getInstance();
  await p.remove(_kHash);
  await p.remove(_kSalt);
  await p.remove('applock_fails');
  await p.remove('applock_until');
}

class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _locked = false;
  DateTime? _paused;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _init() async {
    final set = await pinIsSet();
    if (!mounted) return;
    setState(() {
      _locked = set;
      _ready = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _paused = DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final p = _paused;
      _paused = null;
      if (p != null && DateTime.now().difference(p).inSeconds > 20) {
        _relock();
      }
    }
  }

  Future<void> _relock() async {
    final set = await pinIsSet();
    if (set && mounted) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ColoredBox(color: Colors.black);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: PinScreen(onUnlock: () => setState(() => _locked = false)),
          ),
      ],
    );
  }
}class PinScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const PinScreen({super.key, required this.onUnlock});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _err = '';
  int _fails = 0;
  int _until = 0;

  @override
  void initState() {
    super.initState();
    _loadFails();
  }

  Future<void> _loadFails() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fails = p.getInt('applock_fails') ?? 0;
      _until = p.getInt('applock_until') ?? 0;
    });
  }

  Future<void> _tap(String d) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < _until) {
      final s = ((_until - now) / 1000).ceil();
      setState(() => _err = '$s second baad try karo');
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _err = '';
    });
    if (_pin.length < 4) return;
    final ok = await pinCheck(_pin);
    if (!mounted) return;
    final p = await SharedPreferences.getInstance();
    if (ok) {
      await p.remove('applock_fails');
      await p.remove('applock_until');
      widget.onUnlock();
      return;
    }
    final f = _fails + 1;
    var until = 0;
    if (f >= 5) {
      until = DateTime.now().millisecondsSinceEpoch + 30000 * (f - 4);
    }
    await p.setInt('applock_fails', f);
    await p.setInt('applock_until', until);
    if (!mounted) return;
    setState(() {
      _fails = f;
      _until = until;
      _pin = '';
      _err = f >= 5 ? 'Bahut galat koshish, kuch der ruko' : 'Galat PIN';
    });
  }

  void _del() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Widget _key(String d) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: 64,
          child: FilledButton.tonal(
            onPressed: () => _tap(d),
            child: Text(d, style: const TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }

  Widget _row(List<String> ds) {
    return Row(children: ds.map(_key).toList());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, size: 56, color: cs.primary),
              const SizedBox(height: 12),
              const Text('Call Guard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('PIN daalo'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? cs.primary : Colors.transparent,
                      border: Border.all(color: cs.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 22,
                child: Text(_err, style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 10),
              _row(['1', '2', '3']),
              _row(['4', '5', '6']),
              _row(['7', '8', '9']),
              Row(
                children: [
                  const Expanded(child: SizedBox()),
                  _key('0'),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: SizedBox(
                        height: 64,
                        child: TextButton(
                          onPressed: _del,
                          child: const Icon(Icons.backspace_outlined),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showPinSetup(BuildContext context) async {
  final isSet = await pinIsSet();
  if (!context.mounted) return;
  final c0 = TextEditingController();
  final c1 = TextEditingController();
  final c2 = TextEditingController();
  String err = '';
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        InputDecoration dec(String t) =>
            InputDecoration(labelText: t, counterText: '');
        return AlertDialog(
          title: Text(isSet ? 'PIN badlo ya hatao' : 'App lock PIN lagao'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSet)
                TextField(
                  controller: c0,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: dec('Abhi ka PIN'),
                ),
              TextField(
                controller: c1,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: dec('Naya 4 digit PIN'),
              ),
              TextField(
                controller: c2,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: dec('Naya PIN dobara'),
              ),
              if (err.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(err, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            if (isSet)
              TextButton(
                onPressed: () async {
                  if (!await pinCheck(c0.text)) {
                    setD(() => err = 'Abhi ka PIN galat hai');
                    return;
                  }
                  await pinClear();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('PIN hatao'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (isSet && !await pinCheck(c0.text)) {
                  setD(() => err = 'Abhi ka PIN galat hai');
                  return;
                }
                if (!RegExp(r'^\d{4}$').hasMatch(c1.text)) {
                  setD(() => err = 'PIN 4 digit ka hona chahiye');
                  return;
                }
                if (c1.text != c2.text) {
                  setD(() => err = 'Dono PIN alag hain');
                  return;
                }
                await pinSave(c1.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}
