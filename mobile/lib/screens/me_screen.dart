import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../app_state.dart';
import '../fx.dart';
import '../noor.dart';
import '../theme.dart';
import '../widgets.dart';
import 'card_screens.dart';
import 'more_screen.dart';
import 'today_screen.dart' show setPot;

// A person's page, kept simple: who they are, their sprout and streak. Mine adds edit, SIO card and settings.

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);
int _i(dynamic v) => numOf(v).toInt();

/// Their sprout as it is today: watered (happy), still waiting, or dried up.
NoorMood moodOf(Map<String, dynamic> reading) {
  final cur = _i(reading['current']);
  if (reading['today'] == true) return NoorMood.happy;
  if (cur == 0) return NoorMood.out;
  return noorMood(readToday: false, streak: cur, missedYesterday: false);
}

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My page', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [
        IconButton(
          tooltip: 'Settings and more',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => push(context, const MoreScreen()),
        ),
      ],
    ),
    body: Loader<Map<String, dynamic>>(
      cacheKey: 'profile_me',
      load: () async {
        final p = _m(await Api.call('${Api.m}profile'));
        try {
          final j = _m(await Api.call('${Api.m}journey'));
          p['_pots'] = _i(_m(j['series'])['pots_unlocked']);
          if (j['pot'] != null) Noor.myPot = '${j['pot']}';
        } catch (_) {}
        return p;
      },
      builder: (context, p) => [
        _Who(p: p),
        const SizedBox(height: 16),
        _SproutCard(p: p, mine: true),
        const SizedBox(height: 16),
        if (p['_pots'] != null) ...[_PotPicker(unlocked: math.max(1, _i(p['_pots']))), const SizedBox(height: 16)],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => push(context, const ProfileScreen()),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => push(context, const MemberCardScreen()),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('My SIO card'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class PersonView extends StatelessWidget {
  const PersonView({super.key, this.member, this.username});
  final String? member;
  final String? username;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: Loader<Map<String, dynamic>>(
      cacheKey: 'profile_${member ?? username}',
      load: () async => _m(await Api.call('${Api.m}profile', {'member': ?member, 'username': ?username})),
      builder: (context, p) {
        final st = '${_m(p['friend'])['state']}';
        final mobile = '${p['mobile'] ?? ''}';
        return [
          _Who(p: p),
          const SizedBox(height: 16),
          if (p['hide_games'] != 1 && p['reading'] != null) ...[_SproutCard(p: p), const SizedBox(height: 16)],
          Row(
            children: [
              Expanded(
                child: FriendAction(member: '${p['member']}', state: st),
              ),
              if (mobile.isNotEmpty) ...[
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Call',
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => launchUrl(Uri.parse('tel:$mobile')),
                ),
              ],
            ],
          ),
        ];
      },
    ),
  );
}

class _Who extends StatelessWidget {
  const _Who({required this.p});
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final handle = '${p['username'] ?? ''}';
    return Column(
      children: [
        Avatar('${p['full_name'] ?? ''}', radius: 44, photo: p['photo']),
        const SizedBox(height: 10),
        Text(
          '${p['full_name'] ?? ''}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: SioColors.ink),
        ),
        Text(
          [if (handle.isNotEmpty) '@$handle', if (p['unit'] != null) '${p['unit']}'].join(' · '),
          textAlign: TextAlign.center,
          style: TextStyle(color: SioColors.textSecondary),
        ),
        if (_i(p['friends']) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${_i(p['friends'])} friends',
              style: TextStyle(color: SioColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _SproutCard extends StatelessWidget {
  const _SproutCard({required this.p, this.mine = false});
  final Map<String, dynamic> p;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final r = _m(p['reading']);
    final cur = _i(r['current']);
    final mood = moodOf(r);
    final first = '${p['full_name'] ?? ''}'.split(' ').first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE6F2FD), Color(0xFFCFE5FA)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Noor(mood: mood, size: 96, stage: sproutStage(cur)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mood == NoorMood.out
                      ? (mine ? 'Your Noor dried up' : '$first’s Noor dried up')
                      : sproutStageNames[sproutStage(cur)],
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0E3F70)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF8A1F)),
                    Text(
                      ' $cur day${cur == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2F7BC4)),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFE5A400), size: 20),
                    Text(
                      ' best ${_i(r['best'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2F7BC4)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r['today'] == true
                      ? (mine ? 'Watered today ✓' : 'Watered today ✓')
                      : cur == 0
                      ? (mine ? 'Read today’s ayah to plant it again' : 'Not watered for a while')
                      : (mine ? 'Thirsty: read today’s ayah' : 'Hasn’t watered yet today'),
                  style: const TextStyle(color: Color(0xFF2F7BC4), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Add / accept / cancel / unfriend.
class FriendAction extends StatelessWidget {
  const FriendAction({super.key, required this.member, required this.state, this.compact = false});
  final String member;
  final String state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Future<void> act(Map<String, dynamic> a, String done) async {
      HapticFeedback.selectionClick();
      await run(context, () => Api.call('${Api.m}friend_request', {'member': member, ...a}), done: done);
      AppState.i.refreshAll();
    }

    switch (state) {
      case 'friends':
        return OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                content: const Text('Remove this friend?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
                ],
              ),
            );
            if (ok == true) await act({'remove': 1}, 'Removed');
          },
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Friends'),
        );
      case 'sent':
        return OutlinedButton(onPressed: () => act({'remove': 1}, 'Request cancelled'), child: const Text('Requested'));
      case 'received':
        return FilledButton(onPressed: () => act({}, 'You are now friends'), child: const Text('Accept'));
      case 'self':
        return const SizedBox.shrink();
      default:
        return FilledButton.icon(
          onPressed: () => act({}, 'Friend request sent'),
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: Text(compact ? 'Add' : 'Add friend'),
        );
    }
  }
}

/// 👋 to a friend who hasn't watered their sprout today.
class NudgeButton extends StatelessWidget {
  const NudgeButton({super.key, required this.member});
  final String member;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (bctx) => IconButton(
      tooltip: 'Nudge to read today',
      icon: const Text('👋', style: TextStyle(fontSize: 22)),
      onPressed: () async {
        HapticFeedback.mediumImpact();
        burst(bctx, emojis: const ['👋', '💧', '🌱'], count: 12, power: 0.7);
        try {
          final r = _m(await Api.call('${Api.m}nudge', {'member': member}));
          if (context.mounted) toast(context, r['already'] == 1 ? 'Already nudged today' : 'Nudge sent 👋');
        } on ApiException catch (e) {
          if (context.mounted) toast(context, e.message);
        }
      },
    ),
  );
}

/// Noor's pots: one new colour from each week's chest. Tap one you've won to use it.
class _PotPicker extends StatefulWidget {
  const _PotPicker({required this.unlocked});
  final int unlocked;

  @override
  State<_PotPicker> createState() => _PotPickerState();
}

class _PotPickerState extends State<_PotPicker> {
  @override
  Widget build(BuildContext context) {
    final keys = potColours.keys.toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: SioColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCFE5FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'NOOR’S POTS · ${widget.unlocked} of ${keys.length}',
              style: const TextStyle(color: Color(0xFF1A62A8), fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 6),
            child: Text(
              'Finish a week of the series to open its chest and win a new pot.',
              style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
            ),
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            children: [
              for (var i = 0; i < keys.length; i++)
                Builder(
                  builder: (context) {
                    final k = keys[i];
                    final won = i < widget.unlocked;
                    final mine = Noor.myPot == k;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        if (!won) {
                          toast(
                            context,
                            'Finish ${i - widget.unlocked + 1} more week${i - widget.unlocked + 1 == 1 ? '' : 's'} to win this one 🎁',
                          );
                          return;
                        }
                        setState(() {});
                        await setPot(k);
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: mine ? const Color(0xFFE6F2FD) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: mine ? const Color(0xFF1A62A8) : Colors.transparent, width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Opacity(
                              opacity: won ? 1 : 0.3,
                              child: Noor(mood: NoorMood.happy, size: 52, pot: k, animate: false),
                            ),
                            Text(
                              won ? potColours[k]!.$1 : '🔒',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: won ? SioColors.ink : SioColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
