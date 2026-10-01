import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'calls_tab.dart';
import 'core.dart';

const _native = MethodChannel('callguard/native');

class SmsMsg {
  final String address;
  final String body;
  final int date;
  SmsMsg(this.address, this.body, this.date);
}

class SmsVerdict {
  final String label;
  final Color color;
  final List<String> reasons;
  SmsVerdict(this.label, this.color, this.reasons);
}

String maskDigits(String s) => s.replaceAll(RegExp(r'\d{4,}'), '••••');

bool isNumericSender(String a) =>
    RegExp(r'^\+?\d{10,13}$').hasMatch(a.replaceAll(' ', ''));

SmsVerdict judgeSms(SmsMsg m) {
  final body = m.body.toLowerCase();
  final hasCode = RegExp(r'\b\d{4,8}\b').hasMatch(body);
  if (hasCode &&
      (body.contains('otp') ||
          body.contains('verification') ||
          body.contains('one time'))) {
    return SmsVerdict(
        'OTP', Colors.blue, ['Ye OTP wala msg hai. Ise kisi ko mat batao.']);
  }
  final reasons = <String>[];
  var score = 0;
  if (RegExp(r'https?://|www\.|bit\.ly|tinyurl').hasMatch(body)) {
    score++;
    reasons.add('Link hai');
  }
  if (body.contains('.apk')) {
    score += 2;
    reasons.add('APK file install karne ko kaha');
  }
  const scamWords = [
    'lottery',
    'winner',
    'you have won',
    'prize',
    'kyc',
    'account will be blocked',
    'account blocked',
    'blocked today',
    'pan card',
    'claim now',
    'reward points',
    'expire today',
    'electricity bill',
    'disconnect',
    'click here',
    'verify now',
    'loan approved',
    'lucky draw',
    'work from home',
  ];
  for (final w in scamWords) {
    if (body.contains(w)) {
      score++;
      reasons.add('"$w" jaisa shabd');
    }
  }
  if (isNumericSender(m.address) && score >= 1) {
    score++;
    reasons.add('Personal number se aaya');
  }
  if (score >= 3) return SmsVerdict('Scam ka shak', Colors.red, reasons);
  if (score == 2) return SmsVerdict('Savdhan', Colors.orange, reasons);
  final promoSender = RegExp(r'^[A-Za-z]{2}-').hasMatch(m.address);
  if (promoSender ||
      body.contains('offer') ||
      body.contains('discount') ||
      body.contains('% off') ||
      body.contains('t&c')) {
    return SmsVerdict('Promotional', Colors.grey, ['Offer ya promotion jaisa msg']);
  }
  return SmsVerdict('Normal', Colors.green, ['Koi shak wali baat nahi mili']);
}

class CommHub extends StatefulWidget {
  const CommHub({super.key});

  @override
  State<CommHub> createState() => _CommHubState();
}

class _CommHubState extends State<CommHub> {
  int _m = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    label: Text('Calls'),
                    icon: Icon(Icons.call_outlined)),
                ButtonSegment(
                    value: 1, label: Text('SMS'), icon: Icon(Icons.sms_outlined)),
                ButtonSegment(
                    value: 2,
                    label: Text('Auto reply'),
                    icon: Icon(Icons.reply)),
              ],
              selected: {_m},
              onSelectionChanged: (s) => setState(() => _m = s.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _m,
            children: const [CallsTab(), SmsTab(), AutoReplyTab()],
          ),
        ),
      ],
    );
  }
}

class SmsTab extends StatefulWidget {
  const SmsTab({super.key});

  @override
  State<SmsTab> createState() => _SmsTabState();
}

