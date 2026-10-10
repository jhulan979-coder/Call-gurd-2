import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'core.dart';

const _native = MethodChannel('callguard/native');

String cgWhen(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final n = DateTime.now();
  String two(int x) => x < 10 ? '0$x' : '$x';
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final t = '$h12:${two(d.minute)} ${d.hour < 12 ? 'am' : 'pm'}';
  final diff = DateTime(n.year, n.month, n.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  const mon = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  if (diff == 0) return 'Aaj $t';
  if (diff == 1) return 'Kal $t';
  return '${two(d.day)} ${mon[d.month - 1]} $t';
}

String cgSecs(int s) {
  if (s <= 0) return '';
  final m = s ~/ 60;
  final r = s % 60;
  return m > 0 ? '${m}m ${r}s' : '${r}s';
}

class CallItem {
  final String number;
  final String name;
  final int date;
  final int type;
  final int dur;
  CallItem(this.number, this.name, this.date, this.type, [this.dur = 0]);
}

class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  int _mode = 0;

  bool _loading = true;
  bool _granted = false;
  bool _asked = false;
  bool _notDefault = false;
  String? _error;
  List<CallItem> _items = [];

  bool _cLoading = false;
  bool _cLoaded = false;
  bool _cGranted = false;
  String? _cError;
  String _query = '';
  List<CallItem> _contacts = [];

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
      final isDef =
          await _native.invokeMethod<bool>('isDefaultDialer') ?? false;
      final has = isDef &&
          (await _native.invokeMethod<bool>('hasCallLogPermission') ?? false);
      _granted = has;
      _notDefault = !isDef;
      if (has) await _loadCalls();
    } catch (e) {
      _error = 'Call list nahi khul paayi: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _request() async {
    setState(() => _loading = true);
    try {
      final ok =
          await _native.invokeMethod<bool>('requestCallLogPermission') ?? false;
      _granted = ok;
      _asked = true;
      if (ok) await _loadCalls();
    } catch (e) {
      _error = 'Permission me dikkat: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCalls() async {
    final raw =
        await _native.invokeMethod<List<dynamic>>('getRecentCalls') ?? [];
    final seen = <String>{};
    final list = <CallItem>[];
    for (final r in raw) {
      final m = Map<String, dynamic>.from(r as Map);
      final num = (m['number'] ?? '') as String;
      final n = last10(num);
      if (n.length < 10 || seen.contains(n)) continue;
      seen.add(n);
      list.add(CallItem(n, (m['name'] ?? '') as String,
          (m['date'] ?? 0) as int, (m['type'] ?? 0) as int,
          (m['dur'] ?? 0) as int));
    }
    _items = list;
  }

  Future<void> _loadContacts() async {
    setState(() {
      _cLoading = true;
      _cError = null;
    });
    try {
      final has =
          await _native.invokeMethod<bool>('hasContactsPermission') ?? false;
      _cGranted = has;
      if (has) {
        final raw =
            await _native.invokeMethod<List<dynamic>>('getContacts') ?? [];
        final seen = <String>{};
        final list = <CallItem>[];
        for (final r in raw) {
          final m = Map<String, dynamic>.from(r as Map);
          final n = last10((m['number'] ?? '') as String);
          if (n.length < 10 || seen.contains(n)) continue;
          seen.add(n);
          list.add(CallItem(n, (m['name'] ?? '') as String, 0, 0));
        }
        _contacts = list;
      }
      _cLoaded = true;
    } catch (e) {
      _cError = 'Contacts nahi khul paaye: $e';
    }
    if (mounted) setState(() => _cLoading = false);
  }

  Future<void> _requestContacts() async {
    setState(() => _cLoading = true);
    try {
      await _native.invokeMethod<bool>('requestContactsPermission');
    } catch (e) {
      _cError = 'Permission me dikkat: $e';
    }
    await _loadContacts();
  }

  IconData _typeIcon(int t) {
    switch (t) {
      case 1:
        return Icons.call_received;
      case 2:
        return Icons.call_made;
      case 3:
        return Icons.call_missed;
      case 5:
        return Icons.call_end;
      default:
        return Icons.phone;
    }
  }

  void _open(CallItem c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CallSheet(item: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    label: Text('Recent calls'),
                    icon: Icon(Icons.history)),
                ButtonSegment(
                    value: 1,
                    label: Text('Contacts'),
                    icon: Icon(Icons.contacts_outlined)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                setState(() => _mode = s.first);
                if (_mode == 1 && !_cLoaded) _loadContacts();
              },
            ),
          ),
        ),
        Expanded(child: _mode == 0 ? _recentView() : _contactsView()),
      ],
    );
  }

  Widget _recentView() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_notDefault) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Recent calls dekhne ke liye Call Guard ko default Phone app banao. Settings me button hai.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!_granted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_outlined, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Recent calls dekhne ke liye call log ki permission chahiye. Ye data sirf aapke phone me rehta hai.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _request, child: const Text('Permission do')),
              if (_asked)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Permission nahi mili. Phone Settings > Apps > Call Guard > Permissions > Call logs me Allow karo, phir yahan wapas aao.',
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
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Recent calls',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    onPressed: _init,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('Koi recent call nahi mili'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final c = _items[i];
                        final blocked = store.findBlocked(c.number) != null;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                blocked ? Colors.red.withOpacity(0.15) : null,
                            child: Icon(
                                blocked ? Icons.block : _typeIcon(c.type),
                                color: blocked ? Colors.red : null),
                          ),
                          title: Text(c.name.isNotEmpty ? c.name : c.number),
                          subtitle: Text(c.name.isNotEmpty
                              ? c.number
                              : (blocked ? 'Blocked' : 'Unknown')),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(cgWhen(c.date),
                                  style: const TextStyle(fontSize: 12)),
                              if (c.dur > 0)
                                Text(cgSecs(c.dur),
                                    style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          onTap: () => _open(c),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _contactsView() {
    if (_cLoading) return const Center(child: CircularProgressIndicator());
    if (!_cGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.contacts_outlined, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Contacts dekhne ke liye Contacts ki permission chahiye. Ye data sirf aapke phone me rehta hai.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _requestContacts,
                  child: const Text('Permission do')),
              if (_cLoaded)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Permission nahi mili. Phone Settings > Apps > Call Guard > Permissions > Contacts me Allow karo, phir yahan wapas aao.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_cError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_cError!, textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      );
    }
    final q = _query.toLowerCase();
    final shown = _contacts
        .where((c) =>
            q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.number.contains(q))
        .toList();
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: const InputDecoration(
                  hintText: 'Naam ya number dhundo',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const Center(child: Text('Koi contact nahi mila'))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final c = shown[i];
                        final blocked = store.findBlocked(c.number) != null;
                        final initial = c.name.isNotEmpty
                            ? c.name.substring(0, 1).toUpperCase()
                            : '#';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                blocked ? Colors.red.withOpacity(0.15) : null,
                            child: blocked
                                ? const Icon(Icons.block, color: Colors.red)
                                : Text(initial),
                          ),
                          title: Text(c.name.isNotEmpty ? c.name : c.number),
                          subtitle: Text(c.number),
                          trailing: blocked
                              ? const Icon(Icons.block,
                                  color: Colors.red, size: 18)
                              : null,
                          onTap: () => _open(c),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class CallSheet extends StatefulWidget {
  final CallItem item;
  const CallSheet({super.key, required this.item});

  @override
  State<CallSheet> createState() => _CallSheetState();
}

