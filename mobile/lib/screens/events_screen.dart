import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, this.standalone = false});
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: Loader<List<dynamic>>(
        load: () async => (await Api.call('${Api.m}events') as List?) ?? [],
        builder: (context, list) => [
          if (list.isEmpty) const EmptyNote('No events right now.'),
          for (final e in list) ...[_EventCard(e: Map<String, dynamic>.from(e)), const SizedBox(height: 12)],
        ],
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
  const _EventCard({required this.e});
  final Map<String, dynamic> e;

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final d = parseDate(e['starts_on']);
    final cap = numOf(e['capacity']);
    final reg = numOf(e['registered_count']);
    final registered = e['my_registration'] != null;
    final open = e['status'] == 'Registrations Open';
    final canRegister = AppState.i.can('register_events');
    return SioPanel(
      onTap: () => push(context, EventDetailScreen(name: e['name'].toString(), title: e['title'].toString())),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(e['title'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SioColors.ink))),
          const SizedBox(width: 8),
          StatusChip(registered ? 'Registered' : e['status'].toString(),
              tone: registered ? Tone.green : StatusChip.toneFor(e['status'].toString())),
        ]),
        const SizedBox(height: 6),
        Text([if (d != null) DateFormat('EEE d MMM, h:mm a').format(d), e['venue']].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
            style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
        if (cap > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Expanded(child: Text('Registered', style: TextStyle(color: SioColors.textSecondary, fontSize: 13))),
            Text('${reg.toInt()} / ${cap.toInt()}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          ProgressBar(reg / cap),
        ],
        if (e['budget'] != null) ...[
          const SizedBox(height: 8),
          Text('Budget ${inr(e['budget'])} · spent ${inr(e['spent'])}', style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
        ],
        if (canRegister && (open || registered)) ...[
          const SizedBox(height: 12),
          registered
              ? OutlinedButton(
                  onPressed: _busy ? null : () => _go(cancel: true),
                  child: const Text('Cancel my registration'),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: SioColors.red),
                  onPressed: _busy ? null : () => _go(cancel: false),
                  child: const Text('Register'),
                ),
        ],
      ]),
    );
  }

  Future<void> _go({required bool cancel}) async {
    setState(() => _busy = true);
    await run(context, () => Api.call('${Api.m}register_event', {'event': widget.e['name'], 'cancel': cancel}),
        done: cancel ? 'Registration cancelled.' : 'You are registered. See you there!');
    if (mounted) setState(() => _busy = false);
  }
}
