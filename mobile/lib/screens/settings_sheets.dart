import 'package:device_info_plus/device_info_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../look.dart';
import '../notify.dart';
import '../theme.dart';
import '../update_service.dart';
import '../widgets.dart';

/// Theme (light / dark / phone) and text size.
Future<void> showAppearance(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => StatefulBuilder(
    builder: (context, setState) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Appearance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            const Text('Text size', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 1.0, label: Text('A', style: TextStyle(fontSize: 14))),
                ButtonSegment(value: 1.15, label: Text('A', style: TextStyle(fontSize: 18))),
                ButtonSegment(value: 1.3, label: Text('A', style: TextStyle(fontSize: 22))),
              ],
              selected: {Look.textScale},
              onSelectionChanged: (v) async {
                await Look.set(scale: v.first);
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
            Text(
              'ഇന്നത്തെ ആയത്ത് വായിക്കാം · Read today’s ayah',
              style: malayalamStyle(size: 15 * Look.textScale, color: SioColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// When the daily ayah reminder comes (or off).
Future<void> showReminderPicker(BuildContext context) async {
  const options = [
    ('05:30', 'After Fajr · 5:30 AM'),
    ('07:30', 'Morning · 7:30 AM'),
    ('13:30', 'After lunch · 1:30 PM'),
    ('20:00', 'Evening · 8:00 PM'),
    ('22:00', 'Before sleep · 10:00 PM'),
    ('off', 'No reminder'),
  ];
  final now = Notify.reminderTime ?? 'off';
  final pick = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'One gentle reminder a day, only if you haven’t read yet.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          for (final o in options)
            ListTile(
              leading: Icon(o.$1 == now ? Icons.radio_button_checked : Icons.radio_button_off, color: SioColors.blue),
              title: Text(o.$2),
              onTap: () => Navigator.of(context).pop(o.$1),
            ),
        ],
      ),
    ),
  );
  if (pick == null) return;
  await Notify.setReminder(pick == 'off' ? null : pick);
  if (context.mounted) toast(context, pick == 'off' ? 'Reminder turned off' : 'Reminder set');
}

String reminderLabel() {
  final t = Notify.reminderTime;
  if (t == null) return 'Off';
  final p = t.split(':');
  final h = int.parse(p[0]);
  return 'Every day at ${h % 12 == 0 ? 12 : h % 12}:${p[1]} ${h < 12 ? 'AM' : 'PM'}, if not read yet';
}

/// Feedback straight to the area team (with the app build and phone model, to help fix problems).
Future<void> showFeedback(BuildContext context) async {
  final ctl = TextEditingController();
  var kind = 'Idea';
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send feedback', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Something not working, confusing, or an idea? Tell us. The SIO Connect team reads every message.',
              style: TextStyle(color: SioColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final k in ['Problem', 'Idea', 'Other'])
                  ChoiceChip(
                    label: Text(
                      k == 'Problem'
                          ? '🐞 Problem'
                          : k == 'Idea'
                          ? '💡 Idea'
                          : '💬 Other',
                    ),
                    selected: kind == k,
                    onSelected: (_) => setState(() => kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              minLines: 3,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Write in English or Malayalam'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (ctl.text.trim().isEmpty) return;
                  var device = '';
                  try {
                    final a = await DeviceInfoPlugin().androidInfo;
                    device = '${a.manufacturer} ${a.model} · Android ${a.version.release}';
                  } catch (_) {}
                  if (!context.mounted) return;
                  final ok = await run(
                    context,
                    () => Api.call('${Api.m}send_feedback', {
                      'kind': kind,
                      'message': ctl.text.trim(),
                      'app_build': UpdateService.versionLabel,
                      'device': device,
                    }),
                    done: 'Thank you! We got your message.',
                  );
                  if (ok && context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
