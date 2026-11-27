import 'package:material_ui/material_ui.dart';

/// SIO colours on the Hipersign mobile app layout (same shapes and spacing as the HiperTracker app).
/// Blue and red come from the SIO logo. Change colours here only.
/// App colours. Light by default; [dark] switches the whole palette (set before the app is built).
class SioColors {
  static bool dark = false;
  static Color _p(int light, int night) => Color(dark ? night : light);

  static Color get blue => _p(0xFF1A62A8, 0xFF4C8FD6); // primary, from the logo's blue
  static Color get red => _p(0xFFC8202A, 0xFFE5484D); // the + button and highlights
  static Color get ink => _p(0xFF1F1F23, 0xFFEEF1F5); // headings
  static Color get text => _p(0xFF333333, 0xFFD9DEE4);
  static Color get textSecondary => _p(0xFF6B7785, 0xFF9AA7B4);

  static Color get background => _p(0xFFFFFFFF, 0xFF0F1419);
  static Color get card => _p(0xFFF2F6FA, 0xFF1A2129);
  static Color get cardHigh => _p(0xFFE3ECF5, 0xFF243039);
  static Color get border => _p(0xFFDDE6EF, 0xFF2C3844);

  static Color get green => _p(0xFF1E8E3E, 0xFF4CC26E);
  static Color get greenBg => _p(0xFFCDEED6, 0xFF173A24);
  static Color get danger => _p(0xFFC62828, 0xFFEF5350);
  static Color get dangerBg => _p(0xFFFDECEC, 0xFF3D1A1C);
  static Color get warning => _p(0xFF8A5200, 0xFFF0A847);
  static Color get warningBg => _p(0xFFFFF4DC, 0xFF3A2C12);
  static Color get grey => _p(0xFF4F5965, 0xFFB5BEC8);
  static Color get greyBg => _p(0xFFDADFE5, 0xFF2C343D);
  static Color get purple => _p(0xFF7C3AED, 0xFFA78BFA);
}

/// Qur'an Arabic in a proper Qur'an font, the same on every phone.
TextStyle arabicStyle({Color? color, double size = 22}) =>
    TextStyle(fontFamily: 'AmiriQuran', fontSize: size, height: 2.0, color: color);

/// Malayalam in a clear Malayalam font, the same on every phone.
TextStyle malayalamStyle({Color? color, double size = 16, FontWeight? weight}) =>
    TextStyle(fontFamily: 'NotoSansMalayalam', fontSize: size, height: 1.65, color: color, fontWeight: weight);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: SioColors.blue, brightness: SioColors.dark ? Brightness.dark : Brightness.light)
      .copyWith(
        primary: SioColors.blue,
        onPrimary: Colors.white,
        secondary: SioColors.red,
        onSecondary: Colors.white,
        surface: SioColors.background,
        onSurface: SioColors.text,
        onSurfaceVariant: SioColors.textSecondary,
        surfaceContainerHighest: SioColors.card,
        outline: SioColors.border,
        outlineVariant: SioColors.border,
        error: SioColors.danger,
        surfaceTint: Colors.transparent,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: SioColors.dark ? Brightness.dark : Brightness.light,
    fontFamilyFallback: const ['NotoSansMalayalam'],
  );
  return base.copyWith(
    scaffoldBackgroundColor: SioColors.background,
    textTheme: base.textTheme.apply(bodyColor: SioColors.text, displayColor: SioColors.text),
    appBarTheme: AppBarTheme(
      backgroundColor: SioColors.background,
      foregroundColor: SioColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x1A1A62A8),
      centerTitle: false,
      titleTextStyle: TextStyle(color: SioColors.ink, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    dividerTheme: DividerThemeData(color: SioColors.border, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SioColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: SioColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: SioColors.blue, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SioColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SioColors.blue,
        side: BorderSide(color: SioColors.border),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: SioColors.blue)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: SioColors.blue, linearTrackColor: SioColors.cardHigh),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? SioColors.blue : null),
    ),
    dialogTheme: DialogThemeData(backgroundColor: SioColors.background, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: SioColors.background, surfaceTintColor: Colors.transparent),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: SioColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Color(0x331A62A8),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0E3F70),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      actionTextColor: const Color(0xFF9FD0FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 6,
    ),
    listTileTheme: ListTileThemeData(iconColor: SioColors.blue, textColor: SioColors.text),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: SioColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

/// Rounded soft panel used for every card (Hipersign style).
class SioPanel extends StatelessWidget {
  const SioPanel({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: color ?? SioColors.card,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(width: double.infinity, padding: padding, child: child),
      ),
    );
  }
}

/// Info / error strip.
class SioBanner extends StatelessWidget {
  const SioBanner({super.key, required this.text, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: error ? SioColors.dangerBg : SioColors.warningBg, borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: TextStyle(color: error ? SioColors.danger : SioColors.text)),
  );
}

/// Settings-style row (More screen).
class SioTile extends StatelessWidget {
  const SioTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: SioColors.card,
      leading: Icon(icon, color: danger ? SioColors.danger : SioColors.blue),
      title: Text(title, style: TextStyle(color: danger ? SioColors.danger : null)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(color: SioColors.textSecondary)),
      trailing: trailing ?? (danger ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    ),
  );
}

enum Tone { green, blue, red, amber, grey }

class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, this.tone = Tone.grey});
  final String text;
  final Tone tone;

  static Tone toneFor(String status) {
    switch (status) {
      case 'Paid':
      case 'Present':
      case 'Active':
      case 'Completed':
      case 'Registered':
      case 'Approved':
      case 'Attending':
      case 'Registrations Open':
        return Tone.green;
      case 'Part Paid':
      case 'Scheduled':
        return Tone.blue;
      case 'Offered':
        return Tone.amber;
      case 'Rejected':
      case 'Absent':
      case 'Not Attending':
        return Tone.red;
      case 'Pending':
      case 'Pending Approval':
      case 'Planning':
        return Tone.amber;
      default:
        return Tone.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      Tone.green => (SioColors.green, SioColors.greenBg),
      Tone.blue => (SioColors.blue, SioColors.cardHigh),
      Tone.red => (SioColors.danger, SioColors.dangerBg),
      Tone.amber => (SioColors.warning, SioColors.warningBg),
      Tone.grey => (SioColors.grey, SioColors.greyBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
