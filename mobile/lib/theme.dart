import 'package:material_ui/material_ui.dart';

/// SIO colours on the Hipersign mobile app layout (same shapes and spacing as the HiperTracker app).
/// Blue and red come from the SIO logo. Change colours here only.
class SioColors {
  static const blue = Color(0xFF1A62A8); // primary, from the logo's blue
  static const red = Color(0xFFC8202A); // the + button and highlights, from the logo's red
  static const ink = Color(0xFF1F1F23); // headings, the logo's black
  static const text = Color(0xFF333333);
  static const textSecondary = Color(0xFF6B7785);

  static const background = Color(0xFFFFFFFF);
  static const card = Color(0xFFF2F6FA);
  static const cardHigh = Color(0xFFE3ECF5);
  static const border = Color(0xFFDDE6EF);

  static const green = Color(0xFF1E8E3E);
  static const greenBg = Color(0xFFCDEED6);
  static const danger = Color(0xFFC62828);
  static const dangerBg = Color(0xFFFDECEC);
  static const warning = Color(0xFF8A5200);
  static const warningBg = Color(0xFFFFF4DC);
  static const grey = Color(0xFF4F5965);
  static const greyBg = Color(0xFFDADFE5);
  static const purple = Color(0xFF7C3AED);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: SioColors.blue, brightness: Brightness.light).copyWith(
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
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: SioColors.background,
    textTheme: base.textTheme.apply(bodyColor: SioColors.text, displayColor: SioColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: SioColors.background,
      foregroundColor: SioColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x1A1A62A8),
      centerTitle: false,
      titleTextStyle: TextStyle(color: SioColors.ink, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    dividerTheme: const DividerThemeData(color: SioColors.border, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SioColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: SioColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: SioColors.blue, width: 1.6)),
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
        side: const BorderSide(color: SioColors.border),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: SioColors.blue)),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: SioColors.blue, linearTrackColor: SioColors.cardHigh),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? SioColors.blue : null),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: SioColors.background, surfaceTintColor: Colors.transparent),
    bottomSheetTheme:
        const BottomSheetThemeData(backgroundColor: SioColors.background, surfaceTintColor: Colors.transparent),
    bottomAppBarTheme: const BottomAppBarThemeData(
        color: SioColors.background, surfaceTintColor: Colors.transparent, elevation: 8, shadowColor: Color(0x331A62A8)),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: SioColors.text,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    listTileTheme: const ListTileThemeData(iconColor: SioColors.blue, textColor: SioColors.text),
    chipTheme: base.chipTheme.copyWith(
      side: const BorderSide(color: SioColors.border),
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
        decoration: BoxDecoration(
            color: error ? SioColors.dangerBg : SioColors.warningBg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: error ? SioColors.danger : SioColors.text)),
      );
}

/// Settings-style row (More screen).
class SioTile extends StatelessWidget {
  const SioTile(
      {super.key,
      required this.icon,
      required this.title,
      required this.onTap,
      this.subtitle,
      this.danger = false,
      this.trailing});
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
          subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: SioColors.textSecondary)),
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
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
