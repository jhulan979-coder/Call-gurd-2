import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'ai_tab.dart';
import 'core.dart';

const receptionistSystem =
    'Tum ek AI receptionist ho jo apne maalik ki taraf se unknown caller se phone par baat kar raha hai. '
    'Hamesha chhote, saaf bolchaal ke vaakya me jawab do (zyada se zyada 2 vaakya), kyunki tumhara jawab bola jayega. '
    'Markdown, bullet ya emoji mat use karo. '
    'Pehle poocho ki caller kaun hai aur kis liye call kiya hai. '
    'Agar caller insurance, loan, credit card, lottery, KYC, OTP ya koi bhi sales ya offer ki baat kare, to vinamrta se kaho ki maalik interested nahi hain, aur request karo ki unka number hata diya jaye. '
    'Agar delivery ya koi zaruri kaam lage, to poocho ki kya sandesh dena hai, aur kaho ki maalik ko bata diya jayega. '
    'Kabhi OTP, PIN, password, bank ya address jaisi personal jaankari mat dena. '
    'Caller jis bhasha me bole usi me jawab do (Hindi ya English ya Hinglish).';

const summarySystem =
    'Neeche ek phone call ka transcript hai (Caller aur Receptionist ke beech). '
    'Hinglish me sirf 3 chhoti lines likho: '
    '1) Caller kaun tha aur kya chahta tha. '
    '2) Verdict: Spam, Scam, Delivery ya Zaruri me se ek. '
    '3) Maalik ko kya karna chahiye. '
    'Plain text me likho, koi markdown nahi.';

class AiHub extends StatefulWidget {
  const AiHub({super.key});

  @override
  State<AiHub> createState() => _AiHubState();
}

class _AiHubState extends State<AiHub> {
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
                    label: Text('Chat'),
                    icon: Icon(Icons.chat_bubble_outline)),
                ButtonSegment(
                    value: 1,
                    label: Text('Receptionist'),
                    icon: Icon(Icons.support_agent)),
              ],
              selected: {_m},
              onSelectionChanged: (s) => setState(() => _m = s.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _m,
            children: const [AiTab(), ReceptionistTab()],
          ),
        ),
      ],
    );
  }
}

class ReceptionistTab extends StatefulWidget {
  const ReceptionistTab({super.key});

  @override
  State<ReceptionistTab> createState() => _ReceptionistTabState();
}

class _ReceptionistTabState extends State<ReceptionistTab> {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _msgs = [];

  bool _sttReady = false;
  bool _listening = false;
  bool _thinking = false;
  bool _speak = true;
  String _lang = 'hi-IN';
  String _partial = '';
  String? _summary;
  String? _err;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _sttReady = await _stt.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _listening = false;
              _err = 'Mic error: ${e.errorMsg}';
            });
          }
        },
      );
      await _tts.setSpeechRate(0.5);
      await _tts.setLanguage(_lang);
    } catch (e) {
      _sttReady = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _setLang(String l) async {
    setState(() => _lang = l);
    try {
      await _tts.setLanguage(l);
    } catch (_) {}
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _listen() async {
    if (!_sttReady) {
      setState(() => _err =
          'Mic ya speech service available nahi hai. Neeche likh kar bhi bol sakte ho.');
      return;
    }
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    await _tts.stop();
    setState(() {
      _listening = true;
      _partial = '';
      _err = null;
    });
    await _stt.listen(
      localeId: _lang,
      onResult: (r) {
        if (!mounted) return;
        setState(() => _partial = r.recognizedWords);
        if (r.finalResult) {
          final t = r.recognizedWords;
          setState(() {
            _listening = false;
            _partial = '';
          });
          _send(t);
        }
      },
    );
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _thinking) return;
    setState(() {
      _msgs.add({'role': 'user', 'content': t});
      _thinking = true;
      _summary = null;
      _err = null;
      _input.clear();
    });
    _scrollDown();
    try {
      final reply = await askAI(receptionistSystem, List.of(_msgs));
      if (!mounted) return;
      setState(() => _msgs.add({'role': 'assistant', 'content': reply}));
      if (_speak) {
        try {
          await _tts.speak(reply);
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.removeLast();
        _err = e.toString().replaceFirst('Exception: ', '');
      });
    }
    if (mounted) setState(() => _thinking = false);
    _scrollDown();
  }

  Future<void> _summarize() async {
    if (_msgs.isEmpty || _thinking) return;
    setState(() {
      _thinking = true;
      _err = null;
    });
    final transcript = _msgs
        .map((m) =>
            '${m['role'] == 'user' ? 'Caller' : 'Receptionist'}: ${m['content']}')
        .join('\n');
    try {
      final r = await askAI(summarySystem, [
        {'role': 'user', 'content': transcript}
      ]);
      if (!mounted) return;
      setState(() => _summary = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _thinking = false);
    _scrollDown();
  }

  Future<void> _reset() async {
    await _tts.stop();
    await _stt.cancel();
    setState(() {
      _msgs.clear();
      _summary = null;
      _err = null;
      _partial = '';
      _listening = false;
    });
  }

  Widget _bubble(String who, String text, bool right) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: right ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(who,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            SelectableText(text),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Hindi'),
                selected: _lang == 'hi-IN',
                onSelected: (_) => _setLang('hi-IN'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('English'),
                selected: _lang == 'en-IN',
                onSelected: (_) => _setLang('en-IN'),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _speak = !_speak),
                icon: Icon(_speak ? Icons.volume_up : Icons.volume_off),
              ),
              TextButton(onPressed: _reset, child: const Text('Naya call')),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            children: [
              if (_msgs.isEmpty && _partial.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aap spam caller ban kar bolo. Mic dabao aur bolo, jaise:\n"Main XYZ insurance se bol raha hoon, aapke liye ek offer hai."\n\nAI receptionist jawab dega. Mic aur speaker saath me chalte hain, isliye earphone lagana behtar hai.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ..._msgs.map((m) => m['role'] == 'user'
                  ? _bubble('Caller (aap)', m['content'] ?? '', true)
                  : _bubble('AI receptionist', m['content'] ?? '', false)),
              if (_partial.isNotEmpty) _bubble('Caller (aap)', _partial, true),
              if (_thinking)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
              if (_summary != null)
                Card(
                  color: cs.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Call summary',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        SelectableText(_summary!),
                      ],
                    ),
                  ),
                ),
              if (_err != null)
                Card(
                  color: Colors.red.withOpacity(0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_err!),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: (_msgs.isEmpty || _thinking) ? null : _summarize,
              icon: const Icon(Icons.summarize_outlined),
              label: const Text('Summary banao'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: _send,
                  decoration: const InputDecoration(
                    hintText: 'Ya yahan likho...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _thinking ? null : _listen,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
                color: _listening ? Colors.red : null,
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: _thinking ? null : () => _send(_input.text),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
