import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'card_screens.dart';
import 'event_detail_screen.dart';

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);
List<Map<String, dynamic>> _l(dynamic v) => [for (final x in (v as List? ?? [])) _m(x)];

/// The Programmes tab: every programme the person can join (unit, area), grouped by when, with one-tap "I'll go",
/// check-in by QR and inviting a friend.
class ProgrammesScreen extends StatefulWidget {
  const ProgrammesScreen({super.key});

  @override
  State<ProgrammesScreen> createState() => _ProgrammesScreenState();
}

class _ProgrammesScreenState extends State<ProgrammesScreen> {
  String _scope = 'all'; // all | unit | area

  Future<void> _invite() async {
    await run(context, () async {
      final j = _m(await Api.call('${Api.m}journey'));
      await SharePlus.instance.share(ShareParams(text: '${j['invite_text']}'));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEFF6FD),
    appBar: AppBar(
      backgroundColor: const Color(0xFFEFF6FD),
      surfaceTintColor: const Color(0xFFEFF6FD),
      automaticallyImplyLeading: false,
      title: const Text('Programmes', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [
        IconButton(
          tooltip: 'My SIO card',
          icon: const Icon(Icons.badge_outlined),
          onPressed: () => push(context, const MemberCardScreen()),
        ),
        IconButton(tooltip: 'Check in with QR', icon: const Icon(Icons.qr_code_scanner), onPressed: () => scanToCheckIn(context)),
        IconButton(tooltip: 'Invite a friend', icon: const Icon(Icons.person_add_alt), onPressed: _invite),
      ],
    ),
    body: Loader<List<dynamic>>(
      cacheKey: 'programmes',
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      load: () async => (await Api.call('${Api.m}events', {'limit': 80})) as List<dynamic>,
      builder: (context, raw) {
        final unit = '${AppState.i.me['unit'] ?? ''}';
        final all = _l(raw).where((e) {
          final u = '${e['unit'] ?? ''}';
          return switch (_scope) {
            'unit' => u.isNotEmpty && u == unit,
            'area' => u.isEmpty,
            _ => true,
          };
        }).toList();
        final now = DateTime.now();
        final weekEnd = DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
        final upcoming = all
            .where(
              (e) =>
                  e['status'] != 'Completed' &&
                  (parseDate(e['starts_on'])?.isAfter(now.subtract(const Duration(hours: 6))) ?? true),
            )
            .toList();
        final soon = upcoming.where((e) => (parseDate(e['starts_on']) ?? weekEnd).isBefore(weekEnd)).toList();
        final later = upcoming.where((e) => !soon.contains(e)).toList();
        final past = all.where((e) => !upcoming.contains(e)).toList().reversed.toList();
        return [
          Wrap(
            spacing: 8,
            children: [
              for (final c in [('all', 'All'), ('unit', 'My unit'), ('area', 'Area-wide')])
                ChoiceChip(
                  label: Text(c.$2),
                  selected: _scope == c.$1,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _scope = c.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 38)),
                  const SizedBox(height: 8),
                  Text(
                    'No programmes planned yet. Your unit will post them here, and you’ll get a notice.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SioColors.textSecondary),
                  ),
                ],
              ),
            ),
          if (soon.isNotEmpty) ...[const _Label('This week'), for (final e in soon) _ProgrammeRow(e: e)],
          if (later.isNotEmpty) ...[const _Label('Coming up'), for (final e in later) _ProgrammeRow(e: e)],
          if (past.isNotEmpty) ...[const _Label('Recent'), for (final e in past.take(10)) _ProgrammeRow(e: e, past: true)],
        ];
      },
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.t);
  final String t;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 0, 8),
    child: Text(
      t,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SioColors.ink),
    ),
  );
}

class _ProgrammeRow extends StatefulWidget {
  const _ProgrammeRow({required this.e, this.past = false});
  final Map<String, dynamic> e;
  final bool past;

  @override
  State<_ProgrammeRow> createState() => _ProgrammeRowState();
}

