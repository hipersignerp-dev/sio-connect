import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'expense_screens.dart';

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
          ? FloatingActionButton.extended(
              onPressed: () => push(context, NewClaimScreen(event: name)),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(e['title'].toString(),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SioColors.ink)),
                  ),
                  StatusChip(e['status'].toString(), tone: StatusChip.toneFor(e['status'].toString())),
                ]),
                const SizedBox(height: 6),
                Text(
                    [if (d != null) DateFormat('EEE d MMM yyyy, h:mm a').format(d), e['venue'], e['unit']]
                        .where((x) => x != null && '$x'.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
                if ((e['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(e['description'].toString()),
                ],
              ]),
            ),
            if (sum != null) ...[
              const SectionTitle('Spending'),
              SioPanel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Stat(budget > 0 ? inr(budget) : '–', 'Budget', color: SioColors.ink),
                    Stat(inr(spent), 'Spent', color: SioColors.danger),
                    Stat(sum['remaining'] == null ? '–' : inr(sum['remaining']), 'Left',
                        color: numOf(sum['remaining']) < 0 ? SioColors.danger : SioColors.green),
                  ]),
                  if (budget > 0) ...[
                    const SizedBox(height: 12),
                    ProgressBar(spent / budget),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    [
                      '${inr(sum['paid'])} paid',
                      if (numOf(sum['approved']) > 0) '${inr(sum['approved'])} approved, to pay',
                      if (numOf(sum['pending']) > 0) '${inr(sum['pending'])} waiting approval',
                      if (sum['scope'] == 'my unit') 'your unit only',
                    ].join(' · '),
                    style: const TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
                  ),
                ]),
              ),
              if (cats.isNotEmpty) ...[
                const SectionTitle('By category'),
                PanelList(children: [
                  for (final c in cats)
                    ListTile(
                      dense: true,
                      title: Text(c['category'].toString()),
                      trailing: Text(inr(c['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                ]),
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
