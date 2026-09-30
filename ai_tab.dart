import 'package:flutter/material.dart';
import 'core.dart';

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
    'Bank se call aaya, OTP maang raha hai',
    'Lottery jeetne ka call aaya',
    'KYC update ka message aaya',
    'Ek number baar-baar call kar raha hai',
  ];

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
      final history = _messages.where((m) => m['role'] != 'error').toList();
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
        const Text('AI chalane ke liye API key daalo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
            'Key console.anthropic.com se banti hai (API Keys section). Ye sirf aapke phone me save hoti hai.'),
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
