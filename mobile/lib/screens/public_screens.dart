import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../theme.dart';
import '../app_state.dart';
import '../widgets.dart';
import 'auth_screens.dart';
import 'donors_screen.dart';

/// The first screen for anyone not signed in: who SIO is, mission and vision, the area leaders (call /
/// WhatsApp), programmes, objectives, a hadith on giving with Donate, units and social media.
/// Sign in and Register sit in the header.
class PublicScreen extends StatelessWidget {
  const PublicScreen({super.key, this.landing = false});
  final bool landing;

  @override
  Widget build(BuildContext context) {
    final notice = AppState.i.notice;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _P.paper,
        body: Loader<Map<String, dynamic>>(
          padding: EdgeInsets.zero,
          load: () async => Map<String, dynamic>.from(await Api.guest('info') as Map),
          builder: (context, d) {
            final events = (d['events'] as List?) ?? [];
            final leaders = (d['leaders'] as List?) ?? [];
            final units = (d['units'] as List?) ?? [];
            final vision = (d['vision'] as List?) ?? [];
            final objectives = (d['objectives'] as List?) ?? [];
            final hadith = d['hadith'] as Map?;
            final canDonate = d['can_donate'] == true;
            void donate() => push(context, DonateScreen(minAmount: numOf(d['min_donation']), hadith: hadith));
            var n = 0;
            String next() => (++n).toString().padLeft(2, '0');
            return [
              _Hero(
                name: '${d['org_name'] ?? 'SIO'}',
                intro: '${d['intro'] ?? ''}',
                landing: landing,
                canDonate: canDonate,
                donate: donate,
              ),
              Transform.translate(
                offset: const Offset(0, -34),
                child: _Stats(units: units.length, programmes: events.length),
              ),
              if (landing && notice != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SioBanner(text: notice),
                ),
              if ('${d['mission'] ?? ''}'.isNotEmpty) ...[
                _Heading(no: next(), kicker: 'Our mission', title: 'Why we exist'),
                _Mission(text: '${d['mission']}'),
              ],
              if (vision.isNotEmpty) ...[
                _Heading(no: next(), kicker: 'Our vision', title: 'A complete way of life', sub: '${d['vision_intro'] ?? ''}'),
                _Vision(points: vision),
              ],
              if (leaders.isNotEmpty) ...[
                _Heading(no: next(), kicker: 'Area leadership', title: 'Talk to us'),
                _Leaders(leaders: leaders),
              ],
              _Heading(no: next(), kicker: 'Upcoming', title: 'Programmes'),
              _Programmes(events: events),
              if (objectives.isNotEmpty) ...[
                _Heading(no: next(), kicker: 'What we work for', title: 'Our objectives'),
                _Objectives(items: objectives),
              ],
              const SizedBox(height: 28),
              _Giving(hadith: hadith, canDonate: canDonate, donate: donate),
              if (units.isNotEmpty) ...[
                _Heading(no: next(), kicker: 'Across Ottapalam', title: 'Our units'),
                _Units(units: units),
              ],
              const SizedBox(height: 28),
              _Footer(name: '${d['org_name'] ?? 'SIO'}', social: Map<String, dynamic>.from((d['social'] as Map?) ?? {})),
            ];
          },
        ),
      ),
    );
  }
}

/// Page palette: deep navy, SIO red, a warm gold for scripture, and off-white paper.
class _P {
  static const navy = Color(0xFF0B1F3A);
  static const navy2 = Color(0xFF14325C);
  static const red = Color(0xFFD32F2F);
  static const gold = Color(0xFFD4A84B);
  static const paper = Color(0xFFF7F5F0);
  static const ink = Color(0xFF14181F);
  static const muted = Color(0xFF5E6672);
  static const line = Color(0xFFE4E0D6);
}

Future<void> _open(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) toast(context, 'Could not open the link.');
}

