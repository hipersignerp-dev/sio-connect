import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'api.dart';
import 'app_state.dart';
import 'links.dart';
import 'theme.dart';
import 'update_service.dart';
import 'widgets.dart';

/// Reporting problems: from the menu, or by shaking the phone anywhere in the app. A screenshot of the screen is
/// attached (the person can leave it out). Reports land in SIO Feedback; admins answer them from the app.
class BugReport {
  /// Wraps the whole app (see main.dart), so the current screen can be captured.
  static final shotKey = GlobalKey();
  static StreamSubscription<UserAccelerometerEvent>? _shake;
  static bool _open = false;
  static final _hits = <DateTime>[];

  static bool get shakeOn => Api.prefs.getBool('shake_report') ?? true;

  static Future<void> setShake(bool on) async {
    await Api.prefs.setBool('shake_report', on);
    on ? startShake() : _shake?.cancel();
  }

  /// Shake the phone (three quick shakes) to report a problem.
  static void startShake() {
    _shake?.cancel();
    if (!shakeOn) return;
    try {
      _shake = userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
        final g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (g < 14) return;
        final now = DateTime.now();
        _hits.removeWhere((t) => now.difference(t).inMilliseconds > 1200);
        _hits.add(now);
        if (_hits.length >= 3) {
          _hits.clear();
          final ctx = navKey.currentContext;
          if (ctx != null && ctx.mounted && AppState.i.me['member'] != null) open(ctx, fromShake: true);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  static Future<Uint8List?> _capture() async {
    try {
      final b = shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (b == null) return null;
      final img = await b.toImage(pixelRatio: 0.7);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<void> open(BuildContext context, {bool fromShake = false}) async {
    if (_open) return;
    _open = true;
    final shot = await _capture();
    if (!context.mounted) {
      _open = false;
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReportSheet(shot: shot, fromShake: fromShake),
    );
    _open = false;
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.shot, required this.fromShake});
  final Uint8List? shot;
  final bool fromShake;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _text = TextEditingController();
  String _kind = 'Problem';
  bool _withShot = true;
  bool _busy = false;

  Future<void> _send() async {
    if (_text.text.trim().isEmpty) {
      toast(context, 'Please write what happened.');
      return;
    }
    setState(() => _busy = true);
    var device = '';
    try {
      final a = await DeviceInfoPlugin().androidInfo;
      device = '${a.manufacturer} ${a.model} · Android ${a.version.release}';
    } catch (_) {}
    if (!mounted) return;
    final ok = await run(
      context,
      () => Api.call('${Api.m}send_feedback', {
        'kind': _kind,
        'message': _text.text.trim(),
        'app_build': UpdateService.versionLabel,
        'device': device,
        if (_withShot && widget.shot != null) 'screenshot': base64Encode(widget.shot!),
      }),
      done: 'Thank you! The SIO Connect team will look at it.',
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.fromShake ? 'Something not working? 🐞' : 'Report a problem',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell us what happened. We’ll reply in the app when it’s fixed.',
            style: TextStyle(color: SioColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final k in const [('Problem', '🐞 Problem'), ('Idea', '💡 Idea'), ('Other', '💬 Other')])
                ChoiceChip(
                  label: Text(k.$2),
                  selected: _kind == k.$1,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _kind = k.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 6,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. The photo did not upload when I tapped Add. English or Malayalam is fine.',
            ),
          ),
          if (widget.shot != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Opacity(
                    opacity: _withShot ? 1 : 0.3,
                    child: Image.memory(widget.shot!, height: 140, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _withShot,
                    onChanged: (v) => setState(() => _withShot = v),
                    title: const Text('Attach this screenshot'),
                    subtitle: const Text('Only the app team sees it'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'Sending…' : 'Send')),
          ),
          if (widget.fromShake)
            Center(
              child: TextButton(
                onPressed: () async {
                  await BugReport.setShake(false);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Turn off shake to report'),
              ),
            ),
        ],
      ),
    ),
  );
}

/// The problems and ideas I sent, with their status and the team's reply.
class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My reports')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => BugReport.open(context),
      icon: const Icon(Icons.bug_report_outlined),
      label: const Text('Report a problem'),
    ),
    body: Loader<List<dynamic>>(
      load: () async => (await Api.call('${Api.m}my_feedback')) as List<dynamic>,
      builder: (context, rows) => [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              'Nothing reported yet. If something doesn’t work, shake your phone or tap the button below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SioColors.textSecondary),
            ),
          ),
        for (final r in rows.map((x) => Map<String, dynamic>.from(x as Map)))
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        r['kind'] == 'Idea'
                            ? '💡'
                            : r['kind'] == 'Problem'
                            ? '🐞'
                            : '💬',
                      ),
                      const SizedBox(width: 6),
                      Text(fmtDate(r['creation']), style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: r['status'] == 'Done' ? SioColors.greenBg : SioColors.card,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          r['status'] == 'Done'
                              ? '✓ Fixed'
                              : r['status'] == 'Seen'
                              ? 'Seen by team'
                              : 'Sent',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: r['status'] == 'Done' ? SioColors.green : SioColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${r['message'] ?? r['summary'] ?? ''}'),
                  if ('${r['reply'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SioColors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('SIO Connect team: ${r['reply']}', style: TextStyle(color: SioColors.ink)),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Admins: bug reports and feedback, with screenshot, phone and app version; mark Seen / Fixed and reply.
class FeedbackInboxScreen extends StatefulWidget {
  const FeedbackInboxScreen({super.key});

  @override
  State<FeedbackInboxScreen> createState() => _FeedbackInboxScreenState();
}

class _FeedbackInboxScreenState extends State<FeedbackInboxScreen> {
  String _status = 'New';
  int _v = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bug reports & feedback')),
    body: Loader<Map<String, dynamic>>(
      key: ValueKey('$_status$_v'),
      load: () async => Map<String, dynamic>.from(await Api.call('${Api.m}feedback_inbox', {'status': _status}) as Map),
      builder: (context, d) {
        final counts = Map<String, dynamic>.from((d['counts'] ?? {}) as Map);
        final rows = [for (final x in (d['rows'] as List? ?? [])) Map<String, dynamic>.from(x as Map)];
        return [
          Wrap(
            spacing: 8,
            children: [
              for (final s in const ['New', 'Seen', 'Done'])
                ChoiceChip(
                  label: Text('${s == 'Done' ? 'Fixed' : s} (${counts[s] ?? 0})'),
                  selected: _status == s,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Nothing here 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(color: SioColors.textSecondary),
              ),
            ),
          for (final r in rows)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Text(
                  r['kind'] == 'App error'
                      ? '⚠️'
                      : r['kind'] == 'Idea'
                      ? '💡'
                      : r['kind'] == 'Problem'
                      ? '🐞'
                      : '💬',
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text('${r['summary'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    '${r['full_name'] ?? ''}',
                    if ('${r['unit'] ?? ''}'.isNotEmpty) '${r['unit']}',
                    fmtDate(r['creation']),
                    if ('${r['screenshot'] ?? ''}'.isNotEmpty) '📷',
                  ].join(' · '),
                ),
                onTap: () async {
                  final changed = await Navigator.of(context)
                      .push<bool>(MaterialPageRoute(builder: (_) => _FeedbackDetail(r: r)));
                  if (changed == true) setState(() => _v++);
                },
              ),
            ),
        ];
      },
    ),
  );
}

class _FeedbackDetail extends StatefulWidget {
  const _FeedbackDetail({required this.r});
  final Map<String, dynamic> r;

