import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'theme.dart';

/// Appearance: the app is always light (SIO light blue), whatever the phone's setting; text size is chosen in Settings.
class Look {
  static final changes = ValueNotifier<int>(0);
  static String get mode => Api.prefs.getString('theme_mode') ?? 'light';
  static double get textScale => Api.prefs.getDouble('text_scale') ?? 1.0;

  static void apply() {
    SioColors.dark = false;
  }

  static Future<void> set({String? theme, double? scale}) async {
    if (theme != null) await Api.prefs.setString('theme_mode', theme);
    if (scale != null) await Api.prefs.setDouble('text_scale', scale);
    apply();
    changes.value++;
  }
}
