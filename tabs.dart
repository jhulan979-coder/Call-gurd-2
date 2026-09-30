import 'package:flutter/material.dart';
import 'core.dart';

class CheckTab extends StatefulWidget {
  const CheckTab({super.key});

  @override
  State<CheckTab> createState() => _CheckTabState();
}

class _CheckTabState extends State<CheckTab> {
  final _c = TextEditingController();
  String? _verdict;
  Color _color = Colors.grey;
  IconData _icon = Icons.help_outline;
  String _number = '';
  String _cat = categories[0];
  bool _aiLoading = false;
  String? _aiText;

  bool get _isBlocked => _number.isNotEmpty && store.findBlocked(_number) != null;

  void _check() {
    FocusScope.of(context).unfocus();
    final raw = _c.text.trim();
    final n = last10(raw);
    if (n.length < 10) {
      setState(() {
        _number = '';
        _aiText = null;
        _verdict = 'Poora 10 digit number daalo';
        _color = Colors.orange;
        _icon = Icons.warning_amber;
      });
      return;
    }
    String v;
    Color c;
    IconData i;
    final b = store.findBlocked(n);
    if (b != null) {
      v = 'Aapki block list me hai (${b.label})';
      c = Colors.red;
      i = Icons.block;
    } else if (n.startsWith('140') || n.startsWith('160')) {
      v = 'Shak: telemarketing / promotional number';
      c = Colors.orange;
      i = Icons.campaign;
    } else if (raw.startsWith('+') && !raw.startsWith('+91')) {
      v = 'International number, savdhan rahein';
      c = Colors.orange;
      i = Icons.public;
    } else if (RegExp(r'^(\d)\1{9}$').hasMatch(n)) {
      v = 'Shak: sabhi digit ek jaise hain';
      c = Colors.orange;
      i = Icons.warning_amber;
    } else {
      v = 'Koi spam report nahi mili';
      c = Colors.green;
      i = Icons.verified_user;
    }
    store.addHistory(n, v);
    setState(() {
      _number = n;
      _aiText = null;
      _verdict = v;
      _color = c;
      _icon = i;
    });
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
              'Ye phone number mujhe call kar raha hai: $_number. App ka basic check: $_verdict. '
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _c,
          keyboardType: TextInputType.phone,
          onSubmitted: (_) => _check(),
          decoration: InputDecoration(
            labelText: 'Phone number',
            prefixIcon: const Icon(Icons.phone),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _c.clear();
                setState(() {
                  _verdict = null;
                  _number = '';
                  _aiText = null;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _check,
          icon: const Icon(Icons.search),
          label: const Text('Number check karo'),
        ),
        const SizedBox(height: 16),
        if (_verdict != null)
          Card(
            color: _color.withOpacity(0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_icon, color: _color, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _verdict!,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _color),
                        ),
                      ),
                    ],
                  ),
                  if (_number.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (!_isBlocked) ...[
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
                      FilledButton.tonalIcon(
                        onPressed: () {
                          store.block(_number, _cat);
                          setState(() {
                            _verdict = 'Aapki block list me hai ($_cat)';
                            _color = Colors.red;
                            _icon = Icons.block;
                          });
                        },
                        icon: const Icon(Icons.block),
                        label: const Text('Block list me daalo'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _aiLoading ? null : _askAi,
                      icon: const Icon(Icons.smart_toy_outlined),
                      label: const Text('AI se poochho'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (_aiText != null || _aiLoading)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _aiLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SelectableText(_aiText ?? ''),
            ),
          ),
      ],
    );
  }
}

class BlockedTab extends StatefulWidget {
  const BlockedTab({super.key});

  @override
  State<BlockedTab> createState() => _BlockedTabState();
}

class _BlockedTabState extends State<BlockedTab> {
  String _q = '';

  void _addDialog() {
    final c = TextEditingController();
    String cat = categories[0];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Number block karo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: c,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '10 digit number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: categories
                    .map((x) => ChoiceChip(
                          label: Text(x),
                          selected: cat == x,
                          onSelected: (_) => setD(() => cat = x),
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  store.block(c.text, cat);
                  Navigator.pop(ctx);
                },
                child: const Text('Block')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items =
              store.blocked.where((e) => e.number.contains(_q)).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Number dhundo',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              if (store.blocked.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Hatane ke liye side me swipe karo',
                      style: TextStyle(fontSize: 12)),
                ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Koi number nahi mila'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final e = items[i];
                          return Dismissible(
                            key: ValueKey(e.number),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => store.unblock(e.number),
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.block)),
                              title: Text(e.number),
                              subtitle: Text('${e.label} • ${timeAgo(e.ts)}'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
