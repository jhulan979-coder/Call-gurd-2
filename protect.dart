import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _native = MethodChannel('callguard/native');

class ProtectCard extends StatefulWidget {
  const ProtectCard({super.key});

  @override
  State<ProtectCard> createState() => _ProtectCardState();
}

class _ProtectCardState extends State<ProtectCard> with WidgetsBindingObserver {
  bool _active = false;
  bool _busy = false;
  String? _msg;

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final a = await _native.invokeMethod<bool>('isScreeningActive') ?? false;
      if (mounted) setState(() => _active = a);
    } catch (_) {
      if (mounted) setState(() => _active = false);
    }
  }

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final ok =
          await _native.invokeMethod<bool>('requestScreeningRole') ?? false;
      _active = ok;
      if (!ok) {
        _msg = 'Permission nahi mili. Dobara koshish karo.';
      }
      await _native.invokeMethod<bool>('requestNotificationPermission');
    } catch (e) {
      _msg = 'Dikkat: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = _active ? Colors.green : Colors.orange;
    return Card(
      color: color.withOpacity(0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_active ? Icons.gpp_good : Icons.gpp_maybe,
                    color: color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _active ? 'Auto-block chalu hai' : 'Auto-block band hai',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
                'Block list ke numbers ki aane wali calls apne aap reject hongi, aur shak wale numbers par notification aayega.'),
            if (!_active) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _enable,
                child: const Text('Chalu karo'),
              ),
            ],
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_msg!),
              ),
          ],
        ),
      ),
    );
  }
}
