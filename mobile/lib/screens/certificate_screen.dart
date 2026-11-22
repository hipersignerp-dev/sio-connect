import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);

/// Under a programme I attended: rate it (1-5 stars + a comment) and get my participation certificate.
/// Leaders see the average and the comments.
class ProgrammeAfter extends StatefulWidget {
  const ProgrammeAfter({super.key, required this.e});
  final Map<String, dynamic> e;

  @override
  State<ProgrammeAfter> createState() => _ProgrammeAfterState();
}

class _ProgrammeAfterState extends State<ProgrammeAfter> {
  late int _stars = numOf(widget.e['my_rating']).toInt();
  late final _comment = TextEditingController(text: '${widget.e['my_comment'] ?? ''}');
  late bool _saved = _stars > 0;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(
      context,
      () => Api.call('${Api.m}rate_event', {'event': widget.e['name'], 'rating': _stars, 'comment': _comment.text.trim()}),
      done: 'Thank you for the feedback 🙏',
    );
    if (mounted) {
      setState(() {
        _busy = false;
        if (ok) _saved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final r = e['ratings'] == null ? null : _m(e['ratings']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e['can_rate'] == 1) ...[
          const SectionTitle('How was it?'),
          SioPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => setState(() {
                          _stars = i;
                          _saved = false;
                        }),
                        icon: Icon(
                          i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 34,
                          color: const Color(0xFFF2A93B),
                        ),
                      ),
                  ],
                ),
                if (_stars > 0) ...[
                  TextField(
                    controller: _comment,
                    minLines: 1,
                    maxLines: 4,
                    onChanged: (_) => setState(() => _saved = false),
                    decoration: const InputDecoration(hintText: 'What did you like? What can be better? (optional)'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _saved
                        ? Text(
                            '✓ Sent',
                            style: TextStyle(color: SioColors.green, fontWeight: FontWeight.w700),
                          )
                        : FilledButton(onPressed: _busy ? null : _save, child: const Text('Send')),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (e['certificate'] != null) ...[
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => push(context, CertificateScreen(e: e)),
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('My participation certificate'),
          ),
        ],
        if (r != null && numOf(r['count']) > 0) ...[
          const SectionTitle('Feedback from participants'),
          SioPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⭐ ${r['average']} average · ${r['count']} rating${numOf(r['count']) == 1 ? '' : 's'}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: SioColors.ink),
                ),
                for (final c in (r['comments'] as List? ?? []).map(_m))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('“${c['comment']}” · ${c['full_name'] ?? ''}', style: TextStyle(color: SioColors.text)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The certificate as a picture (A4-like landscape), to save or share.
class CertificateScreen extends StatefulWidget {
  const CertificateScreen({super.key, required this.e});
  final Map<String, dynamic> e;

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2000 / b.size.width);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png', name: 'SIO-certificate.png')],
          text: 'Participation certificate: ${widget.e['title']}',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Certificate')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 1.414,
          child: RepaintBoundary(
            key: _key,
            child: Certificate(e: widget.e),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.download),
          label: Text(_busy ? 'Preparing…' : 'Save or share'),
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: choose “Save to Files” or Drive in the share menu to keep it with your documents.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
        ),
      ],
    ),
  );
}

class Certificate extends StatelessWidget {
  const Certificate({super.key, required this.e});
  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final u = c.maxWidth / 600;
      final cert = _m(e['certificate']);
      final d = parseDate(e['starts_on']);
      const navy = Color(0xFF0E3F70);
      const gold = Color(0xFFC9962B);
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Container(
          color: const Color(0xFFFFFDF7),
          padding: EdgeInsets.all(12 * u),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: gold, width: 3 * u),
            ),
            padding: EdgeInsets.all(4 * u),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: navy, width: 1.2 * u),
              ),
              padding: EdgeInsets.symmetric(horizontal: 28 * u, vertical: 18 * u),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/sio-logo.png', height: 42 * u),
                      SizedBox(width: 10 * u),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Students Islamic Organisation of India',
                            style: TextStyle(fontSize: 12 * u, fontWeight: FontWeight.w800, color: navy),
                          ),
                          Text(
                            'SIO ${cert['area'] ?? 'Ottapalam'} Area',
                            style: TextStyle(fontSize: 10.5 * u, color: navy),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 14 * u),
                  Text(
                    'CERTIFICATE OF PARTICIPATION',
                    style: TextStyle(fontSize: 20 * u, fontWeight: FontWeight.w900, color: navy, letterSpacing: 2 * u),
                  ),
                  SizedBox(height: 4 * u),
                  Container(width: 120 * u, height: 2 * u, color: gold),
                  SizedBox(height: 14 * u),
                  Text(
                    'This is to certify that',
                    style: TextStyle(fontSize: 12 * u, color: const Color(0xFF444444)),
                  ),
                  SizedBox(height: 6 * u),
                  Text(
                    '${cert['full_name'] ?? ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26 * u, fontWeight: FontWeight.w800, color: const Color(0xFF1F1F23)),
                  ),
                  if ('${cert['unit'] ?? ''}'.isNotEmpty)
                    Text(
                      'SIO ${cert['unit']}',
                      style: TextStyle(fontSize: 11 * u, color: const Color(0xFF666666)),
                    ),
                  SizedBox(height: 8 * u),
                  Text(
                    'participated in',
                    style: TextStyle(fontSize: 12 * u, color: const Color(0xFF444444)),
                  ),
                  SizedBox(height: 4 * u),
                  Text(
                    '${e['title'] ?? ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18 * u, fontWeight: FontWeight.w800, color: navy),
                  ),
                  Text(
                    [
                      if (d != null) DateFormat('d MMMM yyyy').format(d),
                      if ('${e['venue'] ?? ''}'.isNotEmpty) '${e['venue']}',
                    ].join(' · '),
                    style: TextStyle(fontSize: 11 * u, color: const Color(0xFF444444)),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Certificate no. ${cert['code'] ?? ''}\nIssued through SIO Connect',
                        style: TextStyle(fontSize: 8.5 * u, color: const Color(0xFF777777)),
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          Container(width: 120 * u, height: 1 * u, color: const Color(0xFF555555)),
                          SizedBox(height: 3 * u),
                          Text(
                            'Area President',
                            style: TextStyle(fontSize: 10 * u, color: const Color(0xFF444444)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
