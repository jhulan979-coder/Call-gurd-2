import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

const _p2pPort = 45678;

class P2PCard extends StatelessWidget {
  const P2PCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.videocam_outlined, color: cs.primary),
        ),
        title: const Text('Offline video call (beta)'),
        subtitle: const Text('Bina internet ke paas wale dost se'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const P2PHomePage()),
        ),
      ),
    );
  }
}

class P2PHomePage extends StatefulWidget {
  const P2PHomePage({super.key});

  @override
  State<P2PHomePage> createState() => _P2PHomePageState();
}

class _P2PHomePageState extends State<P2PHomePage> {
  final _ip = TextEditingController();

  Widget _step(String n, String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, child: Text(n, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(child: Text(t)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline video call (beta)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Bina internet ke do paas wale phone ke beech video call. Dono me Call Guard honi chahiye.',
          ),
          const SizedBox(height: 12),
          _step('1', 'Ek phone ka hotspot on karo. Dusra phone uske Wi-Fi se jude.'),
          _step('2', 'Hotspot wala phone "Call shuru karo" dabaye aur screen par dikhne wala IP dusre ko bataye.'),
          _step('3', 'Dusra phone wahi IP neeche daalke "Judo" dabaye.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const P2PCallPage(host: true, ip: ''),
              ),
            ),
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Call shuru karo'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          TextField(
            controller: _ip,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Dost ka IP (jaise 192.168.43.1)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () {
              final ip = _ip.text.trim();
              if (ip.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => P2PCallPage(host: false, ip: ip),
                ),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('Judo'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Dhyan: hotspot na chale to dono phone ek aam Wi-Fi router se jod do (router me internet na ho tab bhi chalega). Phir bhi na jude to host aur join ke role badal ke dekho.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}class P2PCallPage extends StatefulWidget {
  final bool host;
  final String ip;
  const P2PCallPage({super.key, required this.host, required this.ip});

  @override
  State<P2PCallPage> createState() => _P2PCallPageState();
}

class _P2PCallPageState extends State<P2PCallPage> {
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  MediaStream? _stream;
  RTCPeerConnection? _pc;
  ServerSocket? _server;
  Socket? _sock;
  String _status = 'Shuru ho raha hai...';
  List<String> _ips = [];
  bool _muted = false;
  bool _camOff = false;
  bool _speaker = true;
  bool _cleaned = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  void _say(String s) {
    if (mounted) setState(() => _status = s);
  }

  Future<List<String>> _listIps() async {
    final out = <String>[];
    try {
      final list = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final i in list) {
        for (final a in i.addresses) {
          out.add(a.address + '   (' + i.name + ')');
        }
      }
    } catch (_) {}
    return out;
  }

  Future<void> _start() async {
    try {
      await _local.initialize();
      await _remote.initialize();
      _stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      _local.srcObject = _stream;
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}
    } catch (e) {
      _say('Camera ya mic ki permission nahi mili');
      return;
    }
    if (mounted) setState(() {});
    if (widget.host) {
      await _startHost();
    } else {
      await _startGuest();
    }
  }

  Future<void> _startHost() async {
    final ips = await _listIps();
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, _p2pPort);
    } catch (e) {
      _say('Connection khola nahi ja saka. App band karke dobara kholo');
      return;
    }
    if (mounted) {
      setState(() {
        _ips = ips;
        _status = 'Dost ke judne ka intezaar...';
      });
    }
    _server!.listen((c) {
      if (_sock != null) {
        c.destroy();
        return;
      }
      _sock = c;
      _listen(c);
      _hostOffer();
    });
  }

  Future<void> _startGuest() async {
    _say('Judne ki koshish...');
    try {
      final s = await Socket.connect(
        widget.ip.trim(),
        _p2pPort,
        timeout: const Duration(seconds: 8),
      );
      _sock = s;
      _listen(s);
      _say('Judaa, call set ho rahi hai...');
    } catch (e) {
      _say('Judne me dikkat. IP aur hotspot check karo');
    }
  }

  void _listen(Socket s) {
    utf8.decoder.bind(s).transform(const LineSplitter()).listen(
      (l) {
        _onLine(l);
      },
      onDone: () {
        _say('Connection toot gaya');
      },
      onError: (_) {},
    );
  }

  void _send(Map<String, dynamic> m) {
    try {
      _sock?.write(jsonEncode(m) + '\n');
    } catch (_) {}
  }

  Future<void> _newPc() async {
    final pc = await createPeerConnection({
      'iceServers': <Map<String, dynamic>>[],
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    for (final t in _stream!.getTracks()) {
      await pc.addTrack(t, _stream!);
    }
    pc.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty && mounted) {
        setState(() {
          _remote.srcObject = e.streams[0];
        });
      }
    };
    pc.onConnectionState = (RTCPeerConnectionState s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _say('Call chal rahi hai');
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _say('Connection nahi bana. Hotspot ya Wi-Fi badal ke dekho');
      } else if (s ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _say('Call khatam');
      }
    };
  }

  Future<void> _hostOffer() async {
    try {
      _say('Call set ho rahi hai...');
      await _newPc();
      final done = Completer<void>();
      _pc!.onIceGatheringState = (RTCIceGatheringState s) {
        if (s == RTCIceGatheringState.RTCIceGatheringStateComplete &&
            !done.isCompleted) {
          done.complete();
        }
      };
      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await _pc!.setLocalDescription(offer);
      await done.future.timeout(const Duration(seconds: 4), onTimeout: () {});
      final d = await _pc!.getLocalDescription();
      _send({'t': 'offer', 'sdp': d?.sdp, 'type': d?.type});
      _say('Dost ke jawab ka intezaar...');
    } catch (e) {
      _say('Dikkat: ' + e.toString());
    }
  }

  Future<void> _onLine(String l) async {
    try {
      final m = jsonDecode(l) as Map<String, dynamic>;
      final t = m['t'];
      if (t == 'offer' && !widget.host) {
        _say('Call set ho rahi hai...');
        await _newPc();
        await _pc!.setRemoteDescription(
          RTCSessionDescription(m['sdp'] as String?, m['type'] as String?),
        );
        final done = Completer<void>();
        _pc!.onIceGatheringState = (RTCIceGatheringState s) {
          if (s == RTCIceGatheringState.RTCIceGatheringStateComplete &&
              !done.isCompleted) {
            done.complete();
          }
        };
        final ans = await _pc!.createAnswer();
        await _pc!.setLocalDescription(ans);
        await done.future
            .timeout(const Duration(seconds: 4), onTimeout: () {});
        final d = await _pc!.getLocalDescription();
        _send({'t': 'answer', 'sdp': d?.sdp, 'type': d?.type});
      } else if (t == 'answer' && widget.host) {
        await _pc!.setRemoteDescription(
          RTCSessionDescription(m['sdp'] as String?, m['type'] as String?),
        );
        _say('Judne ki koshish...');
      } else if (t == 'bye') {
        _say('Dost ne call kaat di');
        _hangup(false);
      }
    } catch (e) {
      _say('Dikkat: ' + e.toString());
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    for (final t in _stream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !_muted;
    }
  }

  void _toggleCam() {
    setState(() => _camOff = !_camOff);
    for (final t in _stream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !_camOff;
    }
  }

  Future<void> _switchCam() async {
    final v = _stream?.getVideoTracks();
    if (v != null && v.isNotEmpty) {
      try {
        await Helper.switchCamera(v.first);
      } catch (_) {}
    }
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _speaker = !_speaker);
    try {
      await Helper.setSpeakerphoneOn(_speaker);
    } catch (_) {}
  }

  Future<void> _hangup(bool notify) async {
    if (notify) {
      _send({'t': 'bye'});
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _cleanup();
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  void _cleanup() {
    if (_cleaned) return;
    _cleaned = true;
    try {
      _sock?.destroy();
    } catch (_) {}
    try {
      _server?.close();
    } catch (_) {}
    try {
      _pc?.close();
    } catch (_) {}
    try {
      for (final t in _stream?.getTracks() ?? <MediaStreamTrack>[]) {
        t.stop();
      }
    } catch (_) {}
    try {
      _stream?.dispose();
    } catch (_) {}
    try {
      _local.srcObject = null;
      _remote.srcObject = null;
    } catch (_) {}
    try {
      _local.dispose();
      _remote.dispose();
    } catch (_) {}
  }

  Widget _btn(IconData icon, bool on, VoidCallback f, {Color? color}) {
    return IconButton.filled(
      onPressed: f,
      style: IconButton.styleFrom(
        backgroundColor: color ?? (on ? Colors.white : Colors.white24),
        foregroundColor: color != null
            ? Colors.white
            : (on ? Colors.black : Colors.white),
        minimumSize: const Size(56, 56),
      ),
      icon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRemote = _remote.srcObject != null;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _hangup(true);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              if (hasRemote)
                Positioned.fill(
                  child: RTCVideoView(
                    _remote,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              if (!hasRemote)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_tethering,
                            size: 64, color: Colors.white70),
                        const SizedBox(height: 16),
                        Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18),
                        ),
                        if (widget.host && _ips.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Dost ko ye IP batao (bracket wala hissa chhodke):',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          for (final ip in _ips)
                            SelectableText(
                              ip,
                              style: const TextStyle(
                                  color: Colors.lightBlueAccent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (hasRemote)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_status,
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              Positioned(
                top: 12,
                right: 12,
                width: 100,
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(
                    _local,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _btn(_muted ? Icons.mic_off : Icons.mic, _muted, _toggleMute),
                    _btn(_camOff ? Icons.videocam_off : Icons.videocam, _camOff,
                        _toggleCam),
                    _btn(Icons.cameraswitch, false, _switchCam),
                    _btn(_speaker ? Icons.volume_up : Icons.volume_down,
                        _speaker, _toggleSpeaker),
                    _btn(Icons.call_end, false, () => _hangup(true),
                        color: Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