  @override
  State<_FeedbackDetail> createState() => _FeedbackDetailState();
}

class _FeedbackDetailState extends State<_FeedbackDetail> {
  late final _reply = TextEditingController(text: '${widget.r['reply'] ?? ''}');
  bool _busy = false;

  Future<void> _set(String status) async {
    setState(() => _busy = true);
    final ok = await run(
      context,
      () => Api.call('${Api.m}feedback_update', {
        'name': widget.r['name'],
        'status': status,
        'reply': _reply.text.trim() == '${widget.r['reply'] ?? ''}' ? '' : _reply.text.trim(),
      }),
      done: status == 'Done' ? 'Marked fixed. They got a notice.' : 'Saved',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final shot = '${r['screenshot'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: Text('${r['kind']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${r['full_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(
            [
              fmtDate(r['creation']),
              '${r['unit'] ?? ''}',
              '${r['device'] ?? ''}',
              'build ${r['app_build'] ?? ''}',
            ].where((x) => x.trim().isNotEmpty).join(' · '),
            style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          SelectableText('${r['message'] ?? ''}', style: const TextStyle(fontSize: 15, height: 1.4)),
          if (shot.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                '${Api.baseUrl}$shot',
                headers: Api.authHeaders,
                errorBuilder: (_, _, _) => const Padding(padding: EdgeInsets.all(12), child: Text('Screenshot could not load')),
              ),
            ),
          ],
          if (r['kind'] != 'App error') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _reply,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reply (they get it as a notice)',
                hintText: 'e.g. Thanks! Fixed in the next update.',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: _busy ? null : () => _set('Seen'), child: const Text('Mark seen')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(onPressed: _busy ? null : () => _set('Done'), child: const Text('Fixed ✅')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
