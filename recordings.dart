import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core.dart' show cgDur;

const _rc = MethodChannel('callguard/native');

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _playing;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  Future<void> _stop() async {
    try {
      await _rc.invokeMethod('stopRec');
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final r = await _rc.invokeMethod<List<dynamic>>('listRecs');
      final list = (r ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = 'Recordings load nahi hui: $e';
      });
    }
  }

  Future<void> _toggle(String path) async {
    try {
      if (_playing == path) {
        await _stop();
        if (mounted) setState(() => _playing = null);
        return;
      }
      final ms =
          await _rc.invokeMethod<int>('playRec', {'path': path}) ?? 0;
      if (!mounted) return;
      setState(() => _playing = path);
      if (ms > 0) {
        Future.delayed(Duration(milliseconds: ms + 300), () {
          if (mounted && _playing == path) setState(() => _playing = null);
        });
      }
    } catch (_) {}
  }

  Future<void> _delete(String path) async {
    try {
      await _rc.invokeMethod('deleteRec', {'path': path});
    } catch (_) {}
    if (_playing == path) _playing = null;
    await _load();
  }

  String _when(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    String two(int x) => x < 10 ? '0$x' : '$x';
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI assistant recordings'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Padding(padding: const EdgeInsets.all(16), child: Text(_err!))
              : _items.isEmpty
                  ? const Center(child: Text('Abhi koi recording nahi'))
                  : ListView(
                      children: [
                        for (final r in _items)
                          ListTile(
                            leading: IconButton(
                              icon: Icon(_playing == r['path']
                                  ? Icons.stop_circle
                                  : Icons.play_circle),
                              iconSize: 36,
                              onPressed: () => _toggle(r['path'] as String),
                            ),
                            title: Text((r['info'] ?? 'Unknown') as String),
                            subtitle: Text(
                              _when((r['ts'] ?? 0) as int) +
                                  '  |  ' +
                                  cgDur((r['dur'] ?? 0) as int) +
                                  (((r['summary'] ?? '') as String).isNotEmpty
                                      ? '\n' + (r['summary'] as String)
                                      : ''),
                            ),
                            isThreeLine:
                                ((r['summary'] ?? '') as String).isNotEmpty,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(r['path'] as String),
                            ),
                          ),
                      ],
                    ),
    );
  }
}