class _CallSheetState extends State<CallSheet> {
  String _cat = categories[0];
  bool _aiLoading = false;
  String? _aiText;
  List<CallItem> _hist = [];

  @override
  void initState() {
    super.initState();
    _loadHist();
  }

  Future<void> _loadHist() async {
    try {
      final isDef =
          await _native.invokeMethod<bool>('isDefaultDialer') ?? false;
      if (!isDef) return;
      final has =
          await _native.invokeMethod<bool>('hasCallLogPermission') ?? false;
      if (!has) return;
      final raw =
          await _native.invokeMethod<List<dynamic>>('getRecentCalls') ?? [];
      final list = <CallItem>[];
      for (final r in raw) {
        final m = Map<String, dynamic>.from(r as Map);
        if (last10((m['number'] ?? '') as String) != widget.item.number) {
          continue;
        }
        list.add(CallItem(widget.item.number, (m['name'] ?? '') as String,
            (m['date'] ?? 0) as int, (m['type'] ?? 0) as int,
            (m['dur'] ?? 0) as int));
        if (list.length >= 8) break;
      }
      if (mounted) setState(() => _hist = list);
    } catch (_) {}
  }

  IconData _histIcon(int t) {
    if (t == 1) return Icons.call_received;
    if (t == 2) return Icons.call_made;
    if (t == 3) return Icons.call_missed;
    if (t == 5 || t == 6) return Icons.block;
    return Icons.phone;
  }

