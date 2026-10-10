import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core.dart';

const _cn = MethodChannel('callguard/native');

class AiTab extends StatefulWidget {
  const AiTab({super.key});

  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab> {
  final _input = TextEditingController();
  final _keyInput = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;

  static const _quick = [
    'Is hafte kaun spam tha?',
    'Kal kisne call kiya?',
    'Bank se call aaya, OTP maang raha hai',
    'Lottery jeetne ka call aaya',
  ];

  bool _wantsHistory(String t) {
    final s = t.toLowerCase();
    for (final k in const [
      'kisne',
      'is hafte',
      'kal ',
      'aaj ',
      'miss',
      'history',
      'recent',
      'kaun spam',
      'kitne call',
      'kitni call',
      'pichli'
    ]) {
      if (s.contains(k)) return true;
    }
    return false;
  }

  String _two(int x) => x < 10 ? '0$x' : '$x';

  String _typeName(int t) {
    switch (t) {
      case 1:
        return 'aayi';
      case 2:
        return 'gayi';
      case 3:
        return 'miss';
      case 5:
        return 'reject';
      case 6:
        return 'block';
      default:
        return 'other';
    }
  }

  Future<String?> _callContext() async {
    try {
            final isDef = await _cn.invokeMethod<bool>('isDefaultDialer') ?? false;
      if (!isDef) return null;
      final has =
          await _cn.invokeMethod<bool>('hasCallLogPermission') ?? false;
      if (!has) return null;
      final raw =
          await _cn.invokeMethod<List<dynamic>>('getRecentCalls') ?? [];
      final now = DateTime.now();
      final sb = StringBuffer();
      sb.writeln(
          'Abhi ka samay: ${now.day}/${now.month}/${now.year} ${_two(now.hour)}:${_two(now.minute)}');
      sb.writeln('Meri recent call history (naya pehle):');
      var count = 0;
      for (final r in raw) {
        if (count >= 40) break;
        final m = Map<String, dynamic>.from(r as Map);
        final n = last10((m['number'] ?? '') as String);
        final name = (m['name'] ?? '') as String;
        final date = (m['date'] ?? 0) as int;
        final type = (m['type'] ?? 0) as int;
        final dur = (m['dur'] ?? 0) as int;
        final d = DateTime.fromMillisecondsSinceEpoch(date);
        final who = name.isNotEmpty
            ? name
            : (n.length >= 4 ? '...${n.substring(n.length - 4)}' : 'Unknown');
        var tag = '';
        if (store.findBlocked(n) != null) {
          tag = ', meri block list me';
        } else if (n.startsWith('140') || n.startsWith('160')) {
          tag = ', telemarketing series';
        }
        sb.writeln(
            '- $who | ${_typeName(type)} | ${d.day}/${d.month} ${_two(d.hour)}:${_two(d.minute)} | ${dur}s$tag');
        count++;
      }
      return sb.toString();
    } catch (_) {
      return null;
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
      _input.clear();
    });
    _scrollDown();
    try {
      final history = _messages
          .where((m) => m['role'] != 'error')
          .map((m) => Map<String, String>.from(m))
          .toList();
      if (_wantsHistory(text)) {
        final c = await _callContext();
        if (c == null) {
          throw Exception(
              'Call history ke liye Calls tab me call log ki permission do, phir dobara pucho.');
        }
        history.last['content'] = text +
            '\n\n' +
            c +
            '\nSirf is history ke aadhaar par chhota jawab do. Kisi number ko pakka spam mat batao, sirf andaza batao.';
      }
      final reply = await askAI(aiSystem, history);
      if (!mounted) return;
      setState(() => _messages.add({'role': 'assistant', 'content': reply}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add({
            'role': 'error',
            'content': e.toString().replaceFirst('Exception: ', '')
          }));
    }
    if (mounted) setState(() => _loading = false);
    _scrollDown();
  }
  Widget _keyScreen() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('AI ke liye apni key banao',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
            'Ye sirf AI wale features ke liye hai: AI chat, "AI se poochho", call history poochna. Spam score, call card, auto SMS aur baaki sab bina key ke chalta hai.'),
        const SizedBox(height: 16),
        const Text('3 aasan step:',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text(
            '1. Neeche "Key banao" dabao. Google AI Studio khulega, apne Gmail se login karo.'),
        const SizedBox(height: 4),
        const Text('2. "Create API key" dabao aur key copy karo.'),
        const SizedBox(height: 4),
        const Text(
            '3. Yahan wapas aao, key paste karo aur "Save karo" dabao.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => launchUrl(
              Uri.parse('https://aistudio.google.com/apikey'),
              mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Key banao'),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _keyInput,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'API key',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () async {
                final d = await Clipboard.getData('text/plain');
                final t = d?.text;
                if (t != null && t.trim().isNotEmpty) {
                  _keyInput.text = t.trim();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final k = _keyInput.text.trim();
            if (k.isEmpty) return;
            store.setKey(k);
            _keyInput.clear();
          },
          child: const Text('Save karo'),
        ),
        const SizedBox(height: 16),
        const Text(
            'Key sirf aapke phone me save hoti hai. Limit aur kharch aapki apni key par lagta hai, aur Google ki free limits badalti rehti hain.'),
      ],
    );
  }
  
  Widget _oldKeyScreen()  {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('AI chalane ke liye Gemini API key daalo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
            'Key Google AI Studio (aistudio.google.com) se banti hai. Ye sirf aapke phone me save hoti hai.'),
        const SizedBox(height: 16),
        TextField(
          controller: _keyInput,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'API key',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final k = _keyInput.text.trim();
            if (k.isEmpty) return;
            store.setKey(k);
            _keyInput.clear();
          },
          child: const Text('Save karo'),
        ),
      ],
    );
  }

  Widget _chatScreen() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _messages.clear()),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Chat saaf'),
            ),
            TextButton.icon(
              onPressed: () {
                store.setKey('');
                setState(() => _messages.clear());
              },
              icon: const Icon(Icons.key_off, size: 18),
              label: const Text('Key badlo'),
            ),
          ],
        ),
        Expanded(
          child: _messages.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('Kuch bhi pucho ya neeche se chuno:',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: _quick
                          .map((q) => ActionChip(
                                label: Text(q),
                                onPressed: () => _send(q),
                              ))
                          .toList(),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isUser = m['role'] == 'user';
                    final isError = m['role'] == 'error';
                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8),
                        decoration: BoxDecoration(
                          color: isError
                              ? Colors.red.withOpacity(0.15)
                              : isUser
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SelectableText(m['content'] ?? ''),
                      ),
                    );
                  },
                ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Yahan likho...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _send(),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        return store.apiKey.isEmpty ? _keyScreen() : _chatScreen();
      },
    );
  }
}
