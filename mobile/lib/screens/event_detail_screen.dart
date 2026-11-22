import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:material_ui/material_ui.dart';

import 'album_screens.dart';
import 'card_screens.dart';
import '../links.dart';
import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'certificate_screen.dart';
import 'expense_screens.dart';
import 'manage_screens.dart';
import 'task_screens.dart';

/// One event: details, and its expenses. Office bearers see budget, spent, waiting and what is left,
/// split by category; members see their own claims for the event.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.name, required this.title});
  final String name;
  final String title;

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: s.can('claim_expense')
          ? AddFab(
              tooltip: 'Add expense',
              onPressed: () => push(context, NewClaimScreen(event: name)),
            )
          : null,
      body: Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await Api.call('${Api.m}event', {'name': name}) as Map),
        builder: (context, e) {
          final d = parseDate(e['starts_on']);
          final sum = e['expense_summary'] as Map?;
          final expenses = (e['expenses'] as List?) ?? [];
          final cats = (sum?['by_category'] as List?) ?? [];
          final budget = numOf(sum?['budget']);
          final spent = numOf(sum?['spent']);
          return [
            SioPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e['title'].toString(),
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SioColors.ink),
                        ),
                      ),
                      StatusChip(e['status'].toString(), tone: StatusChip.toneFor(e['status'].toString())),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (d != null) DateFormat('EEE d MMM yyyy, h:mm a').format(d),
                      e['venue'],
                      e['unit'],
                    ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                    style: TextStyle(color: SioColors.textSecondary, fontSize: 13),
                  ),
                  if (s.can('manage_events') && (s.can('all_units') || (e['unit'] != null && e['unit'] == s.me['unit'])))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () async {
                          final r = await push(context, EventFormScreen(event: e));
                          if (r == 'deleted' && context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit event'),
                      ),
                    ),
                  if ((e['description'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(e['description'].toString()),
                  ],
                ],
              ),
            ),
            if (s.can('register_events') && !const ['Completed', 'Cancelled'].contains(e['status'])) ...[
              const SizedBox(height: 12),
              _RegisterButton(event: e),
            ],
            if (e['status'] != 'Cancelled') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (e['can_manage_tasks'] == true)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => push(context, CheckinHostScreen(event: '${e['name']}')),
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Check-in QR'),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => scanToCheckIn(context),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Check in'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final albums = (Map<String, dynamic>.from(await Api.call('${Api.m}albums') as Map)['albums'] as List)
                            .where((a) => a['event'] == e['name'])
                            .toList();
                        if (!context.mounted) return;
                        if (albums.isNotEmpty) {
                          push(context, AlbumScreen(name: '${albums.first['name']}'));
                        } else if (e['can_manage_tasks'] == true) {
                          final n = await newAlbum(context, event: '${e['name']}');
                          if (n != null && context.mounted) push(context, AlbumScreen(name: n));
                        } else {
                          toast(context, 'No photos from this programme yet.');
                        }
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Photos'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                    tooltip: 'Share on WhatsApp',
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: [
                          '📢 ${e['title']}',
                          if (e['starts_on'] != null) '🗓 ${fmtDate(e['starts_on'], 'EEE d MMM, h:mm a')}',
                          if ('${e['venue'] ?? ''}'.isNotEmpty) '📍 ${e['venue']}',
                          'Details and registration: ${Links.share({'e': '${e['name']}'})}',
                        ].join('\n'),
                      ),
                    ),
                    icon: const Icon(Icons.share, color: Colors.white),
                  ),
                ],
              ),
            ],
            if (e['attended'] == 1 || e['ratings'] != null) ProgrammeAfter(e: e),
            ...teamAndTaskSections(context, e),
            if (sum != null) ...[
              const SectionTitle('Spending'),
              SioPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Stat(budget > 0 ? inr(budget) : '–', 'Budget', color: SioColors.ink),
                        Stat(inr(spent), 'Spent', color: SioColors.danger),
                        Stat(
                          sum['remaining'] == null ? '–' : inr(sum['remaining']),
                          'Left',
                          color: numOf(sum['remaining']) < 0 ? SioColors.danger : SioColors.green,
                        ),
                      ],
                    ),
                    if (budget > 0) ...[const SizedBox(height: 12), ProgressBar(spent / budget)],
                    const SizedBox(height: 10),
                    Text(
                      [
                        '${inr(sum['paid'])} paid',
                        if (numOf(sum['approved']) > 0) '${inr(sum['approved'])} approved, to pay',
                        if (numOf(sum['pending']) > 0) '${inr(sum['pending'])} waiting approval',
                        if (sum['scope'] == 'my unit') 'your unit only',
                      ].join(' · '),
                      style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (cats.isNotEmpty) ...[
                const SectionTitle('By category'),
                PanelList(
                  children: [
                    for (final c in cats)
                      ListTile(
                        dense: true,
                        title: Text(c['category'].toString()),
                        trailing: Text(inr(c['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ],
            ],
            SectionTitle(sum != null ? 'Expenses' : 'My expenses for this event'),
            if (expenses.isEmpty) const EmptyNote('No expenses yet.'),
            for (final x in expenses) ...[
              ClaimCard(c: Map<String, dynamic>.from(x)..['event'] = null, canApprove: false),
              const SizedBox(height: 10),
            ],
          ];
        },
      ),
    );
  }
}

/// Register for the event (or cancel the registration) from its page.
class _RegisterButton extends StatefulWidget {
  const _RegisterButton({required this.event});
  final Map<String, dynamic> event;

  @override
  State<_RegisterButton> createState() => _RegisterButtonState();
}

class _RegisterButtonState extends State<_RegisterButton> {
  late bool _registered = widget.event['my_registration'] != null;
  bool _busy = false;

  Future<void> _go() async {
    final cancel = _registered;
    setState(() => _busy = true);
    final ok = await run(
      context,
      () => Api.call('${Api.m}register_event', {'event': widget.event['name'], 'cancel': cancel}),
      done: cancel ? 'Registration cancelled.' : 'You are registered. See you there!',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _registered = !cancel;
    });
    if (ok) AppState.i.refreshAll();
  }

  @override
  Widget build(BuildContext context) => _registered
      ? OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: _busy ? null : _go,
          icon: Icon(Icons.check_circle, color: SioColors.green),
          label: const Text('Registered · tap to cancel'),
        )
      : FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: SioColors.red, minimumSize: const Size.fromHeight(50)),
          onPressed: _busy ? null : _go,
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Register for this programme'),
        );
}
