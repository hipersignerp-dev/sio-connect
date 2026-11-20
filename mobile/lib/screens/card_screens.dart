import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../fx.dart';
import '../theme.dart';
import '../widgets.dart';

// The digital SIO membership card, and QR check-in at programmes.

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);

class MemberCardScreen extends StatefulWidget {
  const MemberCardScreen({super.key});

  @override
  State<MemberCardScreen> createState() => _MemberCardScreenState();
}

class _MemberCardScreenState extends State<MemberCardScreen> {
  final _key = GlobalKey();
  bool _flipped = false;

  Future<void> _share(Map<String, dynamic> c) async {
    try {
      final b = _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      final img = await b?.toImage(pixelRatio: 3);
      final data = await img?.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await SharePlus.instance.share(
        ShareParams(
          text: 'My SIO membership card 💙 ${c['unit'] != null ? 'SIO ${c['unit']}' : ''}',
          files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'sio-card.png')],
          fileNameOverrides: const ['sio-card.png'],
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B1E33),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0B1E33),
      foregroundColor: Colors.white,
      title: const Text('My SIO card', style: TextStyle(color: Colors.white)),
    ),
    body: FutureBuilder<dynamic>(
      future: Api.call('${Api.m}member_card'),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('${snap.error}', style: const TextStyle(color: Colors.white70)),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
        final c = _m(snap.data);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _flipped = !_flipped);
              },
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _flipped ? 1 : 0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                builder: (context, t, _) {
                  final showBack = t > 0.5;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(3.14159 * t),
                    child: showBack
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(3.14159),
                            child: _Back(c: c),
                          )
                        : RepaintBoundary(
                            key: _key,
                            child: _Front(c: c),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tap the card to see your QR. Show it at programmes to check in.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: SioColors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                if (_flipped) setState(() => _flipped = false);
                await Future.delayed(const Duration(milliseconds: 550));
                await _share(c);
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('Share my card', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => scanToCheckIn(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Check in at a programme'),
            ),
          ],
        );
      },
    ),
  );
}

