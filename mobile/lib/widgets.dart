import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'app_state.dart';
import 'theme.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String inr(dynamic v) => _inr.format(num.tryParse('${v ?? 0}') ?? 0);
num numOf(dynamic v) => num.tryParse('${v ?? 0}') ?? 0;

DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
String fmtDate(dynamic v, [String pattern = 'd MMM yyyy']) {
  final d = parseDate(v);
  return d == null ? '' : DateFormat(pattern).format(d);
}

String fmtTime(dynamic v) {
  if (v == null || '$v'.isEmpty) return '';
  final parts = '$v'.split(':');
  if (parts.length < 2) return '$v';
  final t = DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
  return DateFormat.jm().format(t);
}

String apiDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

void toast(BuildContext context, String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// Runs an action with a toast for errors; returns true on success.
Future<bool> run(BuildContext context, Future<void> Function() action, {String? done}) async {
  try {
    await action();
    if (done != null && context.mounted) toast(context, done);
    AppState.i.refreshAll();
    return true;
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message);
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
  }
  return false;
}

/// Loads data, shows a spinner / error with retry, pull to refresh, and reloads after app-wide changes.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.padding, this.skeleton});
  final Future<T> Function() load;
  final Widget? skeleton; // shown (shimmering) instead of the spinner on first load
  final List<Widget> Function(BuildContext context, T data) builder;
  final EdgeInsets? padding;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppState.i.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    AppState.i.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    if (_busy) return;
    _busy = true;
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (_error != null) ...[
        SioBanner(text: _error!, error: true),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _reload, child: const Text('Try again')),
        const SizedBox(height: 12),
      ],
      if (_data == null && _error == null && widget.skeleton != null)
        widget.skeleton!
      else if (_data == null && _error == null)
        const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (_data != null) ...widget.builder(context, _data as T),
    ];
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: children,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SioColors.ink),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class Stat extends StatelessWidget {
  const Stat(this.value, this.label, {super.key, this.color = SioColors.blue});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: SioColors.textSecondary, fontSize: 12)),
      ],
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.radius = 20, this.light = false, this.photo});
  final String name;
  final double radius;
  final bool light;
  final dynamic photo; // a /files/... address, when the person has a photo

  @override
  Widget build(BuildContext context) => '${photo ?? ''}'.isNotEmpty
      ? CircleAvatar(radius: radius, backgroundColor: SioColors.cardHigh, backgroundImage: NetworkImage('${Api.baseUrl}$photo'))
      : CircleAvatar(
          radius: radius,
          backgroundColor: light ? SioColors.cardHigh : SioColors.blue,
          foregroundColor: light ? SioColors.blue : Colors.white,
          child: Text(
            name.isEmpty ? '?' : name.trim()[0].toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.8),
          ),
        );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => SioPanel(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: SioColors.textSecondary),
    ),
  );
}

/// Grouped list inside one panel with dividers.
class PanelList extends StatelessWidget {
  const PanelList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SioPanel(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: 16, endIndent: 16), children[i]],
      ],
    ),
  );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 8),
  );
}

Future<T?> push<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

/// The one "add" button used on every list: a plain round +.
class AddFab extends StatelessWidget {
  const AddFab({super.key, required this.onPressed, this.tooltip = 'Add'});
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => FloatingActionButton(
    heroTag: null,
    tooltip: tooltip,
    backgroundColor: SioColors.cardHigh,
    foregroundColor: SioColors.blue,
    shape: const CircleBorder(),
    onPressed: onPressed,
    child: const Icon(Icons.add, size: 28),
  );
}
