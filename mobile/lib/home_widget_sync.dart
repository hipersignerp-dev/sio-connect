import 'package:home_widget/home_widget.dart';

/// Keeps the home-screen widget (Android, AyahWidgetProvider) in step with the app: today's ayah, the streak
/// and the prayer times. Quietly does nothing where widgets aren't supported.
class HomeWidgetSync {
  static Future<void> _refresh() async {
    await HomeWidget.updateWidget(androidName: 'AyahWidgetProvider');
    await HomeWidget.updateWidget(androidName: 'NoorWidgetProvider');
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  static Future<void> reading(
    Map<String, dynamic>? r, {
    required int streak,
    required bool readToday,
    bool missed = false,
    String name = '',
    bool games = true,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('w_name', name);
      await HomeWidget.saveWidgetData<bool>('w_hide_games', !games);
      await HomeWidget.saveWidgetData<bool>('w_missed', missed);
      if (readToday) await HomeWidget.saveWidgetData<String>('w_read_day', _today());
      if (r != null) {
        final ml = '${r['text_ml'] ?? ''}';
        await HomeWidget.saveWidgetData<String>('w_text', ml.isNotEmpty ? ml : '“${r['text_en'] ?? ''}”');
        await HomeWidget.saveWidgetData<String>('w_ref', '${r['reference'] ?? ''}');
        await HomeWidget.saveWidgetData<String>('w_kind', '${r['kind'] ?? ''}');
        await HomeWidget.saveWidgetData<String>('w_day', _today());
      }
      await HomeWidget.saveWidgetData<int>('w_streak', streak);
      await HomeWidget.saveWidgetData<bool>('w_read', readToday);
      await _refresh();
    } catch (_) {}
  }

  /// times: prayer name → time today.
  static Future<void> prayers(Map<String, DateTime> times) async {
    try {
      String two(int n) => n.toString().padLeft(2, '0');
      final s = times.entries.map((e) => '${e.key}|${two(e.value.hour)}:${two(e.value.minute)}').join(',');
      await HomeWidget.saveWidgetData<String>('w_times', s);
      await _refresh();
    } catch (_) {}
  }
}
