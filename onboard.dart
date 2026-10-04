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
  int _page = 0;
  bool _logOk = false;
  bool _notifOk = false;
  bool _isDefault = false;

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

  Future<void> _refresh() async {
    bool l = false;
    bool d = false;
    try {
      l = await _ob.invokeMethod<bool>('hasCallLogPermission') ?? false;
    } catch (_) {}
    try {
      d = await _ob.invokeMethod<bool>('isDefaultDialer') ?? false;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _logOk = l;
        _isDefault = d;
      });
    }
  }

  Future<void> _askLog() async {
    try {
      await _ob.invokeMethod<bool>('requestCallLogPermission');
    } catch (_) {}
    await _refresh();
  }

  Future<void> _askNotif() async {
    try {
      final ok = await _ob.invokeMethod<bool>('requestNotificationPermission') ??
          false;
      if (mounted) setState(() => _notifOk = ok);
    } catch (_) {}
  }

  Future<void> _askDefault() async {
    try {
      await _ob.invokeMethod<bool>('requestDialerRole');
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
    await _refresh();
  }

  void _next() {
    if (_page < 3) {
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
        _title('Call Guard me aapka swagat hai'),
        const SizedBox(height: 16),
        _bullet(Icons.block, 'Spam aur telemarketing calls pehchanta aur block karta hai'),
        _bullet(Icons.record_voice_over, 'Call aane par naam ya Unknown number bolta hai'),
        _bullet(Icons.mark_email_unread_outlined, 'Shak wale message ya link ko AI se check karta hai'),
        _bullet(Icons.phone_in_talk, 'Apni call screen se call uthao, mute karo, speaker lagao'),
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
        const Text('Call Guard ko in cheezon ki zaroorat padti hai:'),
        const SizedBox(height: 8),
        _bullet(Icons.call_log_outlined == null ? Icons.call : Icons.history,
            'Call log: recent calls dikhane, spam pehchanne aur block hui calls ginne ke liye'),
        _bullet(Icons.contacts_outlined,
            'Contacts: call karne wale ka naam dikhane ke liye'),
        _bullet(Icons.phone_in_talk,
            'Phone aur calls: call uthane, kaatne aur call screen dikhane ke liye'),
        _bullet(Icons.notifications_outlined,
            'Notifications: call aur block ki jaankari dene ke liye'),
        _bullet(Icons.mic_none,
            'Microphone: sirf AI me bolkar poochhne ke liye (aap chaho tab)'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
              'Ye saara data sirf aapke phone me rehta hai. Hum koi server nahi chalate. '
              'Sirf jab aap "AI se poochho" dabate ho, scam checker chalate ho ya online state switch on karte ho, '
              'tab number ya message aapki apni API key se Google Gemini ko jata hai.'),
        ),
        const SizedBox(height: 8),
        const Text(
            'Aage badhne par hi permission maangi jayegi. Chaho to "Abhi nahi" dabao.',
            style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _perm(IconData icon, String title, String sub, bool ok,
      VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: ok ? Colors.green : cs.primary),
        title: Text(title),
        subtitle: Text(sub),
        trailing: ok
            ? const Icon(Icons.check_circle, color: Colors.green)
            : FilledButton(onPressed: onTap, child: const Text('Do')),
      ),
    );
  }

  Widget _perms() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_user_outlined, size: 56, color: cs.primary),
        const SizedBox(height: 12),
        _title('Permissions do'),
        const SizedBox(height: 12),
        _perm(Icons.history, 'Call log aur Contacts',
            'Recent calls aur naam dikhane ke liye', _logOk, _askLog),
        _perm(Icons.notifications_outlined, 'Notifications',
            'Call aur block ki jaankari', _notifOk, _askNotif),
        _perm(Icons.phone_in_talk, 'Default Phone app',
            'Naam bolna, flip to silence aur call screen ke liye', _isDefault,
            _askDefault),
        const SizedBox(height: 8),
        const Text(
            'Android "App was denied access" bataye to: Phone Settings > Apps > Call Guard > upar ke 3 dots > Allow restricted settings, phir yahan wapas aake dobara dabao.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
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
            'Spam call aane par Call Guard khud bata dega. AI ke liye Settings me apni Gemini API key daal sakte ho.',
            textAlign: TextAlign.center),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pages = <Widget>[_welcome(), _disclosure(), _perms(), _done()];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
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
                    child: Text(_page == 3
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