class _SmsTabState extends State<SmsTab> {
  bool _loading = true;
  bool _granted = false;
  bool _asked = false;
  bool _onlyRisky = false;
  String? _error;
  List<SmsMsg> _items = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final has = await _native.invokeMethod<bool>('hasSmsPermission') ?? false;
      _granted = has;
      if (has) await _load();
    } catch (e) {
      _error = 'SMS nahi khul paaye: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _request() async {
    setState(() => _loading = true);
    try {
      final ok =
          await _native.invokeMethod<bool>('requestSmsPermission') ?? false;
      _granted = ok;
      _asked = true;
      if (ok) await _load();
    } catch (e) {
      _error = 'Permission me dikkat: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _load() async {
    final raw = await _native.invokeMethod<List<dynamic>>('getSms') ?? [];
    _items = raw.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return SmsMsg((m['address'] ?? '') as String, (m['body'] ?? '') as String,
          (m['date'] ?? 0) as int);
    }).toList();
  }

  void _open(SmsMsg m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SmsSheet(msg: m, verdict: judgeSms(m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_granted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sms_outlined, size: 48),
              const SizedBox(height: 12),
              const Text(
                'SMS dekhne ke liye SMS ki permission chahiye. Msg sirf aapke phone me padhe jate hain.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _request, child: const Text('Permission do')),
              if (_asked)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Permission nahi mili. Phone Settings > Apps > Call Guard > 3 dots > Allow restricted settings, phir Permissions > SMS me Allow karo.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      );
    }
    final shown = _items.where((m) {
      if (!_onlyRisky) return true;
      final l = judgeSms(m).label;
      return l == 'Scam ka shak' || l == 'Savdhan';
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Sab'),
                selected: !_onlyRisky,
                onSelected: (_) => setState(() => _onlyRisky = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Shak wale'),
                selected: _onlyRisky,
                onSelected: (_) => setState(() => _onlyRisky = true),
              ),
              const Spacer(),
              IconButton(onPressed: _init, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('Koi msg nahi mila'))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final m = shown[i];
                    final v = judgeSms(m);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: v.color.withOpacity(0.15),
                        child: Icon(Icons.sms_outlined, color: v.color),
                      ),
                      title: Text(m.address),
                      subtitle: Text(m.body,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(v.label,
                              style: TextStyle(
                                  color: v.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text(timeAgo(m.date),
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      onTap: () => _open(m),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class SmsSheet extends StatefulWidget {
  final SmsMsg msg;
  final SmsVerdict verdict;
  const SmsSheet({super.key, required this.msg, required this.verdict});

  @override
  State<SmsSheet> createState() => _SmsSheetState();
}

class _SmsSheetState extends State<SmsSheet> {
  bool _aiLoading = false;
  String? _aiText;

  Future<void> _askAi() async {
    setState(() {
      _aiLoading = true;
      _aiText = null;
    });
    try {
      final r = await askAI(aiSystem, [
        {
          'role': 'user',
          'content':
              'Neeche ek SMS ka text hai (numbers chhupa diye gaye hain). Hinglish me sirf 3 chhoti lines likho: '
                  '1) Ye kis tarah ka msg hai. 2) Verdict: Scam, Spam, Promotional ya Normal. 3) Mujhe kya karna chahiye. '
                  'Plain text me likho.\n\nSender: ${maskDigits(widget.msg.address)}\nMsg: ${maskDigits(widget.msg.body)}'
        }
      ]);
      if (!mounted) return;
      setState(() => _aiText = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiText = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _aiLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.msg;
    final v = widget.verdict;
    final n = last10(m.address);
    final canBlock = isNumericSender(m.address) && n.length == 10;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final blocked = canBlock && store.findBlocked(n) != null;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.address, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(v.label,
                    style: TextStyle(
                        color: v.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 4),
                ...v.reasons.map((r) => Text('• $r')),
                const SizedBox(height: 12),
                const Divider(),
                SelectableText(m.body),
                const SizedBox(height: 12),
                if (canBlock)
                  blocked
                      ? OutlinedButton.icon(
                          onPressed: () => store.unblock(n),
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Block hatao'),
                        )
                      : FilledButton.icon(
                          onPressed: () => store.block(n, 'Scam / Fraud'),
                          icon: const Icon(Icons.block),
                          label: const Text('Is number ko block karo'),
                        ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _aiLoading ? null : _askAi,
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('AI se check karo'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'AI check me msg ka text (numbers chhupakar) Google Gemini ko jata hai.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                if (_aiLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (_aiText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SelectableText(_aiText!),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AutoReplyTab extends StatefulWidget {
  const AutoReplyTab({super.key});

  @override
  State<AutoReplyTab> createState() => _AutoReplyTabState();
}

class _AutoReplyTabState extends State<AutoReplyTab> {
  final _c = TextEditingController(
      text:
          'Main abhi available nahi hoon. Kripya apna naam aur kaam SMS karein.');
  bool _enabled = false;
  bool _hasSend = false;
  bool _loading = true;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = Map<String, dynamic>.from(
          await _native.invokeMethod('getAutoSms') as Map);
      final t = (m['text'] ?? '') as String;
      if (t.isNotEmpty) _c.text = t;
      _enabled = (m['enabled'] ?? false) as bool;
      _hasSend = await _native.invokeMethod<bool>('hasSendSms') ?? false;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      await _native.invokeMethod(
          'setAutoSms', {'enabled': _enabled, 'text': _c.text.trim()});
      if (mounted) setState(() => _msg = 'Save ho gaya');
    } catch (e) {
      if (mounted) setState(() => _msg = 'Save nahi hua: $e');
    }
  }

  Future<void> _toggle(bool v) async {
    if (v && !_hasSend) {
      final ok = await _native.invokeMethod<bool>('requestSendSms') ?? false;
      _hasSend = ok;
      if (!ok) {
        if (mounted) {
          setState(() => _msg =
              'SMS bhejne ki permission nahi mili. Settings > Apps > Call Guard > Permissions > SMS me Allow karo.');
        }
        return;
      }
    }
    setState(() => _enabled = v);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Jab block list wale number ki call reject hogi, to us number ko ye SMS apne aap jayega. Ek number ko 24 ghante me sirf ek baar. SMS ka charge aapke plan se katega. Sirf block list ke numbers ko jayega, baaki kisi ko nahi.',
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Block kiye number ko SMS reply bhejo'),
          value: _enabled,
          onChanged: _toggle,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _c,
          maxLines: 4,
          maxLength: 160,
          decoration: const InputDecoration(
            labelText: 'SMS ka text',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _save, child: const Text('Text save karo')),
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_msg!),
          ),
        const SizedBox(height: 12),
        Text(
          _hasSend
              ? 'SMS bhejne ki permission mili hui hai'
              : 'SMS bhejne ki permission abhi nahi hai. Switch ON karoge to maangi jayegi.',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