  String _histName(int t) {
    if (t == 1) return 'Aayi';
    if (t == 2) return 'Gayi';
    if (t == 3) return 'Miss';
    if (t == 5) return 'Reject';
    if (t == 6) return 'Block';
    return 'Call';
  }

  String _verdict() {
    final n = widget.item.number;
    final b = store.findBlocked(n);
    if (b != null) return 'Aapki block list me hai (${b.label})';
    if (n.startsWith('140') || n.startsWith('160')) {
      return 'Shak: telemarketing / promotional number';
    }
    return 'Koi spam report nahi mili';
  }

  Future<void> _report() async {
    final n = widget.item.number;
    final d = DateTime.now();
    String two(int x) => x < 10 ? '0$x' : '$x';
    final date = '${two(d.day)}/${two(d.month)}/${two(d.year % 100)}';
    final body =
        'Spam call. Number $n. Date $date. Unsolicited commercial call.';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shikayat kaise karein',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
                'Marketing ya baar-baar aane wali call: TRAI ko 1909 par SMS. Fraud ya thagi ka shak: Chakshu par report. Paisa kat gaya ho to turant 1930.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                launchUrl(
                    Uri.parse('sms:1909?body=${Uri.encodeComponent(body)}'));
              },
              icon: const Icon(Icons.sms_outlined),
              label: const Text('1909 ko SMS taiyar karo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: n));
                launchUrl(Uri.parse('https://sancharsaathi.gov.in/sfc/'),
                    mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Chakshu kholo (number copy ho jayega)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _askAi() async {
    setState(() {
      _aiLoading = true;
      _aiText = null;
    });
    try {
      String why = '';
      try {
        why = await _native.invokeMethod<String>(
                'spamWhy', {'number': widget.item.number}) ??
            '';
      } catch (_) {}
      final r = await askAI(aiSystem, [
        {
          'role': 'user',
          'content':
              'Ye phone number mujhe call kar raha hai: ${widget.item.number}. App ka basic check: ${_verdict()}. App ka score aur wajah: $why. Jawab me saaf batao ki ye number spam kyun lag raha hai. '
                  'Kya ye spam ya scam ho sakta hai? Chhota jawab do aur batao mujhe kya karna chahiye.'
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
    final n = widget.item.number;
    final name = widget.item.name;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final blocked = store.findBlocked(n) != null;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(name, style: Theme.of(context).textTheme.headlineSmall),
                Text(n,
                    style: name.isNotEmpty
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(_verdict()),
                if (_hist.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Call history',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  for (final h in _hist)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(_histIcon(h.type),
                              size: 18,
                              color: (h.type == 3 || h.type == 5 || h.type == 6)
                                  ? Colors.red
                                  : Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  '${_histName(h.type)}  |  ${cgWhen(h.date)}')),
                          if (h.dur > 0) Text(cgSecs(h.dur)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: n)),
                  icon: const Icon(Icons.call),
                  label: const Text('Call karo'),
                ),
                const SizedBox(height: 8),
                if (!blocked) ...[
                  const Text('Category chuno:'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: categories
                        .map((x) => ChoiceChip(
                              label: Text(x),
                              selected: _cat == x,
                              onSelected: (_) => setState(() => _cat = x),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => store.block(n, _cat),
                    icon: const Icon(Icons.block),
                    label: const Text('Block list me daalo'),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: () => store.unblock(n),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Block hatao'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _aiLoading ? null : _askAi,
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('AI se poochho'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _report,
                  icon: const Icon(Icons.report_outlined),
                  label: const Text('Shikayat karo (TRAI / Chakshu)'),
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
