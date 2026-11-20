import 'journey_screens.dart';

import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../biometric.dart';
import '../theme.dart';
import '../update_service.dart';
import '../photo.dart';
import 'settings_sheets.dart';
import '../widgets.dart';
import '../location.dart';
import 'task_screens.dart';
import 'accounts_screen.dart';
import 'donors_screen.dart';
import 'fund_screens.dart';
import 'manage_screens.dart';
import 'units_screen.dart';
import 'events_screen.dart';
import 'expense_screens.dart';
import 'social_screens.dart';
import 'card_screens.dart';
import 'collection_screens.dart';
import 'home_shell.dart';
import 'meeting_screens.dart';
import 'member_screens.dart';
import 'notice_screens.dart';

/// More tab, laid out like the Hipersign mobile app: profile card, then rows for this person's role.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.i,
      builder: (context, _) {
        final s = AppState.i;
        final me = s.me;
        final meetingsTab = s.can('rsvp') || s.can('mark_attendance');
        return Scaffold(
          appBar: AppBar(title: Text(dashboardOpen ? 'Admin' : 'More')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              SioPanel(
                child: Row(
                  children: [
                    Avatar((me['full_name'] ?? '').toString(), radius: 26, photo: me['photo']),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (me['full_name'] ?? '').toString(),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [
                              s.pending
                                  ? 'Waiting for your unit to confirm'
                                  : (dashboardOpen ? me['member_role'] : friendlyRole(me['member_role'])),
                              me['unit'],
                            ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                            style: TextStyle(color: SioColors.textSecondary, fontSize: 13),
                          ),
                          if (me['member'] != null)
                            Text('Member ID ${me['member']}', style: TextStyle(color: SioColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!dashboardOpen)
                SioTile(
                  icon: Icons.person_outline,
                  title: 'My profile',
                  subtitle: 'College, course, unit',
                  onTap: () => push(context, const ProfileScreen()),
                ),
              if (me['member'] != null && !dashboardOpen)
                SioTile(
                  icon: Icons.badge_outlined,
                  title: 'My SIO card',
                  subtitle: 'Membership card with QR for check-in',
                  onTap: () => push(context, const MemberCardScreen()),
                ),
              if (me['member'] != null && !dashboardOpen)
                SioTile(
                  icon: Icons.local_fire_department_outlined,
                  title: 'My journey',
                  subtitle: 'Daily ayah streak, quiz, badges, friends',
                  onTap: () => push(context, const JourneyScreen()),
                ),
              if (me['member'] != null && !dashboardOpen)
                SioTile(
                  icon: Icons.account_circle_outlined,
                  title: 'My page',
                  subtitle: 'Username, badges and posts friends see',
                  onTap: () => push(context, const PersonPage()),
                ),
              if (s.can('manage_events'))
                SioTile(
                  icon: Icons.quiz_outlined,
                  title: 'Weekly quizzes',
                  subtitle: 'Make the quiz for the week, see scores',
                  onTap: () => push(context, const QuizzesScreen()),
                ),
              if (me['member'] != null && !dashboardOpen)
                SioTile(
                  icon: Icons.task_alt,
                  title: 'My tasks',
                  subtitle: 'Event tasks given to me, reminders',
                  onTap: () => push(context, const MyTasksScreen()),
                ),
              if (s.can('view_members'))
                SioTile(
                  icon: Icons.groups_outlined,
                  title: 'Students & members',
                  subtitle: 'Approve new associates, roles',
                  onTap: () => push(context, const MembersScreen()),
                ),
              if (meetingsTab)
                SioTile(
                  icon: Icons.event_outlined,
                  title: 'Events',
                  subtitle: 'Programmes and registrations',
                  onTap: () => push(context, const EventsScreen(standalone: true)),
                )
              else if (s.can('mark_attendance'))
                SioTile(
                  icon: Icons.event_note_outlined,
                  title: 'Meetings',
                  subtitle: 'Weekly meetings',
                  onTap: () => push(context, const MeetingsScreen(standalone: true)),
                ),
              if (dashboardOpen && (s.can('collect') || s.can('view_collection_totals') || s.can('offer')))
                SioTile(
                  icon: Icons.volunteer_activism_outlined,
                  title: s.can('collect') || s.can('view_collection_totals') ? 'Collections' : 'Give',
                  subtitle: 'Collected so far, entries and offers',
                  onTap: () => push(
                    context,
                    CollectionScreen(title: s.can('collect') || s.can('view_collection_totals') ? 'Collection' : 'Give'),
                  ),
                ),
              if ((s.can('claim_expense') || s.can('approve_expense')) && !dashboardOpen)
                SioTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Expense claims',
                  subtitle: s.can('approve_expense') ? 'Approve and pay claims' : 'Claim bills for events and meetings',
                  onTap: () => push(context, const ExpensesScreen()),
                ),
              if (s.can('view_donors'))
                SioTile(
                  icon: Icons.contacts_outlined,
                  title: 'Donors',
                  subtitle: 'Everyone who gave, with phone, to ask again',
                  onTap: () => push(context, const DonorsScreen()),
                ),
              if (s.can('view_members') || s.can('all_units'))
                SioTile(
                  icon: Icons.apartment_outlined,
                  title: 'Areas & units',
                  subtitle: s.can('manage_units') ? 'Add areas and units, office bearers' : 'Areas, units and their members',
                  onTap: () => push(context, const UnitsScreen()),
                ),
              if (s.can('manage_collections'))
                SioTile(
                  icon: Icons.savings_outlined,
                  title: 'Collections & targets',
                  subtitle: 'Add, close or delete collections; split targets to units',
                  onTap: () => push(context, const ManageCollectionsScreen()),
                ),
              if (s.can('request_funds') || s.can('approve_funds'))
                SioTile(
                  icon: Icons.request_quote_outlined,
                  title: 'Programme funds',
                  subtitle: s.can('approve_funds')
                      ? 'Approve and release money units ask for'
                      : 'Ask the area for programme money',
                  onTap: () => push(context, const FundRequestsScreen()),
                ),
              if (s.can('view_accounts'))
                SioTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Accounts',
                  subtitle: 'Money in, money out and balance',
                  onTap: () => push(context, const AccountsScreen()),
                ),
              SioTile(
                icon: Icons.campaign_outlined,
                title: 'Updates & notices',
                subtitle: s.can('send_notice') ? 'Read and send updates' : 'News from your unit and area',
                onTap: () => push(context, const NoticesScreen()),
              ),
              const _BiometricTile(),
              if (!dashboardOpen) ...[
                SioTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Daily ayah reminder',
                  subtitle: reminderLabel(),
                  onTap: () async {
                    await showReminderPicker(context);
                    AppState.i.touch();
                  },
                ),
                SioTile(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Dark mode and text size',
                  onTap: () => showAppearance(context),
                ),
                SioTile(
                  icon: Icons.feedback_outlined,
                  title: 'Send feedback',
                  subtitle: 'Report a problem or share an idea',
                  onTap: () => showFeedback(context),
                ),
              ],
              if (!dashboardOpen && s.isLeader)
                SioTile(
                  icon: Icons.space_dashboard_outlined,
                  title: 'Open admin dashboard',
                  subtitle: 'Meetings, collections, members and more',
                  onTap: () => openAdminDashboard(context),
                ),
              if (dashboardOpen)
                SioTile(
                  icon: Icons.auto_awesome,
                  title: 'Back to the app',
                  subtitle: 'Feed, friends and my journey',
                  onTap: () => Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst),
                ),
              if (!dashboardOpen && !UpdateService.playStore)
                SioTile(
                  icon: Icons.system_update_outlined,
                  title: 'Check for updates',
                  subtitle: UpdateService.versionLabel,
                  onTap: () => UpdateService.check(context, force: true),
                ),
              if (!dashboardOpen)
                SioTile(
                  icon: Icons.dns_outlined,
                  title: 'Server',
                  subtitle: Api.baseUrl.replaceFirst('https://', ''),
                  onTap: () {},
                ),
              const SizedBox(height: 8),
              if (!dashboardOpen && s.me['member'] != null)
                SioTile(
                  icon: Icons.person_remove_outlined,
                  title: 'Delete my account',
                  subtitle: 'Remove your profile and data from SIO Connect',
                  onTap: () => deleteMyAccount(context),
                ),
              if (!dashboardOpen)
                SioTile(
                  icon: Icons.logout,
                  title: 'Sign out',
                  danger: true,
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign out?'),
                        content: const Text('Fingerprint sign-in will be turned off on this phone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                        ],
                      ),
                    );
                    if (ok == true) await AppState.i.signOut();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BiometricTile extends StatefulWidget {
  const _BiometricTile();

  @override
  State<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<_BiometricTile> {
  bool? _available;

  @override
  void initState() {
    super.initState();
    Biometric.available().then((v) {
      if (mounted) setState(() => _available = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_available != true) return const SizedBox.shrink();
    final on = AppState.i.biometricOn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: SioColors.card,
        secondary: Icon(Icons.fingerprint, color: SioColors.blue),
        title: const Text('Fingerprint sign-in'),
        subtitle: Text(on ? 'Open the app with your fingerprint' : 'Off', style: TextStyle(color: SioColors.textSecondary)),
        value: on,
        onChanged: (v) async {
          if (v) {
            await run(context, AppState.i.enableBiometric, done: 'Fingerprint sign-in is on.');
          } else {
            await AppState.i.disableBiometric();
          }
          if (mounted) setState(() {});
        },
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final me = AppState.i.me;
  late final _campus = TextEditingController(text: (me['campus'] ?? '').toString());
  late final _course = TextEditingController(text: (me['course'] ?? '').toString());
  late final _town = TextEditingController(text: (me['home_town'] ?? '').toString());
  late String? _year = (me['year_of_study'] ?? '').toString().isEmpty ? null : me['year_of_study'].toString();
  late String? _unit = me['unit']?.toString();
  List<dynamic> _units = [];
  bool _busy = false;
  late GeoPoint? _loc = GeoPoint.from(me['latitude'], me['longitude']);
  late final _landmark = TextEditingController(text: (me['location_note'] ?? '').toString());

  static const years = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'PG 1st Year',
    'PG 2nd Year',
    'Research',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (AppState.i.pending) {
      Api.units()
          .then((u) {
            if (mounted) setState(() => _units = u);
          })
          .catchError((_) {});
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(context, () async {
      final r = await Api.call('${Api.m}update_my_profile', {
        'campus': _campus.text.trim(),
        'course': _course.text.trim(),
        'year_of_study': _year,
        'home_town': _town.text.trim().isEmpty ? null : _town.text.trim(),
        'unit': AppState.i.pending ? _unit : null,
        'latitude': _loc?.lat,
        'longitude': _loc?.lng,
        'clear_location': _loc == null ? 1 : null,
        'location_note': _landmark.text.trim(),
      });
      AppState.i.me = Map<String, dynamic>.from(r as Map);
    }, done: 'Profile saved.');
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = AppState.i.pending;
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (me['member'] != null) ...[
            PhotoPicker(
              name: (me['full_name'] ?? '').toString(),
              photo: me['photo']?.toString(),
              self: true,
              onChanged: (u) {
                AppState.i.me['photo'] = u;
                AppState.i.refreshAll();
                AppState.i.touch();
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to add or change your photo',
              textAlign: TextAlign.center,
              style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
          ],
          SioPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((me['full_name'] ?? '').toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  [me['mobile'], me['email']].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                  style: TextStyle(color: SioColors.textSecondary),
                ),
                if (me['joined_on'] != null)
                  Text('Member since ${fmtDate(me['joined_on'])}', style: TextStyle(color: SioColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (pending && _units.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _units.any((u) => u['name'] == _unit) ? _unit : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: [for (final u in _units) DropdownMenuItem(value: u['name'].toString(), child: Text(u['name'].toString()))],
              onChanged: (v) => setState(() => _unit = v),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _campus,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'College / campus'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _course,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Course'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: years.contains(_year) ? _year : null,
            decoration: const InputDecoration(labelText: 'Year'),
            items: [for (final y in years) DropdownMenuItem(value: y, child: Text(y))],
            onChanged: (v) => setState(() => _year = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _town,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Home town'),
          ),
          const SizedBox(height: 14),
          LocationField(value: _loc, onChanged: (g) => setState(() => _loc = g)),
          const SizedBox(height: 10),
          TextField(
            controller: _landmark,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'House name / landmark (optional)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

Future<void> deleteMyAccount(BuildContext context) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete my account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your profile, photo, contact details, location, username, friends, posts, photo tags, streaks and quiz '
            'answers will be removed, and you will be signed out. This cannot be undone.\n\n'
            'Records SIO must keep (money paid or collected, attendance) stay without your contact details.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            decoration: const InputDecoration(labelText: 'Type DELETE to confirm'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: SioColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final done = await run(context, () => Api.call('${Api.m}delete_my_account', {'confirm': c.text.trim()}));
  if (done && context.mounted) {
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    await AppState.i.signOut();
  }
}
