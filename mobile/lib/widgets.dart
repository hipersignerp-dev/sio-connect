import 'dart:convert';

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
    if (context.mounted) toast(context, friendlyError(e));
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
  }
  return false;
}

/// Loads data, shows a spinner / error with retry, pull to refresh, and reloads after app-wide changes.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.padding, this.skeleton, this.cacheKey});
  final Future<T> Function() load;
  final Widget? skeleton; // shown (shimmering) instead of the spinner on first load
  final List<Widget> Function(BuildContext context, T data) builder;
  final EdgeInsets? padding;

  /// When set, the last good data is kept on the phone: shown instantly on open (then refreshed quietly),
  /// and still shown when there's no internet.
  final String? cacheKey;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

/// The phone-side copy of screens (see [Loader.cacheKey]); per signed-in person, cleared on sign out.
class ScreenCache {
  static String _k(String key) => 'lc_${AppState.i.me['email'] ?? ''}_$key';

  static T? read<T>(String key) {
    final raw = Api.prefs.getString(_k(key));
    if (raw == null) return null;
    try {
      final d = jsonDecode(raw);
      if (d is T) return d;
      if (d is List) {
        final maps = List<Map<String, dynamic>>.from(d.map((e) => Map<String, dynamic>.from(e as Map)));
        if (maps is T) return maps as T;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> write(String key, Object? data) async {
    try {
      await Api.prefs.setString(_k(key), jsonEncode(data));
    } catch (_) {}
  }

  static Future<void> clear() async {
    for (final k in Api.prefs.getKeys().where((k) => k.startsWith('lc_')).toList()) {
      await Api.prefs.remove(k);
    }
  }
}

class _LoaderState<T> extends State<Loader<T>> {
  T? _data;
  String? _error;
  bool _busy = false;
  bool _stale = false; // showing the saved copy

  @override
  void initState() {
    super.initState();
    if (widget.cacheKey != null) {
      _data = ScreenCache.read<T>(widget.cacheKey!);
      _stale = _data != null;
    }
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
      if (widget.cacheKey != null) ScreenCache.write(widget.cacheKey!, d);
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
          _stale = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = _error != null && _data != null;
    final children = <Widget>[
      if (offline)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: _reload,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _stale ? 'You’re offline. Showing what was saved on your phone.' : _error!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        )
      else if (_error != null) ...[
        const SizedBox(height: 40),
        Icon(Icons.wifi_off_rounded, size: 48, color: SioColors.textSecondary),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4)),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Try again')),
        ),
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

/// Turns errors into words a student understands.
String friendlyError(Object e) {
  if (e is ApiException) {
    if (e.status == null) return 'You’re offline or the internet is slow. Pull down to try again.';
    if (e.status == 401) return 'Please sign in again.';
    if ((e.status ?? 0) >= 500 && e.message.startsWith('Something went wrong')) {
      return 'Our server had a hiccup. Please try again in a minute.';
    }
    return e.message;
  }
  final t = e.toString();
  if (t.contains('SocketException') || t.contains('TimeoutException') || t.contains('ClientException')) {
    return 'You’re offline or the internet is slow. Pull down to try again.';
  }
  return 'Something didn’t work. Please try again.';
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SioColors.ink),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class Stat extends StatelessWidget {
  const Stat(this.value, this.label, {super.key, this._color});
  final String value;
  final String label;
  final Color? _color;
  Color get color => _color ?? SioColors.blue;

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
        Text(label, style: TextStyle(color: SioColors.textSecondary, fontSize: 12)),
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
      style: TextStyle(color: SioColors.textSecondary),
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

/// A phone number as WhatsApp wants it (country code, digits only; Indian 10-digit numbers get 91).
String waNumber(String mobile) {
  final d = mobile.replaceAll(RegExp(r'[^0-9]'), '');
  return d.length == 10 ? '91$d' : d;
}

/// "Adnan, Affan and 3 more going" with their faces overlapping (friends first), or just "12 going".
class FacesGoing extends StatelessWidget {
  const FacesGoing({super.key, required this.e, this.light = false, this.extra = 0});
  final Map<String, dynamic> e;
  final bool light; // on a blue card
  final int extra; // my own change after tapping "I'll go"

  @override
  Widget build(BuildContext context) {
    final friends = [for (final f in (e['friends_going'] as List? ?? [])) Map<String, dynamic>.from(f as Map)];
    final fCount = numOf(e['friends_going_count']).toInt();
    final total = numOf(e['registered_count']).toInt() + extra;
    if (total <= 0 && friends.isEmpty) return const SizedBox.shrink();
    String first(Map<String, dynamic> f) {
      final w = '${f['full_name'] ?? ''}'.trim().split(RegExp(r'\s+'));
      final skip = {'mohammed', 'muhammed', 'muhammad', 'mohammad', 'md', 'mhd'};
      return w.firstWhere((x) => !skip.contains(x.toLowerCase()) && x.length > 1, orElse: () => w.first);
    }

    final text = friends.isEmpty
        ? '$total going'
        : [
            friends.take(2).map(first).join(', '),
            if (total - friends.take(2).length > 0) ' and ${total - friends.take(2).length} more',
            ' going',
          ].join();
    final color = light ? Colors.white : SioColors.text;
    return Row(
      children: [
        if (friends.isNotEmpty)
          SizedBox(
            width: 18.0 * friends.length + 10,
            height: 28,
            child: Stack(
              children: [
                for (var i = 0; i < friends.length; i++)
                  Positioned(
                    left: i * 18.0,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: light ? const Color(0xFF1A62A8) : SioColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Avatar('${friends[i]['full_name'] ?? ''}', radius: 12, light: true, photo: friends[i]['photo']),
                    ),
                  ),
              ],
            ),
          ),
        if (friends.isNotEmpty) const SizedBox(width: 4),
        Flexible(
          child: Text(
            fCount > 0 && friends.isEmpty ? '$total going' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