class _Front extends StatelessWidget {
  const _Front({required this.c});
  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.586,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E3F70), Color(0xFF1A62A8), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -40,
            child: Opacity(opacity: 0.08, child: Image.asset('assets/sio-logo.png', height: 200)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Image.asset('assets/sio-logo.png', height: 26),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STUDENTS ISLAMIC ORGANISATION',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, letterSpacing: 1.2, fontWeight: FontWeight.w800),
                        ),
                        Text('of India · Membership card', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Avatar('${c['full_name']}', radius: 34, photo: c['photo'], light: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c['full_name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          [c['role'], if (c['unit'] != null) 'SIO ${c['unit']}'].join(' · '),
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          [if (c['area'] != null) '${c['area']} Area', 'since ${c['since']}'].join(' · '),
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${c['member']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.5, fontFamily: 'monospace'),
                  ),
                  const Spacer(),
                  if (numOf(c['programmes']) > 0)
                    Text(
                      '🎟 ${c['programmes']} programmes',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Back extends StatelessWidget {
  const _Back({required this.c});
  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.586,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Row(
        children: [
          QrImageView(
            data: '${c['qr']}',
            size: 150,
            eyeStyle: const QrEyeStyle(color: Color(0xFF0E3F70), eyeShape: QrEyeShape.square),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c['full_name']}',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: SioColors.ink),
                ),
                const SizedBox(height: 4),
                Text('${c['member']}', style: TextStyle(color: SioColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
                Text('Organisers scan this to check you in.', style: TextStyle(fontSize: 12, color: SioColors.text)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Opens the camera and returns the first QR code it sees.
Future<String?> scanQr(BuildContext context, {String title = 'Scan QR code', String? hint}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    builder: (_) => _Scanner(title: title, hint: hint),
  ),
);

class _Scanner extends StatefulWidget {
  const _Scanner({required this.title, this.hint});
  final String title;
  final String? hint;

  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> {
  final _c = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      actions: [IconButton(tooltip: 'Torch', icon: const Icon(Icons.flashlight_on_outlined), onPressed: () => _c.toggleTorch())],
    ),
    body: Stack(
      children: [
        MobileScanner(
          controller: _c,
          onDetect: (cap) {
            if (_done) return;
            final v = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
            if (v == null || v.isEmpty) return;
            _done = true;
            HapticFeedback.mediumImpact();
            Navigator.pop(context, v);
          },
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        if (widget.hint != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              widget.hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    ),
  );
}

/// Student: scan the programme's QR to check in, then celebrate.
Future<void> scanToCheckIn(BuildContext context) async {
  final code = await scanQr(context, title: 'Check in', hint: 'Point at the check-in QR the organisers show');
  if (code == null || !context.mounted) return;
  try {
    final r = _m(await Api.call('${Api.m}checkin', {'code': code}));
    if (!context.mounted) return;
    if (r['already'] == true) {
      toast(context, 'You’re already checked in at ${r['title']} ✅');
      return;
    }
    await celebrate(
      context,
      number: numOf(r['present']).toInt(),
      emoji: '🎟',
      colors: const [Color(0xFF1E8E3E), Color(0xFF1A62A8)],
      title: 'Checked in!',
      subtitle: r['first'] == true
          ? 'Welcome to your first SIO programme: ${r['title']}. You earned a badge 🏅'
          : 'Welcome to ${r['title']}. You’re number ${r['present']} here today.',
    );
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message);
  }
}

/// Organisers: show the programme's check-in QR on screen, see who has arrived, or scan a student's card.
class CheckinHostScreen extends StatefulWidget {
  const CheckinHostScreen({super.key, required this.event});
  final String event;

  @override
  State<CheckinHostScreen> createState() => _CheckinHostScreenState();
}

class _CheckinHostScreenState extends State<CheckinHostScreen> {
  Map<String, dynamic>? _d;
  Timer? _t;
  final List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load({bool fresh = false}) async {
    try {
      final d = _m(await Api.call('${Api.m}checkin_qr', {'event': widget.event, 'new': fresh ? 1 : null}));
      if (mounted) setState(() => _d = d);
    } catch (_) {}
  }

  Future<void> _scanCard() async {
    final code = await scanQr(context, title: 'Scan member card', hint: 'Point at the QR on the student’s SIO card');
    if (code == null || !mounted) return;
    try {
      final r = _m(await Api.call('${Api.m}checkin', {'code': code, 'event': widget.event}));
      HapticFeedback.heavyImpact();
      setState(() => _recent.insert(0, r));
      if (mounted) toast(context, r['already'] == true ? '${r['full_name']} was already in' : '${r['full_name']} checked in ✅');
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: SioColors.background,
      appBar: AppBar(
        title: Text(d == null ? 'Check-in' : '${d['title']}'),
        actions: [
          IconButton(
            tooltip: 'New code (old QR stops working)',
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(fresh: true),
          ),
        ],
      ),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Students open SIO Connect → Check in, and scan this',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SioColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: SioColors.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: QrImageView(data: '${d['qr']}', size: 260),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Pop(
                    trigger: d['present'],
                    child: Text(
                      '${d['present']} checked in',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: SioColors.green),
                    ),
                  ),
                ),
                Center(
                  child: Text('${d['registered']} registered', style: TextStyle(color: SioColors.textSecondary)),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _scanCard,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan a student’s card'),
                ),
                for (final r in _recent)
                  ListTile(
                    leading: Avatar('${r['full_name']}', photo: r['photo'], light: true),
                    title: Text('${r['full_name']}'),
                    subtitle: Text(r['already'] == true ? 'Already checked in' : 'Checked in now'),
                    trailing: Icon(Icons.check_circle, color: SioColors.green),
                  ),
              ],
            ),
    );
  }
}
