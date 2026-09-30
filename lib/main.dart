import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CallGuardApp());

class CallGuardApp extends StatelessWidget {
  const CallGuardApp({super.key  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Guard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

String last10(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  List<String> _blocked = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _blocked = prefs.getStringList('blocked') ?? []);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked', _blocked);
  }

  void _add(String number) {
    final n = last10(number);
    if (n.length < 10 || _blocked.contains(n)) return;
    setState(() => _blocked.add(n));
    _save();
  }

  void _remove(String number) {
    setState(() => _blocked.remove(number));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CheckTab(blocked: _blocked, onBlock: _add),
      BlockedTab(blocked: _blocked, onAdd: _add, onRemove: _remove),
      const AssistantTab(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Call Guard')),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Check'),
          NavigationDestination(icon: Icon(Icons.block), label: 'Blocked'),
          NavigationDestination(icon: Icon(Icons.smart_toy), label: 'AI'),
        ],
      ),
    );
  }
}

class CheckTab extends StatefulWidget {
  final List<String> blocked;
  final void Function(String) onBlock;
  const CheckTab({super.key, required this.blocked, required this.onBlock});

  @override
  State<CheckTab> createState() => _CheckTabState();
}

class _CheckTabState extends State<CheckTab> {
  final _controller = TextEditingController();
  String? _result;
  Color _color = Colors.grey;
  bool _canBlock = false;

  void _check() {
    final raw = _controller.text.trim();
    final n = last10(raw);
    if (n.length < 10) {
      setState(() {
        _result = 'Poora 10 digit number daalo';
        _color = Colors.orange;
        _canBlock = false;
      });
      return;
    }
    if (widget.blocked.contains(n)) {
      setState(() {
        _result = 'Ye number aapki block list me hai';
        _color = Colors.red;
        _canBlock = false;
      });
    } else if (n.startsWith('140') || n.startsWith('160')) {
      setState(() {
        _result = 'Shak: telemarketing / promotional number';
        _color = Colors.orange;
        _canBlock = true;
      });
    } else {
      setState(() {
        _result = 'Koi spam report nahi mili';
        _color = Colors.green;
        _canBlock = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _check, child: const Text('Number check karo')),
          const SizedBox(height: 24),
          if (_result != null)
            Card(
              color: _color.withOpacity(0.15),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_result!,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _color)),
                    if (_canBlock) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          widget.onBlock(_controller.text);
                          _check();
                        },
                        icon: const Icon(Icons.block),
                        label: const Text('Block list me daalo'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BlockedTab extends StatelessWidget {
  final List<String> blocked;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  const BlockedTab(
      {super.key,
      required this.blocked,
      required this.onAdd,
      required this.onRemove});

  void _addDialog(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Number block karo'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '10 digit number'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                onAdd(c.text);
                Navigator.pop(context);
              },
              child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: blocked.isEmpty
          ? const Center(child: Text('Abhi koi number block nahi hai'))
          : ListView.builder(
              itemCount: blocked.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text(blocked[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onRemove(blocked[i]),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AssistantTab extends StatefulWidget {
  const AssistantTab({super.key});

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  final _input = TextEditingController();
  final _keyInput = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  String _apiKey = '';
  bool _loading = false;
  bool _ready = false;

  static const _system =
      'Tum Call Guard app ke AI helper ho. Hinglish me chhote aur saaf jawab do. '
      'Spam, scam aur telemarketing calls pehchanne aur unse bachne me madad karo. '
      'Kisi khaas number ke baare me pakka nahi bata sakte, sirf salah do. '
      'Kabhi OTP, PIN ya bank details share karne ko mat kaho.';

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('api_key') ?? '';
      _ready = true;
    });
  }

  Future<void> _saveKey() async {
    final k = _keyInput.text.trim();
    if (k.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', k);
    _keyInput.clear();
    setState(() => _apiKey = k);
  }

  Future<void> _clearKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key');
    setState(() {
      _apiKey = '';
      _messages.clear();
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
      _input.clear();
    });
    _scrollDown();
    try {
      final history = _messages.where((m) => m['role'] != 'error').toList();
      final res = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'content-type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 600,
          'system': _system,
          'messages': history,
        }),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200) {
        final reply =
            (data['content'] as List).map((c) => c['text'] ?? '').join();
        setState(() => _messages.add({'role': 'assistant', 'content': reply}));
      } else {
        final err = data['error']?['message'] ?? 'Error ${res.statusCode}';
        setState(() => _messages.add({'role': 'error', 'content': '$err'}));
      }
    } catch (e) {
      setState(() => _messages
          .add({'role': 'error', 'content': 'Internet ya connection ki dikkat: $e'}));
    }
    setState(() => _loading = false);
    _scrollDown();
  }

  Widget _keyScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('AI chalane ke liye API key daalo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
              'Key console.anthropic.com se banti hai. Ye sirf aapke phone me save hoti hai.'),
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
          FilledButton(onPressed: _saveKey, child: const Text('Save karo')),
        ],
      ),
    );
  }

  Widget _chatScreen() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _clearKey,
            icon: const Icon(Icons.key_off, size: 18),
            label: const Text('Key badlo'),
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Kuch bhi pucho, jaise:\n"Koi bol raha hai bank se call hai, OTP mang raha hai. Kya karun?"',
                      textAlign: TextAlign.center,
                    ),
                  ),
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
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(m['content'] ?? ''),
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
                onPressed: _send,
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
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return _apiKey.isEmpty ? _keyScreen() : _chatScreen();
  }
}
