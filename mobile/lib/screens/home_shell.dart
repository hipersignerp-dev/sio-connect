import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../notify.dart';
import '../theme.dart';
import '../update_service.dart';
import '../widgets.dart';
import 'collection_screens.dart';
import 'events_screen.dart';
import 'expense_screens.dart';
import 'donors_screen.dart';
import 'fund_screens.dart';
import 'home_screen.dart';
import 'manage_screens.dart';
import 'meeting_screens.dart';
import 'more_screen.dart';
import 'notice_screens.dart';

/// Bottom-bar shell, the same pattern as the Hipersign mobile app: Home, (2nd tab), [+], Collection, More.
/// Members see Meetings as the 2nd tab; associates see Events. Every tab and + item depends on the
/// person's capabilities from ERP, so each person gets their own app.
/// True while the admin dashboard is open on top of the app.
bool dashboardOpen = false;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.dashboard = false});
  final bool dashboard; // opened from the app's "Admin dashboard" button

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    dashboardOpen = widget.dashboard;
    if (widget.dashboard) return;
    WidgetsBinding.instance.addObserver(this);
    // like the HiperTracker app: look for a new version when the app opens (at most every few hours)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.check(context);
    });
    // phone notifications for new updates and programmes
    Notify.start('${AppState.i.me['user'] ?? ''}');
  }

  @override
  void dispose() {
    if (widget.dashboard) dashboardOpen = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      UpdateService.check(context);
      Notify.check().catchError((_) {});
    }
  }

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
        // associates only give offers, so + opens that straight away
        onPressed: () => s.role == 'Associate' || (s.can('offer') && !s.can('collect') && !s.can('mark_attendance'))
            ? push(context, const NewEntryScreen(forSelf: true))
            : showQuickAdd(context),
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        height: 68,
        child: Row(
          children: [
            nav(0),
            nav(1),
            const Expanded(child: SizedBox()),
            nav(2),
            nav(3),
          ],
        ),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w700 : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _QuickAction = (IconData, Color, String, Widget Function());

/// Each role's most-used actions, in order. The first four show as big buttons; the rest sit under "More".
const _priorities = <String, List<String>>{
  'Area Admin': ['funds', 'collect', 'expense', 'update', 'event', 'collection', 'student', 'donor', 'attendance', 'meeting'],
  'Area President': ['funds', 'collect', 'expense', 'update', 'event', 'collection', 'student', 'donor', 'attendance', 'meeting'],
  'Area Secretary': ['funds', 'collect', 'expense', 'update', 'event', 'collection', 'student', 'donor', 'attendance', 'meeting'],
  'Finance': ['collect', 'funds', 'expense', 'collection', 'donor', 'offer'],
  'Unit President': ['attendance', 'collect', 'expense', 'student', 'meeting', 'ask_funds', 'event', 'update', 'donor', 'offer'],
  'Unit Secretary': ['attendance', 'meeting', 'collect', 'student', 'expense', 'update', 'ask_funds', 'event', 'donor', 'offer'],
  'Worker': ['collect', 'offer', 'expense', 'donor'],
  'Member': ['collect', 'offer', 'expense', 'donor'],
};

/// The + button: the actions that matter most for this person first, the rest one tap away.
Future<void> showQuickAdd(BuildContext context) async {
  final s = AppState.i;
  final all = <String, _QuickAction>{
    if (s.can('offer'))
      'offer': (Icons.favorite_outline, SioColors.green, 'Give an offer', () => const NewEntryScreen(forSelf: true)),
    if (s.can('collect')) 'collect': (Icons.volunteer_activism, SioColors.red, 'Collection entry', () => const NewEntryScreen()),
    if (s.can('mark_attendance'))
      'attendance': (Icons.how_to_reg, SioColors.blue, 'Attendance', () => const MeetingsScreen(standalone: true)),
    if (s.can('schedule_meeting'))
      'meeting': (Icons.edit_calendar, SioColors.ink, 'New meeting', () => const ScheduleMeetingScreen()),
    if (s.can('claim_expense')) 'expense': (Icons.receipt_long, SioColors.warning, 'Expense claim', () => const NewClaimScreen()),
    if (s.can('send_notice')) 'update': (Icons.campaign, SioColors.purple, 'Send update', () => const SendNoticeScreen()),
    if (s.can('manage_events')) 'event': (Icons.event_available, SioColors.green, 'New event', () => const EventFormScreen()),
    if (s.can('add_members')) 'student': (Icons.person_add_alt_1, SioColors.blue, 'Add student', () => const MemberFormScreen()),
    if (s.can('request_funds') && !s.can('approve_funds'))
      'ask_funds': (Icons.request_quote_outlined, SioColors.blue, 'Ask for funds', () => const FundRequestFormScreen()),
    if (s.can('approve_funds'))
      'funds': (Icons.request_quote_outlined, SioColors.blue, 'Fund requests', () => const FundRequestsScreen()),
    if (s.can('view_donors')) 'donor': (Icons.contacts_outlined, SioColors.green, 'New donor', () => const DonorFormScreen()),
    if (s.can('manage_collections'))
      'collection': (Icons.savings_outlined, SioColors.red, 'New collection', () => const CollectionFormScreen()),
  };
  final order = <String>[
    for (final k in _priorities[s.role] ?? const <String>[])
      if (all.containsKey(k)) k,
    for (final k in all.keys)
      if (!(_priorities[s.role] ?? const <String>[]).contains(k)) k,
  ];
  final top = order.take(4).toList();
  final rest = order.skip(4).toList();

  void open(BuildContext sheet, String k) {
    Navigator.pop(sheet);
    push(context, all[k]!.$4());
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: _QuickAddSheet(
        top: [for (final k in top) (all[k]!, () => open(sheet, k))],
        rest: [for (final k in rest) (all[k]!, () => open(sheet, k))],
      ),
    ),
  );
}

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet({required this.top, required this.rest});
  final List<(_QuickAction, VoidCallback)> top;
  final List<(_QuickAction, VoidCallback)> rest;

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  bool _more = false;

  Widget _big((_QuickAction, VoidCallback) it) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: it.$2,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: it.$1.$2,
            child: Icon(it.$1.$1, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            it.$1.$3,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final it in widget.top) Expanded(child: _big(it)),
              for (var i = widget.top.length; i < 4; i++) const Expanded(child: SizedBox()),
            ],
          ),
          if (widget.rest.isNotEmpty) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => setState(() => _more = !_more),
              icon: Icon(_more ? Icons.expand_less : Icons.expand_more),
              label: Text(_more ? 'Less' : 'More'),
            ),
            if (_more)
              for (final it in widget.rest)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: it.$1.$2,
                    child: Icon(it.$1.$1, color: Colors.white, size: 20),
                  ),
                  title: Text(it.$1.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: it.$2,
                ),
          ],
        ],
      ),
    );
  }
}
