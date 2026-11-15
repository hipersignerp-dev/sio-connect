import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'collection_screens.dart';
import 'events_screen.dart';
import 'expense_screens.dart';
import 'home_screen.dart';
import 'meeting_screens.dart';
import 'more_screen.dart';
import 'notice_screens.dart';

/// Bottom-bar shell, the same pattern as the Hipersign mobile app: Home, (2nd tab), [+], Collection, More.
/// Members see Meetings as the 2nd tab; associates see Events. Every tab and + item depends on the
/// person's capabilities from ERP, so each person gets their own app.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    final meetingsTab = s.can('rsvp') || s.can('mark_attendance');
    final collectLabel = s.can('collect') || s.can('view_collection_totals') ? 'Collection' : 'Give';
    final pages = <Widget>[
      HomeScreen(openTab: (i) => setState(() => _tab = i)),
      meetingsTab ? const MeetingsScreen() : const EventsScreen(),
      CollectionScreen(title: collectLabel == 'Give' ? 'Give' : 'Collection'),
      const MoreScreen(),
    ];
    final tabs = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home, 'Home'),
      meetingsTab ? (Icons.event_note_outlined, Icons.event_note, 'Meetings') : (Icons.event_outlined, Icons.event, 'Events'),
      (Icons.volunteer_activism_outlined, Icons.volunteer_activism, collectLabel),
      (Icons.more_horiz, Icons.more_horiz, 'More'),
    ];
    Widget nav(int i) => _NavItem(
          icon: _tab == i ? tabs[i].$2 : tabs[i].$1,
          label: tabs[i].$3,
          selected: _tab == i,
          onTap: () => setState(() => _tab = i),
        );
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add new',
        backgroundColor: SioColors.red,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => showQuickAdd(context),
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        height: 68,
        child: Row(children: [nav(0), nav(1), const Expanded(child: SizedBox()), nav(2), nav(3)]),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SioColors.blue : SioColors.textSecondary;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w700 : null)),
          ]),
        ),
      ),
    );
  }
}

/// The + button: only the actions this person may do.
Future<void> showQuickAdd(BuildContext context) async {
  final s = AppState.i;
  final items = <(IconData, Color, String, String, Widget Function())>[
    if (s.can('offer'))
      (Icons.favorite_outline, SioColors.green, 'Give an offer', 'Ramadan collection, Baithul Mal...',
          () => const NewEntryScreen(forSelf: true)),
    if (s.can('collect'))
      (Icons.volunteer_activism, SioColors.red, 'Collection entry', 'Offered, paid now or items, from someone',
          () => const NewEntryScreen()),
    if (s.can('mark_attendance'))
      (Icons.how_to_reg, SioColors.blue, 'Mark attendance', 'Pick a meeting and mark who came', () => const MeetingsScreen(standalone: true)),
    if (s.can('schedule_meeting'))
      (Icons.edit_calendar, SioColors.ink, 'Schedule meeting', 'Weekly meeting or study circle', () => const ScheduleMeetingScreen()),
    if (s.can('claim_expense'))
      (Icons.receipt_long, SioColors.warning, 'Expense claim', 'Bills for events and meetings', () => const NewClaimScreen()),
    if (s.can('send_notice'))
      (Icons.campaign, SioColors.purple, 'Send update', 'Tell members in the app', () => const SendNoticeScreen()),
    if (!s.can('rsvp'))
      (Icons.event, SioColors.blue, 'Events', 'See and register for programmes', () => const EventsScreen(standalone: true)),
  ];
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final it in items)
          ListTile(
            leading: CircleAvatar(backgroundColor: it.$2, child: Icon(it.$1, color: Colors.white)),
            title: Text(it.$3, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(it.$4),
            onTap: () {
              Navigator.pop(sheet);
              push(context, it.$5());
            },
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}
