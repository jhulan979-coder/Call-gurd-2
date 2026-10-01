import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core.dart';

const _native = MethodChannel('callguard/native');

class CallItem {
  final String number;
  final String name;
  final int date;
  final int type;
  CallItem(this.number, this.name, this.date, this.type);
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
      final has =
          await _native.invokeMethod<bool>('hasCallLogPermission') ?? false;
      _granted = has;
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
          (m['date'] ?? 0) as int, (m['type'] ?? 0) as int));
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
                          trailing: Text(timeAgo(c.date)),
                          onTap: () => _open(c),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }Widget _contactsView() {
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

  String _verdict() {
    final n = widget.item.number;
    final b = store.findBlocked(n);
    if (b != null) return 'Aapki block list me hai (${b.label})';
    if (n.startsWith('140') || n.startsWith('160')) {
      return 'Shak: telemarketing / promotional number';
    }
    return 'Koi spam report nahi mili';
  }

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
              'Ye phone number mujhe call kar raha hai: ${widget.item.number}. App ka basic check: ${_verdict()}. '
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
