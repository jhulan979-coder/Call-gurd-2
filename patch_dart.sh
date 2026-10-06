python3 - << 'PY'
p = 'lib/p2pcall.dart'
s = open(p, encoding='utf-8').read()
n = 0

def rep(a, b):
    global s, n
    if a in s:
        s = s.replace(a, b, 1)
        n += 1
    else:
        print('PATCH MISS: ' + a[:40])

rep("if (mounted) setState(() => _status = s);",
    "if (mounted) { final t = (_status + '\\n' + s).split('\\n'); setState(() => _status = t.sublist(t.length > 7 ? t.length - 7 : 0).join('\\n')); }")
rep("_pc = pc;",
    "_pc = pc;\n    pc.onIceConnectionState = (RTCIceConnectionState s) {\n      _say('ICE: ' + s.toString().split('.').last);\n    };")
rep("_say('Dost ke jawab ka intezaar...');",
    "_say('Dost ke jawab ka intezaar... Mere candidates: ' + cgCand(d?.sdp));")
rep("_send({'t': 'answer', 'sdp': d?.sdp, 'type': d?.type});",
    "_send({'t': 'answer', 'sdp': d?.sdp, 'type': d?.type});\n        _say('Jawab bheja. Mere candidates: ' + cgCand(d?.sdp));")
s += "\nString cgCand(String? sdp) {\n  final ips = <String>[];\n  for (final l in (sdp ?? '').split('\\n')) {\n    if (l.startsWith('a=candidate:')) {\n      final p = l.trim().split(' ');\n      if (p.length > 4) ips.add(p[4]);\n    }\n  }\n  return ips.length.toString() + ' [' + ips.toSet().join(', ') + ']';\n}\n"
open(p, 'w', encoding='utf-8').write(s)
print('P2P DEBUG PATCH OK: ' + str(n))
PY