/// A quiet geometric lattice of eight-point stars, drawn behind the dark bands.
class _Pattern extends CustomPainter {
  const _Pattern({this.opacity = 0.07});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 56.0;
    const r = 18.0;
    for (double y = -step; y < size.height + step; y += step) {
      for (double x = -step; x < size.width + step; x += step) {
        final c = Offset(x + ((y / step).round().isOdd ? step / 2 : 0), y);
        canvas.drawRect(Rect.fromCenter(center: c, width: r * 2, height: r * 2), p);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(0.785398);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2), p);
        canvas.restore();
        canvas.drawCircle(c, r * 0.45, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Pattern old) => old.opacity != opacity;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.intro, required this.landing, required this.canDonate, required this.donate});
  final String name;
  final String intro;
  final bool landing;
  final bool canDonate;
  final VoidCallback donate;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_P.navy, _P.navy2]),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _Pattern())),
          Positioned(
            right: -60,
            top: top + 40,
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/sio-logo.png',
                width: 240,
                height: 240,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 8, 20, 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header bar
                Row(
                  children: [
                    if (!landing)
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Image.asset('assets/sio-logo.png', width: 34, height: 34),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'SIO Connect',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                      ),
                    ),
                    if (landing) ...[
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: () => push(context, const RegisterScreen()),
                        child: const Text('Register'),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _P.navy,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => push(context, const LoginScreen()),
                        child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Container(width: 24, height: 3, color: _P.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name.toUpperCase(),
                        style: const TextStyle(color: _P.gold, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 2.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                    children: [
                      TextSpan(text: 'Study'),
                      TextSpan(
                        text: '.\n',
                        style: TextStyle(color: _P.red),
                      ),
                      TextSpan(text: 'Struggle'),
                      TextSpan(
                        text: '.\n',
                        style: TextStyle(color: _P.red),
                      ),
                      TextSpan(text: 'Service'),
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: _P.red),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  intro.isEmpty ? 'Students Islamic Organisation of India' : intro,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 15.5, height: 1.5),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _P.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: canDonate ? donate : null,
                        icon: const Icon(Icons.volunteer_activism, size: 20),
                        label: const Text('Donate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => push(context, const RegisterScreen()),
                        child: const Text('Join SIO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.units, required this.programmes});
  final int units;
  final int programmes;

  @override
  Widget build(BuildContext context) {
    Widget cell(String v, String l) => Expanded(
      child: Column(
        children: [
          Text(
            v,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _P.navy),
          ),
          const SizedBox(height: 2),
          Text(
            l,
            style: const TextStyle(fontSize: 12, color: _P.muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    Widget rule() => Container(width: 1, height: 34, color: _P.line);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _P.navy.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          cell('$units', units == 1 ? 'Unit' : 'Units'),
          rule(),
          cell(programmes == 0 ? '—' : '$programmes', 'Upcoming'),
          rule(),
          cell('1982', 'Since'),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.no, required this.kicker, required this.title, this.sub = ''});
  final String no;
  final String kicker;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              no,
              style: const TextStyle(color: _P.red, fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 1),
            ),
            const SizedBox(width: 8),
            Container(width: 18, height: 1.5, color: _P.red),
            const SizedBox(width: 8),
            Text(
              kicker.toUpperCase(),
              style: const TextStyle(color: _P.muted, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 1.8),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(color: _P.ink, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(sub, style: const TextStyle(color: _P.muted, fontSize: 15, height: 1.5)),
        ],
      ],
    ),
  );
}

class _Mission extends StatelessWidget {
  const _Mission({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(color: _P.red, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _P.navy, fontSize: 21, height: 1.4, fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Vision extends StatelessWidget {
  const _Vision({required this.points});
  final List points;

  static const _icons = [Icons.auto_stories_outlined, Icons.forum_outlined, Icons.lightbulb_outline, Icons.flag_outlined];

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _P.line),
    ),
    child: Column(
      children: [
        for (var i = 0; i < points.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 20, endIndent: 20, color: _P.line),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: _P.navy, borderRadius: BorderRadius.circular(14)),
                  child: Icon(_icons[i % _icons.length], color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${points[i]['title']}',
                        style: const TextStyle(color: _P.ink, fontSize: 16.5, fontWeight: FontWeight.w800),
                      ),
                      if ('${points[i]['text'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('${points[i]['text']}', style: const TextStyle(color: _P.muted, height: 1.5, fontSize: 14)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _Leaders extends StatelessWidget {
  const _Leaders({required this.leaders});
  final List leaders;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final l in leaders)
              SizedBox(
                width: w,
                child: _Leader(l: Map<String, dynamic>.from(l)),
              ),
          ],
        );
      },
    ),
  );
}

class _Leader extends StatelessWidget {
  const _Leader({required this.l});
  final Map<String, dynamic> l;

  @override
  Widget build(BuildContext context) {
    final phone = '${l['phone'] ?? ''}';
    final photo = '${l['photo'] ?? ''}';
    final name = '${l['leader_name']}';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _P.navy.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 4.6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                photo.isNotEmpty
                    ? Image.network(
                        '${Api.baseUrl}$photo',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, _, _) => _initial(name),
                      )
                    : _initial(name),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.55, 1],
                      colors: [Colors.transparent, Color(0xDD0B1F3A)],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${l['designation'] ?? ''}'.toUpperCase(),
                        style: const TextStyle(color: _P.gold, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: _Pill(icon: Icons.call, label: 'Call', color: _P.navy, onTap: () => callNumber(context, phone)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Pill(
                      icon: Icons.chat,
                      label: 'WhatsApp',
                      color: const Color(0xFF1E9E54),
                      onTap: () => whatsApp(context, phone, 'Assalamu alaikum $name, '),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _initial(String name) => Container(
    color: _P.navy2,
    alignment: Alignment.center,
    child: Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Programmes extends StatelessWidget {
  const _Programmes({required this.events});
  final List events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.line),
        ),
        child: const Row(
          children: [
            Icon(Icons.event_available_outlined, color: _P.muted),
            SizedBox(width: 12),
            Expanded(
              child: Text('No public programmes announced right now. Check back soon.', style: TextStyle(color: _P.muted)),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: events.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final e = Map<String, dynamic>.from(events[i]);
          final d = parseDate(e['starts_on']);
          final width = events.length == 1 ? MediaQuery.sizeOf(context).width - 40 : 270.0;
          return Container(
            width: width,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _P.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (d != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: _P.navy, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Text(
                              '${d.day}',
                              style: const TextStyle(color: Colors.white, fontSize: 22, height: 1, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM').format(d).toUpperCase(),
                              style: const TextStyle(color: _P.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (d != null)
                            Text(
                              DateFormat('EEEE · h:mm a').format(d),
                              style: const TextStyle(color: _P.red, fontWeight: FontWeight.w800, fontSize: 12.5),
                            ),
                          if ('${e['unit'] ?? ''}'.isNotEmpty)
                            Text('${e['unit']} unit', style: const TextStyle(color: _P.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${e['title']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _P.ink, fontSize: 17, height: 1.25, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if ('${e['venue'] ?? ''}'.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 16, color: _P.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${e['venue']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _P.muted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Objectives extends StatelessWidget {
  const _Objectives({required this.items});
  final List items;

  static const _icons = [
    Icons.campaign_outlined,
    Icons.menu_book_outlined,
    Icons.favorite_border,
    Icons.balance_outlined,
    Icons.school_outlined,
    Icons.auto_awesome_outlined,
  ];

  void _show(BuildContext context, int i) {
    final o = items[i];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OBJECTIVE ${(i + 1).toString().padLeft(2, '0')}',
                style: const TextStyle(color: _P.red, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.6),
              ),
              const SizedBox(height: 6),
              Text(
                '${o['title']}',
                style: const TextStyle(color: _P.ink, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text('${o['text']}', style: const TextStyle(color: _P.muted, fontSize: 15.5, height: 1.55)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: w,
                height: 150,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _show(context, i),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _P.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(_icons[i % _icons.length], color: _P.navy, size: 26),
                              const Spacer(),
                              Text(
                                (i + 1).toString().padLeft(2, '0'),
                                style: const TextStyle(color: _P.line, fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '${items[i]['title']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _P.ink, fontSize: 15, height: 1.25, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Text(
                                'Read more',
                                style: TextStyle(color: _P.red, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.arrow_forward, size: 14, color: _P.red),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _Giving extends StatelessWidget {
  const _Giving({required this.hadith, required this.canDonate, required this.donate});
  final Map? hadith;
  final bool canDonate;
  final VoidCallback donate;

  @override
  Widget build(BuildContext context) => Container(
    color: _P.navy,
    child: Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _Pattern(opacity: 0.06))),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'SUPPORT OUR WORK',
                textAlign: TextAlign.center,
                style: TextStyle(color: _P.gold, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 2.2),
              ),
              const SizedBox(height: 18),
              if (hadith != null) ...[
                const Text(
                  '“',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _P.gold, fontSize: 64, height: 0.8),
                ),
                Text(
                  '${hadith!['text']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 20, height: 1, color: _P.gold),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${hadith!['source'] ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _P.gold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(width: 20, height: 1, color: _P.gold),
                  ],
                ),
                const SizedBox(height: 22),
              ],
              Text(
                'Your support funds student programmes, camps, relief and community service across our units.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.5),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _P.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: canDonate ? donate : null,
                icon: const Icon(Icons.volunteer_activism),
                label: Text(
                  canDonate ? 'Donate with UPI' : 'Online donation coming soon',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Units extends StatelessWidget {
  const _Units({required this.units});
  final List units;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final u in units)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _P.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: _P.red, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  '${u['name']}',
                  style: const TextStyle(color: _P.ink, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.name, required this.social});
  final String name;
  final Map<String, dynamic> social;

  @override
  Widget build(BuildContext context) {
    final links = <(IconData, String, String)>[
      if (social['instagram'] != null) (Icons.camera_alt_outlined, 'Instagram', 'https://instagram.com/${social['instagram']}'),
      if (social['threads'] != null) (Icons.alternate_email, 'Threads', 'https://www.threads.net/@${social['threads']}'),
      if (social['facebook'] != null) (Icons.facebook, 'Facebook', '${social['facebook']}'),
      if (social['youtube'] != null) (Icons.smart_display_outlined, 'YouTube', '${social['youtube']}'),
      if (social['whatsapp_channel'] != null) (Icons.chat_outlined, 'WhatsApp', '${social['whatsapp_channel']}'),
      if (social['website'] != null) (Icons.language, 'Website', '${social['website']}'),
    ];
    return Container(
      color: _P.ink,
      padding: EdgeInsets.fromLTRB(24, 32, 24, 28 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Image.asset('assets/sio-logo.png', width: 48, height: 48),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Students Islamic Organisation of India',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
          ),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final x in links)
                  Tooltip(
                    message: x.$2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _open(context, x.$3),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Icon(x.$1, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
            if ((social['instagram'] ?? social['threads']) != null) const SizedBox(height: 8),
            if ((social['instagram'] ?? social['threads']) != null)
              Text(
                '@${social['instagram'] ?? social['threads']}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
              ),
          ],
          const SizedBox(height: 24),
          Divider(color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 10),
          Text(
            'SIO Connect · Powered by Hipersign ERP',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// A visitor donates: details, then pay with any UPI app, then give the UPI reference so SIO can confirm it.
class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key, this.minAmount = 10, this.hadith});
  final num minAmount;
  final Map? hadith;

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _place = TextEditingController();
  final _amount = TextEditingController();
  final _utr = TextEditingController();
  Map<String, dynamic>? _donation; // after the donation is recorded
  bool _busy = false;
  bool _done = false;

  Future<void> _start() async {
    final amount = num.tryParse(_amount.text.trim()) ?? 0;
    if (amount < widget.minAmount) {
      toast(context, 'The smallest donation is ${inr(widget.minAmount)}.');
      return;
    }
    setState(() => _busy = true);
    try {
      final d = Map<String, dynamic>.from(
        await Api.guest('donate', {
          'full_name': _name.text.trim(),
          'mobile': _mobile.text.trim(),
          'place': _place.text.trim(),
          'amount': _amount.text.trim(),
        }) as Map,
      );
      setState(() => _donation = d);
      await _openUpi();
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openUpi() async {
    final d = _donation!;
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': '${d['upi_id']}',
        'pn': '${d['payee']}',
        'am': numOf(d['amount']).toStringAsFixed(2),
        'cu': 'INR',
        'tn': '${d['note']}',
      },
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) {
      toast(context, 'No UPI app found. Pay ${inr(d['amount'])} to ${d['upi_id']} and enter the reference below.');
    }
  }

  Future<void> _paid() async {
    setState(() => _busy = true);
    try {
      await Api.guest('donation_paid', {
        'ref': _donation!['ref'],
        'mobile': _mobile.text.trim(),
        'payment_ref': _utr.text.trim(),
      });
      setState(() => _done = true);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = _donation;
    return Scaffold(
      appBar: AppBar(title: const Text('Donate to SIO')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_done) ...[
            const SizedBox(height: 40),
            const Icon(Icons.check_circle, size: 72, color: SioColors.green),
            const SizedBox(height: 16),
            const Text(
              'Jazakallah khair!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'SIO will confirm your donation of ${inr(d!['amount'])} once the payment is matched. Reference ${d['ref']}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: SioColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ] else if (d == null) ...[
            if (widget.hadith != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: SioColors.warningBg, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Text(
                      '"${widget.hadith!['text']}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SioColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.hadith!['source'] ?? ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: SioColors.warning, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _place,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Place (optional)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final a in const [100, 500, 1000, 5000])
                  ActionChip(label: Text(inr(a)), onPressed: () => setState(() => _amount.text = '$a')),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Pay with UPI'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Opens GPay, PhonePe, Paytm or any UPI app with the amount filled in.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
            ),
          ] else ...[
            SioPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Pay ${inr(d['amount'])} to', style: const TextStyle(color: SioColors.textSecondary)),
                  const SizedBox(height: 4),
                  SelectableText('${d['upi_id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openUpi,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open UPI app again'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('After paying, enter the UPI reference (UTR / transaction ID) from your payment app.'),
            const SizedBox(height: 10),
            TextField(
              controller: _utr,
              decoration: const InputDecoration(labelText: 'UPI reference'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _paid, child: const Text("I've paid")),
          ],
        ],
      ),
    );
  }
}
