import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ob = MethodChannel('callguard/native');
const _kDone = 'onboard_done_v1';

class OnboardGate extends StatefulWidget {
  final Widget child;
  const OnboardGate({super.key, required this.child});

  @override
  State<OnboardGate> createState() => _OnboardGateState();
}

class _OnboardGateState extends State<OnboardGate> {
  bool _ready = false;
  bool _done = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _done = p.getBool(_kDone) ?? false;
      _ready = true;
    });
  }

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDone, true);
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const ColoredBox(color: Colors.black);
    if (_done) return widget.child;
    return OnboardScreen(onFinish: _finish);
  }
}

class OnboardScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardScreen({super.key, required this.onFinish});

  @override
  State<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends State<OnboardScreen>
    with WidgetsBindingObserver {
  static const int _last = 4;
  int _page = 0;
  bool _defOk = false;
  bool _logOk = false;
  bool _conOk = false;
  bool _notifOk = false;
  bool _smsOk = false;
  bool _ovOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<bool> _q(String m) async {
    try {
      return await _ob.invokeMethod<bool>(m) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refresh() async {
    final d = await _q('isDefaultDialer');
    final l = await _q('hasCallLogPermission');
    final c = await _q('hasContactsPermission');
    final s = await _q('hasSms');
    final o = await _q('canOverlay');
    if (mounted) {
      setState(() {
        _defOk = d;
        _logOk = l;
        _conOk = c;
        _smsOk = s;
        _ovOk = o;
      });
    }
  }

  Future<void> _ask(String m) async {
    try {
      await _ob.invokeMethod<bool>(m);
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
    await _refresh();
  }

  Future<void> _askNotif() async {
    try {
      final ok =
          await _ob.invokeMethod<bool>('requestNotificationPermission') ??
              false;
      if (mounted) setState(() => _notifOk = ok);
    } catch (_) {}
  }

  void _next() {
    if (_page < _last) {
      setState(() => _page++);
    } else {
      widget.onFinish();
    }
  }

  Widget _bullet(IconData i, String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(t)),
        ],
      ),
    );
  }

  Widget _title(String t) {
    return Text(t,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700));
  }

  Widget _welcome() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield, size: 72, color: cs.primary),
        const SizedBox(height: 16),
        _title('Pehredaar me aapka swagat hai'),
        const SizedBox(height: 16),
        _bullet(Icons.shield_outlined,
            'Har unknown call ka spam score, wajah aur salah dikhata hai'),
        _bullet(Icons.record_voice_over,
            'Call aane par naam ya Unknown number bolta hai'),
        _bullet(Icons.sms_outlined,
            'Miss call par (aapki marzi se) auto SMS bhejta hai'),
        _bullet(Icons.report_outlined,
            'Spam ki TRAI aur Chakshu par ek tap me shikayat'),
        _bullet(Icons.smart_toy_outlined,
            'AI se call ke baare me pucho (apni Gemini key se, optional)'),
      ],
    );
  }

  Widget _disclosure() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.privacy_tip_outlined, size: 56, color: cs.primary),
        const SizedBox(height: 12),
        _title('Aapka data aur permissions'),
        const SizedBox(height: 12),
        const Text('Pehredaar ko in cheezon ki zaroorat padti hai:'),
        const SizedBox(height: 8),
        _bullet(Icons.phone_in_talk,
            'Phone app banna: call uthane, kaatne, mute karne aur call screen dikhane ke liye'),
        _bullet(Icons.history,
            'Call log: recent calls dikhane, spam score banane aur history se call hatane ke liye. Ye tabhi padha jata hai jab Pehredaar aapka default Phone app ho'),
        _bullet(Icons.contacts_outlined,
            'Contacts: caller ka naam dikhane, search aur bol ke call lagane ke liye'),
        _bullet(Icons.sms_outlined,
            'SMS (sirf bhejna): agar aap "Miss call par auto SMS" on karo. Hum aapke SMS padhte nahi'),
        _bullet(Icons.layers_outlined,
            'Doosre apps ke upar dikhana: call ke dauran spam card ke liye'),
        _bullet(Icons.notifications_outlined,
            'Notifications: call, miss call aur summary ki jaankari ke liye'),
        _bullet(Icons.mic_none,
            'Microphone: sirf bol ke sawal ya call lagane ke liye. Calls record nahi hoti'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
              'Ye saara data sirf aapke phone me rehta hai. Hum koi server nahi chalate. '
              'Sirf jab aap AI chat, "AI se poochho" ya call ke baare me sawal use karo, ya online state switch on karo, '
              'tab number, aapka sawal ya recent calls ki chhoti list (naam ya number ke aakhri 4 digit, call ka type, samay) '
              'aapki apni API key se Google Gemini ko jati hai.'),
        ),
        const SizedBox(height: 8),
        const Text(
            'Aage badhne par hi permission maangi jayegi. Chaho to "Abhi nahi" dabao.',
            style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _perm(IconData icon, String title, String sub, bool ok,
      VoidCallback onTap,
      {bool enabled = true}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: ok ? Colors.green : cs.primary),
        title: Text(title),
        subtitle: Text(sub),
        trailing: ok
            ? const Icon(Icons.check_circle, color: Colors.green)
            : FilledButton(
                onPressed: enabled ? onTap : null,
                child: const Text('Do')),
      ),
    );
  }

  Widget _phonePage() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.phone_in_talk, size: 56, color: cs.primary),
        const SizedBox(height: 12),
        _title('Pehredaar ko Phone app banao'),
        const SizedBox(height: 8),
        const Text(
            'Spam rokne, call screen aur card ke liye Pehredaar ko default Phone app banana zaruri hai. Pehle ye karo, phir neeche ki permissions.'),
        const SizedBox(height: 12),
        _perm(Icons.phone_in_talk, 'Default Phone app',
            'Naam bolna, spam card aur call screen ke liye', _defOk,
            () => _ask('requestDialerRole')),
        _perm(Icons.history, 'Call log',
            'Recent calls aur spam score ke liye. Pehle upar wala step karo',
            _logOk, () => _ask('requestCallLogPermission'),
            enabled: _defOk),
        _perm(Icons.contacts_outlined, 'Contacts',
            'Naam dikhane aur search ke liye', _conOk,
            () => _ask('requestContactsPermission')),
        const SizedBox(height: 8),
        const Text(
            'Android "App was denied access" bataye to: Phone Settings > Apps > Pehredaar > upar ke 3 dots > Allow restricted settings, phir yahan wapas aake dobara dabao.',
            style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _extraPage() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.tune, size: 56, color: cs.primary),
        const SizedBox(height: 12),
        _title('Ye optional hain'),
        const SizedBox(height: 8),
        const Text(
            'Inke bina bhi app chalta hai. Jo features chahiye, unki permission do.'),
        const SizedBox(height: 12),
        _perm(Icons.notifications_outlined, 'Notifications',
            'Call, miss call aur summary ki jaankari', _notifOk, _askNotif),
        _perm(Icons.layers_outlined, 'Doosre apps ke upar dikhao',
            'Call ke dauran spam card dikhane ke liye', _ovOk,
            () => _ask('requestOverlay')),
        _perm(Icons.sms_outlined, 'SMS bhejna',
            'Miss call par auto SMS ke liye. Hum SMS padhte nahi', _smsOk,
            () => _ask('requestSms')),
        const SizedBox(height: 8),
        const Text('Ye sab baad me Settings se bhi ho sakta hai.',
            style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _done() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(Icons.check_circle, size: 88, color: cs.primary),
        const SizedBox(height: 16),
        _title('Sab taiyar hai'),
        const SizedBox(height: 12),
        const Text(
            'Spam call aane par Pehredaar khud bata dega. AI ke liye Settings me apni Gemini API key daal sakte ho (optional). Baaki sab bina key ke chalta hai.',
            textAlign: TextAlign.center),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pages = <Widget>[
      _welcome(),
      _disclosure(),
      _phonePage(),
      _extraPage(),
      _done(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _last + 1,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: pages[_page],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => setState(() => _page--),
                      child: const Text('Peeche'),
                    ),
                  const Spacer(),
                  if (_page == 1)
                    TextButton(
                      onPressed: widget.onFinish,
                      child: const Text('Abhi nahi'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_page == _last
                        ? 'Shuru karo'
                        : (_page == 1 ? 'Samajh gaya' : 'Aage')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
