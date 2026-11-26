import 'dart:convert';

import 'journey_screens.dart';

import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../biometric.dart';
import '../theme.dart';
import '../update_service.dart';
import '../photo.dart';
import 'settings_sheets.dart';
import '../bug_report.dart';
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
                  icon: Icons.bug_report_outlined,
                  title: 'Report a problem',
                  subtitle: 'Or share an idea. Tip: shake your phone anywhere',
                  onTap: () => BugReport.open(context),
                ),
                SioTile(
                  icon: Icons.inbox_outlined,
                  title: 'My reports',
                  subtitle: 'See replies from the SIO Connect team',
                  onTap: () => push(context, const MyReportsScreen()),
                ),
                const _ShakeTile(),
              ],
              if (AppState.i.can('handle_feedback'))
                SioTile(
                  icon: Icons.bug_report,
                  title: 'Bug reports & feedback',
                  subtitle: 'Reports from students, with screenshots',
                  onTap: () => push(context, const FeedbackInboxScreen()),
                ),
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
                  subtitle: 'Today, programmes, friends and prayer',
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
  const ProfileScreen({super.key, this.focusPrivacy = false});
  final bool focusPrivacy;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// Life stages people pick in their profile (and in the welcome steps).
const lifeStages = [
  ('School', 'Plus One / Plus Two', Icons.backpack_outlined),
  ('College', 'Degree, PG or diploma', Icons.school_outlined),
  ('Working', 'Job or own business', Icons.work_outline),
];

const phoneChoices = [
  ('Leaders only', 'Only SIO leaders (default)'),
  ('Friends', 'My SIO friends'),
  ('My unit', 'Everyone in my unit'),
  ('All members', 'All SIO members'),
];

