import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../noor.dart';
import '../prayer.dart';
import '../prayer_alarms.dart';
import '../theme.dart';

/// The full-screen reminder 15 minutes after the azan: it shows over the lock screen like an alarm,
/// with the ayah being recited and its meaning, so people read what they hear.
class PrayerAlarmScreen extends StatefulWidget {
  const PrayerAlarmScreen({super.key, required this.prayer, required this.offset, this.id});
  final String prayer;
  final int offset;
  final int? id; // the notification, so closing this screen stops its sound

  @override
  State<PrayerAlarmScreen> createState() => _PrayerAlarmScreenState();
}

class _PrayerAlarmScreenState extends State<PrayerAlarmScreen> {
  static const _deep = Color(0xFF0E3F70);
  static const _sio = Color(0xFF1A62A8);
  static const _pale = Color(0xFFE6F2FD);
  static const _pale2 = Color(0xFFCFE5FA);

  @override
  void initState() {
    super.initState();
    PrayerAlarms.overLockScreen(true);
  }

  @override
  void dispose() {
    PrayerAlarms.overLockScreen(false);
    super.dispose();
  }

  Future<void> _close() async {
    await PrayerAlarms.stop(widget.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ml = PrayerTimes.ml[widget.prayer] ?? '';
    final title = widget.offset > 0
        ? 'Did you pray ${widget.prayer}?'
        : widget.offset < 0
        ? '${widget.prayer} in ${-widget.offset} minutes'
        : 'It’s time for ${widget.prayer}';
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) PrayerAlarms.stop(widget.id);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_pale2, _pale, Colors.white]),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  children: [
                    const Spacer(),
                    const Noor(mood: NoorMood.waiting, size: 120),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _deep),
                    ),
                    if (ml.isNotEmpty)
                      Text(ml, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _sio)),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: _pale2, width: 2),
                        boxShadow: const [BoxShadow(color: Color(0x1A0E3F70), blurRadius: 24, offset: Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          Text(
                            PrayerAlarms.ayahText,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: arabicStyle(color: _deep, size: 30),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            PrayerAlarms.ayahMeaningMl,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w700, color: Color(0xFF1F1F23)),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Every soul will taste death, then to Us you will be returned.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15.5, height: 1.4, color: Color(0xFF4A5563)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Qur’an 29:57',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _sio),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _sio,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: _close,
                        child: const Text('I’m going to pray 🤲', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _close,
                      child: const Text('Close', style: TextStyle(color: _sio, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
