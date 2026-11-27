import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

import '../home_widget_sync.dart';
import '../prayer.dart';
import '../prayer_alarms.dart';
import '../theme.dart';
import '../widgets.dart';
import 'qibla_screen.dart';

// The Prayer tab: the next prayer with a countdown, today's five times (tap the bell to turn a prayer's reminders
// on or off), the Qibla, and the reminder settings: when (at azan, before, after) and which sound.

class PrayerTab extends StatefulWidget {
  const PrayerTab({super.key});

  @override
  State<PrayerTab> createState() => _PrayerTabState();
}

class _PrayerTabState extends State<PrayerTab> {
  PrayerTimes? _p;
  Set<String> _on = {};
  List<int> _offs = [];
  String _sound = 'chime';
  bool _enabled = true;
  bool _exact = true;
  String? _custom; // name of the uploaded sound
  Timer? _tick;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    final p = await PrayerTimes.load();
    if (p != null) HomeWidgetSync.prayers(p.times);
    final on = await PrayerAlarms.prayersOn();
    final offs = await PrayerAlarms.offsets();
    final snd = await PrayerAlarms.sound();
    final en = await PrayerAlarms.enabled();
    final ex = await PrayerAlarms.exactAllowed();
    final custom = await PrayerAlarms.customName();
    if (mounted) {
      setState(() {
        _p = p;
        _on = on;
        _offs = offs;
        _sound = snd;
        _enabled = en;
        _exact = ex;
        _custom = custom;
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _hm(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  Future<void> _addCustom() async {
    var mins = 10;
    var after = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Add a reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Before')),
                  ButtonSegment(value: true, label: Text('After')),
                ],
                selected: {after},
                onSelectionChanged: (v) => set(() => after = v.first),
              ),
              const SizedBox(height: 12),
              Text('$mins minutes ${after ? 'after' : 'before'} azan', style: const TextStyle(fontWeight: FontWeight.w800)),
              Slider(value: mins.toDouble(), min: 1, max: 60, divisions: 59, onChanged: (v) => set(() => mins = v.round())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final o = after ? mins : -mins;
      setState(() => _offs = {..._offs, o}.toList()..sort());
      await PrayerAlarms.save(offsets: _offs);
    }
  }

  Future<void> _toggleOffset(int o) async {
    HapticFeedback.selectionClick();
    final next = _offs.contains(o) ? (_offs.toList()..remove(o)) : ([..._offs, o]..sort());
    setState(() => _offs = next);
    await PrayerAlarms.save(offsets: next);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final next = p?.next;
    final left = next?.value.difference(DateTime.now());
    final presets = {-10, -5, 0, 15, 30, ..._offs}.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: () => push(context, const QiblaScreen()),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Qibla'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            if (p == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF7FBFF), Color(0xFFDDEEFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFCFE5FA), width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NEXT PRAYER',
                            style: TextStyle(
                              color: Color(0xFF2F7BC4),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${next!.key} · ${PrayerTimes.ml[next.key]}',
                            style: const TextStyle(color: Color(0xFF0E3F70), fontWeight: FontWeight.w900, fontSize: 24),
                          ),
                          Text(
                            '${_hm(next.value)} · in ${left!.inHours > 0 ? '${left.inHours}h ' : ''}${left.inMinutes % 60}m',
                            style: const TextStyle(color: Color(0xFF1A62A8), fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 14, color: Color(0xFF6B8299)),
                              Text(p.place, style: const TextStyle(color: Color(0xFF6B8299), fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Text('🕌', style: TextStyle(fontSize: 56)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final n in PrayerTimes.names)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: n == next.key
                        ? SioColors.blue.withValues(alpha: 0.12)
                        : (SioColors.dark ? SioColors.card : const Color(0xFFF1F7FD)),
                    borderRadius: BorderRadius.circular(16),
                    border: n == next.key ? Border.all(color: SioColors.blue.withValues(alpha: 0.5)) : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: n,
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: SioColors.ink),
                              ),
                              TextSpan(
                                text: '  ${PrayerTimes.ml[n]}',
                                style: TextStyle(color: SioColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        _hm(p.times[n]!),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: SioColors.ink),
                      ),
                      IconButton(
                        tooltip: _on.contains(n) ? 'Reminders on for $n' : 'Reminders off for $n',
                        icon: Icon(
                          _on.contains(n) && _enabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                          color: _on.contains(n) && _enabled ? SioColors.blue : SioColors.textSecondary,
                        ),
                        onPressed: () async {
                          HapticFeedback.selectionClick();
                          final on = {..._on};
                          on.contains(n) ? on.remove(n) : on.add(n);
                          setState(() => _on = on);
                          await PrayerAlarms.save(on: on);
                          if (context.mounted) toast(context, on.contains(n) ? '$n reminders on' : '$n reminders off');
                        },
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Prayer reminders', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Times update by themselves every day'),
              value: _enabled,
              onChanged: (v) async {
                setState(() => _enabled = v);
                await PrayerAlarms.save(enabled: v);
              },
            ),
            if (_enabled) ...[
              if (!_exact)
                Card(
                  color: SioColors.warningBg,
                  child: ListTile(
                    leading: Icon(Icons.alarm, color: SioColors.warning),
                    title: const Text('Allow exact reminders'),
                    subtitle: const Text('So reminders ring at the exact minute, not a few minutes late'),
                    onTap: () async {
                      await PrayerAlarms.askExact();
                      await _load();
                      await PrayerAlarms.schedule();
                    },
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Remind me',
                style: TextStyle(fontWeight: FontWeight.w800, color: SioColors.ink),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in presets)
                    FilterChip(
                      label: Text(PrayerAlarms.offsetLabel(o)),
                      selected: _offs.contains(o),
                      onSelected: (_) => _toggleOffset(o),
                    ),
                  ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Other time'), onPressed: _addCustom),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Sound',
                style: TextStyle(fontWeight: FontWeight.w800, color: SioColors.ink),
              ),
              RadioGroup<String>(
                groupValue: _sound,
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _sound = v);
                  if (v != 'default') {
                    try {
                      if (v == 'custom') {
                        final path = await PrayerAlarms.customPath();
                        if (path != null) await _player.setFilePath(path);
                      } else {
                        await _player.setAsset('assets/sounds/prayer_$v.ogg');
                      }
                      await _player.play();
                    } catch (_) {}
                  }
                  await PrayerAlarms.save(sound: v);
                },
                child: Column(
                  children: [
                    for (final e in PrayerAlarms.sounds.entries)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: e.key,
                        title: Text(e.value),
                        subtitle: e.key == 'ayah'
                            ? const Text(
                                'كُلُّ نَفْسٍ ذَائِقَةُ الْمَوْتِ ۖ ثُمَّ إِلَيْنَا تُرْجَعُونَ\nEvery soul will taste death, then to Us you will return · Mishary Alafasy',
                              )
                            : null,
                      ),
                    if (_custom != null)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: 'custom',
                        title: Text(_custom!),
                        subtitle: const Text('Your uploaded sound · plays in full, at alarm volume'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      _player.stop();
                      final name = await PrayerAlarms.pickCustom();
                      if (name == null) return;
                      await _load();
                      if (context.mounted) toast(context, '“$name” will play for prayer reminders');
                    } catch (e) {
                      if (context.mounted) toast(context, '$e'.replaceFirst('Exception: ', ''));
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(_custom == null ? 'Upload a sound (e.g. an azan)' : 'Upload a different sound'),
                ),
              ),
              Text(
                'Download an azan or any sound you like to your phone, then upload it here.',
                style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => PrayerAlarms.test(),
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Send me a test reminder'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
