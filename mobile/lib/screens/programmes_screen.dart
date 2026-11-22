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
    backgroundColor: SioColors.background,
    appBar: AppBar(
      backgroundColor: SioColors.background,
      surfaceTintColor: SioColors.background,
      automaticallyImplyLeading: false,
      title: const Text('Programmes', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [
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
      done: was ? 'Removed' : 'See you there! 🙌',
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

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final d = parseDate(e['starts_on']);
    final canGo = !widget.past && AppState.i.can('register_events') && e['status'] != 'Completed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: SioColors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => push(context, EventDetailScreen(name: '${e['name']}', title: '${e['title']}')),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.past ? SioColors.greyBg : SioColors.blue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        d == null ? '–' : DateFormat('d').format(d),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          color: widget.past ? SioColors.ink : Colors.white,
                        ),
                      ),
                      Text(
                        d == null ? '' : DateFormat('MMM').format(d).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: widget.past ? SioColors.textSecondary : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e['title']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: SioColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (d != null) DateFormat('EEE, h:mm a').format(d),
                          if ('${e['venue'] ?? ''}'.isNotEmpty) '${e['venue']}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: SioColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${e['unit'] ?? ''}'.isEmpty ? 'Area-wide' : 'SIO ${e['unit']}',
                        style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      FacesGoing(e: e, extra: _count - numOf(e['registered_count']).toInt()),
                    ],
                  ),
                ),
                if (canGo) ...[
                  const SizedBox(width: 8),
                  _going
                      ? FilledButton.tonal(
                          onPressed: _busy ? null : _toggle,
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                          child: const Text('✓ Going'),
                        )
                      : FilledButton(
                          onPressed: _busy ? null : _toggle,
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                          child: const Text('I’ll go'),
                        ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