class _ProgrammeRowState extends State<_ProgrammeRow> {
  late bool _going = '${widget.e['my_registration'] ?? ''}'.isNotEmpty;
  late int _count = numOf(widget.e['registered_count']).toInt();
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    final was = _going;
    final ok = await run(
      context,
      () => Api.call('${Api.m}register_event', {'event': widget.e['name'], 'cancel': was ? 1 : 0}),
      done: was ? 'Okay, you’re not going' : 'See you there! 🙌',
    );
    if (mounted) {
      setState(() {
        _busy = false;
        if (ok) {
          _going = !was;
          _count += was ? -1 : 1;
        }
      });
    }
  }

  static const _deep = Color(0xFF0E3F70);
  static const _sio = Color(0xFF1A62A8);
  static const _mid = Color(0xFF2F7BC4);
  static const _light = Color(0xFF5AA6E8);
  static const _grey = Color(0xFF5B6B7C);

  /// A picture for the kind of programme, from its type or title.
  static String _emoji(Map e) {
    final t = '${e['event_type'] ?? ''} ${e['title'] ?? ''}'.toLowerCase();
    if (t.contains('tour') || t.contains('trip') || t.contains('yatra')) return '🚌';
    if (t.contains('class') || t.contains('study') || t.contains('quran') || t.contains('halaqa')) return '📖';
    if (t.contains('camp')) return '⛺';
    if (t.contains('sport') || t.contains('football') || t.contains('match') || t.contains('cricket')) return '⚽';
    if (t.contains('iftar') || t.contains('ramadan') || t.contains('eid')) return '🌙';
    if (t.contains('meet') || t.contains('conference') || t.contains('sammelan')) return '🤝';
    if (t.contains('blood') || t.contains('relief') || t.contains('service') || t.contains('help')) return '❤️';
    if (t.contains('protest') || t.contains('rally') || t.contains('march')) return '📣';
    return '✨';
  }

  /// "Today", "Tomorrow", "In 3 days".
  static String? _when(DateTime? d) {
    if (d == null) return null;
    final now = DateTime.now();
    final days = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return null;
    if (days == 0) return d.isBefore(now) ? 'Happening now' : 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  Widget _info(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: _mid),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF2B3A4A), fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  void _open() => push(context, EventDetailScreen(name: '${widget.e['name']}', title: '${widget.e['title']}'));

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final d = parseDate(e['starts_on']);
    final canGo = !widget.past && AppState.i.can('register_events') && e['status'] != 'Completed';
    final venue = '${e['venue'] ?? ''}';
    final where = '${e['unit'] ?? ''}'.isEmpty ? 'Area-wide programme' : 'SIO ${e['unit']}';
    if (widget.past) {
      // past ones stay small
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _open,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(_emoji(e), style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e['title']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _deep),
                        ),
                        Text(
                          [if (d != null) DateFormat('d MMM').format(d), where].join(' · '),
                          style: const TextStyle(color: _grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _grey),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final soon = _when(d);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // the colourful top: picture, date, how soon
              Container(
                height: 112,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_sio, _light]),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -8,
                      bottom: -18,
                      child: Opacity(opacity: 0.9, child: Text(_emoji(e), style: const TextStyle(fontSize: 92))),
                    ),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: Container(
                        width: 62,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          children: [
                            Text(
                              d == null ? '' : DateFormat('EEE').format(d).toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _mid, letterSpacing: 1),
                            ),
                            Text(
                              d == null ? '–' : DateFormat('d').format(d),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.1, color: _deep),
                            ),
                            Text(
                              d == null ? '' : DateFormat('MMM').format(d).toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _mid, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (soon != null)
                      Positioned(
                        left: 88,
                        top: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            soon,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e['title']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _deep, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    if (d != null) _info(Icons.schedule_rounded, DateFormat('EEEE, h:mm a').format(d)),
                    if (venue.isNotEmpty) _info(Icons.place_outlined, venue),
                    _info(Icons.groups_2_outlined, where),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: FacesGoing(e: e, extra: _count - numOf(e['registered_count']).toInt())),
                        if (canGo)
                          SizedBox(
                            height: 46,
                            child: _going
                                ? OutlinedButton.icon(
                                    onPressed: _busy ? null : _toggle,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _sio,
                                      side: const BorderSide(color: _sio, width: 1.5),
                                      shape: const StadiumBorder(),
                                    ),
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Going', style: TextStyle(fontWeight: FontWeight.w800)),
                                  )
                                : FilledButton(
                                    onPressed: _busy ? null : _toggle,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _sio,
                                      padding: const EdgeInsets.symmetric(horizontal: 22),
                                      shape: const StadiumBorder(),
                                    ),
                                    child: const Text('I’ll go 🙌', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  ),
                          ),
                      ],
                    ),
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
