import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'events_screen.dart';
import 'expense_screens.dart';
import 'meeting_screens.dart';
import 'member_screens.dart';
import 'notice_screens.dart';

/// Home: greeting, the next meeting (like the Check In card), quick numbers for this person's role,
/// next event and latest updates.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.openTab});
  final void Function(int) openTab;

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Row(children: [
          const Image(image: AssetImage('assets/sio-logo.png'), width: 40, height: 40),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.firstName.isEmpty ? 'SIO Connect' : 'Hi ${s.firstName}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: SioColors.textSecondary)),
          ]),
        ]),
        actions: [
          IconButton(
            tooltip: 'Updates',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => push(context, const NoticesScreen()),
          ),
        ],
      ),
      body: Loader<Map<String, dynamic>>(
        load: () async {
          final h = Map<String, dynamic>.from(await Api.call('${Api.m}home') as Map);
          AppState.i.me = Map<String, dynamic>.from(h['me'] as Map);
          return h;
        },
        builder: (context, h) => [
          if (s.pending) ...[
            const SioBanner(
                text: 'Your registration is waiting for your unit’s approval. Meanwhile you can see events and updates, and make a pledge.'),
            const SizedBox(height: 12),
          ],
          if (h['next_meeting'] != null) ...[_MeetingCard(meeting: Map<String, dynamic>.from(h['next_meeting'])), const SizedBox(height: 12)],
          ..._tiles(context, h),
          if (h['next_event'] != null) ...[const SizedBox(height: 12), _EventPanel(event: Map<String, dynamic>.from(h['next_event']))],
          const SizedBox(height: 12),
          _NoticesPanel(notices: (h['notices'] as List?) ?? []),
        ],
      ),
    );
  }

  List<Widget> _tiles(BuildContext context, Map<String, dynamic> h) {
    final tiles = <Widget>[];
    final camp = h['campaign'] as Map?;
    if (camp != null && camp['collected'] != null) {
      tiles.add(_Tile(Icons.volunteer_activism, 'Collected', inr(camp['collected']), () => openTab(2)));
    } else if ((h['my_pledges'] as List?)?.isNotEmpty ?? false) {
      final list = h['my_pledges'] as List;
      final pledged = list.fold<num>(0, (a, e) => a + numOf(e['pledged_amount']));
      tiles.add(_Tile(Icons.favorite_outline, 'My pledge', inr(pledged), () => openTab(2)));
    } else if (camp != null) {
      tiles.add(_Tile(Icons.volunteer_activism, camp['name'].toString(), 'Make a pledge', () => openTab(2)));
    }
    final members = h['members'] as Map?;
    if (members != null) {
      tiles.add(_Tile(Icons.groups, numOf(members['pending']) > 0 ? '${members['pending']} waiting approval' : 'Active members',
          '${members['active']}', () => push(context, const MembersScreen())));
    }
    final exp = h['pending_expenses'] as Map?;
    if (exp != null) {
      tiles.add(_Tile(Icons.receipt_long, '${exp['count']} claims pending', inr(exp['amount']),
          () => push(context, const ExpensesScreen())));
    }
    final att = h['my_attendance'] as Map?;
    if (att != null && numOf(att['total']) > 0) {
      tiles.add(_Tile(Icons.how_to_reg, 'My attendance', '${att['present']} of ${att['total']}', () => openTab(1)));
    }
    if (tiles.isEmpty) return [];
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: tiles[i]),
          const SizedBox(width: 12),
          Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
        ]),
      ));
    }
    return rows;
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.value, this.onTap);
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: SioColors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: SioColors.blue),
              const SizedBox(height: 8),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: SioColors.ink)),
              ),
            ]),
          ),
        ),
      );
}

/// Next weekly meeting with the big RSVP button (the Hipersign Check In card).
class _MeetingCard extends StatefulWidget {
  const _MeetingCard({required this.meeting});
  final Map<String, dynamic> meeting;

  @override
  State<_MeetingCard> createState() => _MeetingCardState();
}

class _MeetingCardState extends State<_MeetingCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.meeting;
    final attending = m['my_rsvp'] == 'Attending';
    final canRsvp = AppState.i.can('rsvp');
    final when = [fmtDate(m['meeting_date'], 'EEE d MMM'), fmtTime(m['meeting_time'])].where((e) => e.isNotEmpty).join(', ');
    return SioPanel(
      color: attending ? SioColors.greenBg : SioColors.card,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: attending ? SioColors.green : SioColors.textSecondary, borderRadius: BorderRadius.circular(20)),
            child: Text(attending ? 'ATTENDING' : 'NEXT MEETING',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .5)),
          ),
          const Spacer(),
          Text(when, style: const TextStyle(color: SioColors.textSecondary, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        Text(m['topic']?.toString() ?? 'Weekly meeting',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SioColors.ink)),
        const SizedBox(height: 2),
        Text([m['meeting_type'], m['unit'], m['venue']].where((e) => e != null && '$e'.isNotEmpty).join(' · '),
            style: const TextStyle(color: SioColors.textSecondary)),
        if (canRsvp) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: attending ? SioColors.danger : SioColors.green,
              minimumSize: const Size.fromHeight(58),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await run(context, () => Api.call('${Api.m}rsvp', {'name': m['name'], 'attending': !attending}),
                        done: attending ? 'Marked as not attending.' : 'Your unit knows you’ll attend.');
                    if (mounted) setState(() => _busy = false);
                  },
            icon: Icon(attending ? Icons.close : Icons.how_to_reg),
            label: Text(attending ? 'Can’t make it' : 'I’ll attend'),
          ),
        ],
        if (AppState.i.can('mark_attendance')) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => push(context, MeetingScreen(name: m['name'].toString())),
            icon: const Icon(Icons.checklist),
            label: const Text('Open meeting'),
          ),
        ],
      ]),
    );
  }
}

class _EventPanel extends StatelessWidget {
  const _EventPanel({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final d = parseDate(event['starts_on']);
    return SioPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Next event', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SioColors.ink))),
          TextButton(onPressed: () => push(context, const EventsScreen(standalone: true)), child: const Text('All events')),
        ]),
        Row(children: [
          Container(
            width: 52,
            height: 56,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(d == null ? '' : DateFormat('MMM').format(d).toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SioColors.red)),
              Text(d == null ? '' : '${d.day}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event['title'].toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text([event['venue'], if (d != null) DateFormat.jm().format(d)].where((e) => e != null && '$e'.isNotEmpty).join(' · '),
                  style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
            ]),
          ),
          if (event['my_registration'] != null) const StatusChip('Registered', tone: Tone.green),
        ]),
      ]),
    );
  }
}

class _NoticesPanel extends StatelessWidget {
  const _NoticesPanel({required this.notices});
  final List notices;

  @override
  Widget build(BuildContext context) => SioPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('Latest updates', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SioColors.ink))),
            TextButton(onPressed: () => push(context, const NoticesScreen()), child: const Text('See all')),
          ]),
          if (notices.isEmpty) const Text('No updates yet.', style: TextStyle(color: SioColors.textSecondary)),
          for (final n in notices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text('${n['audience'] == 'Unit' ? n['unit'] : n['audience']} · ${fmtDate(n['sent_on'], 'd MMM, h:mm a')}',
                    style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
              ]),
            ),
        ]),
      );
}
