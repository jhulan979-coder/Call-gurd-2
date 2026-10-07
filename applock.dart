import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kHash = 'applock_hash';
const _kSalt = 'applock_salt';
const _kBio = 'applock_bio';

final LocalAuthentication _auth = LocalAuthentication();

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
  await p.remove(_kBio);
  await p.remove('applock_fails');
  await p.remove('applock_until');
}

Future<bool> bioEnabled() async {
  final p = await SharedPreferences.getInstance();
  return p.getBool(_kBio) ?? false;
}

Future<void> setBio(bool v) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kBio, v);
}

Future<bool> bioAvailable() async {
  try {
    final can = await _auth.canCheckBiometrics;
    if (!can) return false;
    final list = await _auth.getAvailableBiometrics();
    return list.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<bool> bioAsk(String reason, {bool deviceCredential = false}) async {
  try {
    return await _auth.authenticate(
      localizedReason: reason,
      options: AuthenticationOptions(
        biometricOnly: !deviceCredential,
        stickyAuth: true,
      ),
    );
  } catch (_) {
    return false;
  }
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
  bool _bioOn = false;

  @override
  void initState() {
    super.initState();
    _loadFails();
    _initBio();
  }

  Future<void> _initBio() async {
    final on = await bioEnabled();
    if (!mounted) return;
    setState(() => _bioOn = on);
    if (on) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _tryBio();
    }
  }

  Future<void> _tryBio() async {
    final ok = await bioAsk('Call Guard kholne ke liye fingerprint do');
    if (ok && mounted) widget.onUnlock();
  }

  Future<void> _forgot() async {
    final ok = await bioAsk(
        'Apne phone ka PIN, pattern ya fingerprint do',
        deviceCredential: true);
    if (ok) {
      await pinClear();
      if (mounted) widget.onUnlock();
    } else if (mounted) {
      setState(() => _err = 'Pehchan nahi hui');
    }
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

  Widget _cell(Widget child) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(height: 64, child: child),
      ),
    );
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
                  _bioOn
                      ? _cell(TextButton(
                          onPressed: _tryBio,
                          child: const Icon(Icons.fingerprint, size: 34),
                        ))
                      : const Expanded(child: SizedBox()),
                  _key('0'),
                  _cell(TextButton(
                    onPressed: _del,
                    child: const Icon(Icons.backspace_outlined),
                  )),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _forgot,
                child: const Text('PIN bhool gaye?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _askPin(BuildContext context, String title) async {
  final c = TextEditingController();
  String err = '';
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: c,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration:
                  const InputDecoration(labelText: 'PIN', counterText: ''),
            ),
            if (err.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(err, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await pinCheck(c.text);
              if (!ctx.mounted) return;
              if (ok) {
                Navigator.pop(ctx, c.text);
              } else {
                setD(() => err = 'Galat PIN');
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> _newPinDialog(BuildContext context) async {
  final c1 = TextEditingController();
  final c2 = TextEditingController();
  String err = '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Naya 4 digit PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: c1,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration:
                  const InputDecoration(labelText: 'PIN', counterText: ''),
            ),
            TextField(
              controller: c2,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                  labelText: 'PIN dobara', counterText: ''),
            ),
            if (err.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(err, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!RegExp(r'^\d{4}$').hasMatch(c1.text)) {
                setD(() => err = 'PIN 4 digit ka hona chahiye');
                return;
              }
              if (c1.text != c2.text) {
                setD(() => err = 'Dono PIN alag hain');
                return;
              }
              await pinSave(c1.text);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({super.key});

  @override
  State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  bool _loading = true;
  bool _set = false;
  bool _bio = false;
  bool _avail = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await pinIsSet();
    final b = await bioEnabled();
    final a = await bioAvailable();
    if (!mounted) return;
    setState(() {
      _set = s;
      _bio = b && s;
      _avail = a;
      _loading = false;
    });
  }

  void _toast(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _turnOn() async {
    final ok = await _newPinDialog(context);
    await _load();
    if (ok && mounted) _toast('App lock chalu ho gaya');
  }

  Future<void> _change() async {
    final p = await _askPin(context, 'Abhi ka PIN');
    if (p == null || !mounted) return;
    final ok = await _newPinDialog(context);
    if (ok && mounted) _toast('PIN badal gaya');
  }

  Future<void> _toggleBio(bool v) async {
    if (v) {
      final ok = await bioAsk('Fingerprint chalu karne ke liye pehchano');
      if (ok) {
        await setBio(true);
      } else if (mounted) {
        _toast('Fingerprint pehchani nahi gayi');
      }
    } else {
      await setBio(false);
    }
    await _load();
  }

  Future<void> _remove() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('App lock hatana hai?'),
        content: const Text(
            'Iske baad Call Guard bina PIN ke khulegi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    bool verified = false;
    if (_bio && _avail) {
      verified = await bioAsk('Lock hatane ke liye fingerprint do');
    }
    if (!verified && mounted) {
      final p = await _askPin(context, 'Lock hatane ke liye PIN daalo');
      verified = p != null;
    }
    if (verified) {
      await pinClear();
      await _load();
      if (mounted) _toast('App lock hata diya');
    }
  }

  Future<void> _forgot() async {
    final ok = await bioAsk(
        'Apne phone ka PIN, pattern ya fingerprint do',
        deviceCredential: true);
    if (ok) {
      await pinClear();
      await _load();
      if (mounted) _toast('App lock hata diya');
    } else if (mounted) {
      _toast('Pehchan nahi hui');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App lock')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (_set ? Colors.green : Colors.orange)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(_set ? Icons.lock : Icons.lock_open,
                          color: _set ? Colors.green : Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _set ? 'App lock chalu hai' : 'App lock band hai',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_set) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      onPressed: _turnOn,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('PIN lagao'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        '4 digit PIN lagane ke baad fingerprint se bhi khol sakte ho.'),
                  ),
                ],
                if (_set) ...[
                  SwitchListTile(
                    title: const Text('Fingerprint se kholo'),
                    subtitle: Text(_avail
                        ? 'PIN ki jagah ungli se'
                        : 'Is phone me fingerprint set nahi hai'),
                    value: _bio,
                    onChanged: _avail ? _toggleBio : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: const Text('PIN badlo'),
                    onTap: _change,
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('PIN bhool gaye?'),
                    subtitle: const Text(
                        'Phone ke PIN ya fingerprint se lock hatao'),
                    onTap: _forgot,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock_open, color: Colors.red),
                    title: const Text('App lock hatao',
                        style: TextStyle(color: Colors.red)),
                    onTap: _remove,
                  ),
                ],
              ],
            ),
    );
  }
}

Future<void> showPinSetup(BuildContext context) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AppLockSettingsPage()),
  );
}