class _ProfileScreenState extends State<ProfileScreen> {
  final me = AppState.i.me;
  late final _campus = TextEditingController(text: (me['campus'] ?? '').toString());
  late final _course = TextEditingController(text: (me['course'] ?? '').toString());
  late final _town = TextEditingController(text: (me['home_town'] ?? '').toString());
  late final _profession = TextEditingController(text: (me['profession'] ?? '').toString());
  late final _workplace = TextEditingController(text: (me['workplace'] ?? '').toString());
  late final _city = TextEditingController(text: (me['current_city'] ?? '').toString());
  late final _mentor = TextEditingController(text: (me['mentor_topics'] ?? '').toString());
  late String? _stage = (me['life_stage'] ?? '').toString().isEmpty ? null : '${me['life_stage']}';
  late String _phone = '${me['phone_visibility'] ?? 'Leaders only'}';
  late bool _hideGames = '${me['hide_games']}' == '1';
  late String? _year = (me['year_of_study'] ?? '').toString().isEmpty ? null : me['year_of_study'].toString();
  late String? _unit = me['unit']?.toString();
  List<dynamic> _units = [];
  bool _busy = false;
  late final GeoPoint? _loc = GeoPoint.from(me['latitude'], me['longitude']);
  late final _landmark = TextEditingController(text: (me['location_note'] ?? '').toString());
  final _privacyKey = GlobalKey();

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
  static const schoolYears = ['Plus One', 'Plus Two', 'Other'];

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
    if (widget.focusPrivacy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _privacyKey.currentContext;
        if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300));
      });
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(context, () async {
      final r = await Api.call('${Api.m}update_my_profile', {
        'life_stage': _stage ?? '',
        'campus': _stage == 'Working' ? '' : _campus.text.trim(),
        'course': _stage == 'Working' ? '' : _course.text.trim(),
        'year_of_study': _stage == 'Working' ? '' : _year,
        'profession': _stage == 'Working' ? _profession.text.trim() : '',
        'workplace': _stage == 'Working' ? _workplace.text.trim() : '',
        'current_city': _city.text.trim(),
        'mentor_topics': _stage == 'School' ? '' : _mentor.text.trim(),
        'phone_visibility': _phone,
        'hide_games': _hideGames ? 1 : 0,
        'home_town': _town.text.trim().isEmpty ? null : _town.text.trim(),
        'unit': AppState.i.pending ? _unit : null,
        'latitude': _loc?.lat,
        'longitude': _loc?.lng,
        'clear_location': _loc == null ? 1 : null,
        'location_note': _landmark.text.trim(),
      });
      AppState.i.me = Map<String, dynamic>.from(r as Map);
      await Api.prefs.setString('me_cache', jsonEncode(AppState.i.me));
      AppState.i.refreshAll();
    }, done: 'Profile saved.');
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context);
    }
  }

  Widget _field(TextEditingController c, String label, {String? hint, int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: lines > 1),
    ),
  );

  Widget _section(String t, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.fromLTRB(2, 10, 0, 10),
    child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
  );

  @override
  Widget build(BuildContext context) {
    final pending = AppState.i.pending;
    final school = _stage == 'School';
    final working = _stage == 'Working';
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
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    await pickUsername(context, '${me['username'] ?? ''}');
                    if (mounted) setState(() {});
                  },
                  child: Text(
                    '${me['username'] ?? ''}'.isEmpty ? '+ Choose a username' : '@${me['username']} · change',
                    style: TextStyle(color: SioColors.blue, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (pending && _units.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _units.any((u) => u['name'] == _unit) ? _unit : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: [for (final u in _units) DropdownMenuItem(value: u['name'].toString(), child: Text(u['name'].toString()))],
              onChanged: (v) => setState(() => _unit = v),
            ),
          ],
          _section('Where are you in life?'),
          StagePicker(value: _stage, onChanged: (v) => setState(() => _stage = v)),
          const SizedBox(height: 16),
          if (working) ...[
            _field(_profession, 'Profession', hint: 'e.g. Software engineer, Doctor, Teacher, Business'),
            _field(_workplace, 'Workplace (optional)', hint: 'Company, hospital, school or own business'),
          ] else if (_stage != null) ...[
            _field(_campus, school ? 'School' : 'College / campus'),
            _field(_course, school ? 'Stream (e.g. Science, Commerce)' : 'Course'),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                initialValue: (school ? schoolYears : years).contains(_year) ? _year : null,
                decoration: const InputDecoration(labelText: 'Year'),
                items: [for (final y in (school ? schoolYears : years)) DropdownMenuItem(value: y, child: Text(y))],
                onChanged: (v) => setState(() => _year = v),
              ),
            ),
          ],
          _field(_city, 'Lives in (city or town now)', hint: 'Where you study or work, e.g. Kochi, Bengaluru'),
          _field(_town, 'Home town'),
          _section('Privacy', key: _privacyKey),
          const Text('Who can see my phone number', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          RadioGroup<String>(
            groupValue: _phone,
            onChanged: (v) => setState(() => _phone = v ?? _phone),
            child: Column(
              children: [
                for (final c in phoneChoices)
                  RadioListTile<String>(dense: true, contentPadding: EdgeInsets.zero, value: c.$1, title: Text(c.$2)),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _hideGames,
            onChanged: (v) => setState(() => _hideGames = v),
            title: const Text('Hide streaks, badges and leaderboards'),
            subtitle: const Text('You still get the daily ayah. You won’t appear on leaderboards.'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

/// School / College / Working as three big choices.
class StagePicker extends StatelessWidget {
  const StagePicker({super.key, required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final s in lifeStages)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(s.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                decoration: BoxDecoration(
                  color: value == s.$1 ? SioColors.blue.withValues(alpha: 0.10) : SioColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: value == s.$1 ? SioColors.blue : SioColors.border, width: value == s.$1 ? 2 : 1),
                ),
                child: Column(
                  children: [
                    Icon(s.$3, color: value == s.$1 ? SioColors.blue : SioColors.textSecondary, size: 28),
                    const SizedBox(height: 6),
                    Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      s.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: SioColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
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

class _ShakeTile extends StatefulWidget {
  const _ShakeTile();

  @override
  State<_ShakeTile> createState() => _ShakeTileState();
}

class _ShakeTileState extends State<_ShakeTile> {
  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(Icons.vibration, color: SioColors.blue),
    title: const Text('Shake to report a problem'),
    value: BugReport.shakeOn,
    onChanged: (v) async {
      await BugReport.setShake(v);
      setState(() {});
    },
  );
}
