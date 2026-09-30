import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const categories = ['Spam', 'Scam / Fraud', 'Telemarketing', 'Other'];

const aiSystem =
    'Tum Call Guard app ke AI helper ho. Hinglish me chhote aur saaf jawab do (zyada se zyada 6-7 line). '
    'Spam, scam aur telemarketing calls pehchanne aur unse bachne me madad karo. '
    'Kisi khaas phone number ke baare me tum pakka nahi bata sakte, isliye sirf sambhavna aur salah do. '
    'Kabhi OTP, PIN, CVV ya bank details share karne ko mat kaho.';

class Entry {
  final String number;
  final String label;
  final int ts;
  Entry(this.number, this.label, this.ts);

  Map<String, dynamic> toJson() => {'n': number, 'l': label, 't': ts};

  factory Entry.fromJson(Map<String, dynamic> j) =>
      Entry(j['n'] as String, j['l'] as String, j['t'] as int);
}

String last10(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

String timeAgo(int ts) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
  if (d.inMinutes < 1) return 'abhi';
  if (d.inMinutes < 60) return '${d.inMinutes} min pehle';
  if (d.inHours < 24) return '${d.inHours} ghante pehle';
  return '${d.inDays} din pehle';
}

class Store extends ChangeNotifier {
  List<Entry> blocked = [];
  List<Entry> history = [];
  String apiKey = '';
  bool loaded = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    blocked = _decode(p.getString('blocked_v2'));
    history = _decode(p.getString('history_v2'));
    apiKey = p.getString('api_key') ?? '';
    loaded = true;
    notifyListeners();
  }

  List<Entry> _decode(String? s) {
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'blocked_v2', jsonEncode(blocked.map((e) => e.toJson()).toList()));
    await p.setString(
        'history_v2', jsonEncode(history.map((e) => e.toJson()).toList()));
    await p.setString('api_key', apiKey);
  }

  Entry? findBlocked(String number) {
    final n = last10(number);
    for (final e in blocked) {
      if (e.number == n) return e;
    }
    return null;
  }

  void block(String number, String label) {
    final n = last10(number);
    if (n.length < 10 || findBlocked(n) != null) return;
    blocked.insert(0, Entry(n, label, DateTime.now().millisecondsSinceEpoch));
    notifyListeners();
    _persist();
  }

  void unblock(String number) {
    blocked.removeWhere((e) => e.number == number);
    notifyListeners();
    _persist();
  }

  void addHistory(String number, String verdict) {
    final n = last10(number);
    history.removeWhere((e) => e.number == n);
    history.insert(0, Entry(n, verdict, DateTime.now().millisecondsSinceEpoch));
    if (history.length > 20) history = history.sublist(0, 20);
    notifyListeners();
    _persist();
  }

  void setKey(String k) {
    apiKey = k;
    notifyListeners();
    _persist();
  }

  Future<void> clearAll() async {
    blocked = [];
    history = [];
    apiKey = '';
    notifyListeners();
    await _persist();
  }
}

final store = Store();

Future<String> askAI(String system, List<Map<String, String>> messages) async {
  if (store.apiKey.isEmpty) {
    throw Exception('Pehle AI tab me API key daalo');
  }
  final res = await http.post(
    Uri.parse('https://api.anthropic.com/v1/messages'),
    headers: {
      'content-type': 'application/json',
      'x-api-key': store.apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: jsonEncode({
      'model': 'claude-haiku-4-5-20251001',
      'max_tokens': 600,
      'system': system,
      'messages': messages,
    }),
  );
  final data = jsonDecode(utf8.decode(res.bodyBytes));
  if (res.statusCode != 200) {
    String msg = 'Error ${res.statusCode}';
    if (data is Map && data['error'] is Map) {
      msg = '${data['error']['message']}';
    }
    throw Exception(msg);
  }
  return (data['content'] as List).map((c) => c['text'] ?? '').join();
}
