import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../links.dart';
import '../noor.dart';
import '../widgets.dart';

int _n(dynamic v) => numOf(v).toInt();

/// "My week" (Monday to today): days read, streak, programmes, photos, reactions, new friends, as a tall picture
/// to share on WhatsApp Status. Every share also tells friends about SIO Connect.
class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key, this.games = true});
  final bool games;

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1080 / b.size.width);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png', name: 'my-sio-week.png')],
          text: 'My week with SIO Connect 🏮 ${Links.share({'q': 'week'})}',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My week')),
    body: Loader<Map<String, dynamic>>(
      load: () async => Map<String, dynamic>.from(await Api.call('${Api.m}week_recap') as Map),
      builder: (context, d) => [
        Center(
          child: SizedBox(
            width: 320,
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: RepaintBoundary(
                  key: _key,
                  child: RecapPoster(d: d, games: widget.games),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const StadiumBorder(),
          ),
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.share),
          label: Text(_busy ? 'Preparing…' : 'Share to WhatsApp Status'),
        ),
      ],
    ),
  );
}

class RecapPoster extends StatelessWidget {
  const RecapPoster({super.key, required this.d, this.games = true});
  final Map<String, dynamic> d;
  final bool games;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final u = c.maxWidth / 320;
      final read = _n(d['days_read']);
      final dow = _n(d['day_of_week']).clamp(1, 7);
      final progs = [for (final p in (d['programmes'] as List? ?? [])) '$p'];
      Widget stat(String big, String small) => Expanded(
        child: Container(
          margin: EdgeInsets.all(4 * u),
          padding: EdgeInsets.symmetric(vertical: 12 * u),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14 * u)),
          child: Column(
            children: [
              Text(
                big,
                style: TextStyle(color: Colors.white, fontSize: 24 * u, fontWeight: FontWeight.w900),
              ),
              Text(
                small,
                style: TextStyle(color: Colors.white70, fontSize: 11 * u),
              ),
            ],
          ),
        ),
      );
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A2B4E), Color(0xFF1A62A8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: EdgeInsets.fromLTRB(18 * u, 22 * u, 18 * u, 16 * u),
          child: Column(
            children: [
              Text(
                'MY WEEK WITH SIO',
                style: TextStyle(color: Colors.white70, fontSize: 11 * u, letterSpacing: 3 * u, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4 * u),
              Text(
                '${d['name'] ?? ''}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18 * u, fontWeight: FontWeight.w800),
              ),
              Text(
                'SIO ${d['unit'] ?? ''}',
                style: TextStyle(color: Colors.white70, fontSize: 12 * u),
              ),
              SizedBox(height: 10 * u),
              Noor(mood: read > 0 ? NoorMood.happy : NoorMood.hello, size: 110 * u, animate: false),
              SizedBox(height: 8 * u),
              // the week's days, lit up for each day read
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 7; i++)
                    Container(
                      width: 26 * u,
                      height: 26 * u,
                      margin: EdgeInsets.symmetric(horizontal: 3 * u),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < read
                            ? const Color(0xFFFFC94D)
                            : (i < dow ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.04)),
                      ),
                      child: Text(
                        'MTWTFSS'[i],
                        style: TextStyle(
                          fontSize: 11 * u,
                          fontWeight: FontWeight.w800,
                          color: i < read ? const Color(0xFF0A2B4E) : Colors.white54,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6 * u),
              Text(
                '$read of 7 days with the ayah of the day',
                style: TextStyle(color: Colors.white, fontSize: 13 * u, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12 * u),
              Row(
                children: [
                  if (games) stat('🔥${_n(d['streak'])}', 'day streak'),
                  stat('${progs.length}', progs.length == 1 ? 'programme' : 'programmes'),
                  stat('${_n(d['photos'])}', 'photos of me'),
                ],
              ),
              Row(children: [stat('${_n(d['reactions'])}', 'reactions'), stat('${_n(d['new_friends'])}', 'new friends')]),
              if (progs.isNotEmpty) ...[
                SizedBox(height: 6 * u),
                Text(
                  progs.take(2).join(' · '),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, fontSize: 11.5 * u),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(3 * u),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Image.asset('assets/sio-logo.png', width: 22 * u, height: 22 * u),
                  ),
                  SizedBox(width: 8 * u),
                  Text(
                    'SIO Connect · join me',
                    style: TextStyle(color: Colors.white, fontSize: 13 * u, fontWeight: FontWeight.w800),
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
