import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'links.dart';
import 'theme.dart';

/// Today's ayah as a tall picture (9:16, made for WhatsApp Status): Arabic, Malayalam, English, the lesson,
/// and the SIO Connect name, so every share also tells friends about the app.
Future<void> shareAyahImage(BuildContext context, Map<String, dynamic> r) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _ShareSheet(r: r),
);

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.r});
  final Map<String, dynamic> r;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share({bool textOnly = false}) async {
    final r = widget.r;
    final link = Links.share({'q': 'ayah'});
    final text = [
      if ('${r['text_ml'] ?? ''}'.isNotEmpty) '${r['text_ml']}',
      '— ${r['reference'] ?? ''}',
      '\nRead the ayah of the day with SIO Connect: $link',
    ].join('\n');
    if (textOnly) {
      await SharePlus.instance.share(ShareParams(text: text));
      return;
    }
    setState(() => _busy = true);
    try {
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1080 / b.size.width);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png', name: 'ayah-of-the-day.png')],
          text: text,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: h * 0.58,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RepaintBoundary(
                    key: _key,
                    child: AyahPoster(r: widget.r),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.image_outlined),
                label: Text(_busy ? 'Preparing…' : 'Share picture (WhatsApp Status)'),
              ),
            ),
            TextButton(onPressed: () => _share(textOnly: true), child: const Text('Share as text instead')),
          ],
        ),
      ),
    );
  }
}

/// The picture itself; laid out for a 9:16 box of any size (everything scales with the width).
class AyahPoster extends StatelessWidget {
  const AyahPoster({super.key, required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final u = c.maxWidth / 360; // design unit: a 360-wide card
      final ar = '${r['text_ar'] ?? ''}';
      final ml = '${r['text_ml'] ?? ''}';
      final en = '${r['text_en'] ?? ''}';
      final lesson = '${r['lesson_ml'] ?? ''}';
      final long = (ar.length + ml.length) > 420;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A2B4E), Color(0xFF1A62A8), Color(0xFF3B2A8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.fromLTRB(24 * u, 30 * u, 24 * u, 22 * u),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                r['kind'] == 'Hadith' ? 'HADITH OF THE DAY' : 'AYAH OF THE DAY',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11 * u, letterSpacing: 3 * u, fontWeight: FontWeight.w800),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 312 * u,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ar.isNotEmpty)
                          Text(
                            ar,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: arabicStyle(color: Colors.white, size: (long ? 20 : 25) * u),
                          ),
                        SizedBox(height: 14 * u),
                        Container(width: 40 * u, height: 2 * u, color: const Color(0xFFFFD2B3)),
                        SizedBox(height: 14 * u),
                        if (ml.isNotEmpty)
                          Text(
                            ml,
                            textAlign: TextAlign.center,
                            style: malayalamStyle(color: Colors.white, size: (long ? 15 : 18) * u, weight: FontWeight.w700),
                          ),
                        if (en.isNotEmpty) ...[
                          SizedBox(height: 10 * u),
                          Text(
                            '“$en”',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 12.5 * u, height: 1.4),
                          ),
                        ],
                        SizedBox(height: 10 * u),
                        Text(
                          '— ${r['reference'] ?? ''}',
                          style: TextStyle(color: Colors.white, fontSize: 13 * u, fontWeight: FontWeight.w700),
                        ),
                        if (lesson.isNotEmpty) ...[
                          SizedBox(height: 18 * u),
                          Container(
                            padding: EdgeInsets.all(12 * u),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14 * u),
                            ),
                            child: Text(
                              '💡 $lesson',
                              textAlign: TextAlign.center,
                              style: malayalamStyle(color: Colors.white, size: 13.5 * u),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(3 * u),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Image.asset('assets/sio-logo.png', width: 26 * u, height: 26 * u),
                  ),
                  SizedBox(width: 10 * u),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SIO Connect',
                        style: TextStyle(color: Colors.white, fontSize: 14 * u, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Read the ayah of the day with us 🔥',
                        style: TextStyle(color: Colors.white70, fontSize: 10.5 * u),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
