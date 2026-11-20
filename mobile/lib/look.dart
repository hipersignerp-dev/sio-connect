import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'theme.dart';

/// Appearance chosen in Settings: light / dark / follow the phone, and text size.
class Look {
  static final changes = ValueNotifier<int>(0);
  static String get mode => Api.prefs.getString('theme_mode') ?? 'system';
  static double get textScale => Api.prefs.getDouble('text_scale') ?? 1.0;

  static void apply() {
    final phoneDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    SioColors.dark = mode == 'dark' || (mode == 'system' && phoneDark);
  }

  static Future<void> set({String? theme, double? scale}) async {
    if (theme != null) await Api.prefs.setString('theme_mode', theme);
    if (scale != null) await Api.prefs.setDouble('text_scale', scale);
    apply();
    changes.value++;
  }
}
