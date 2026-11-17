import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'widgets.dart';

/// A house location: latitude and longitude from the phone's GPS.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  static GeoPoint? from(dynamic lat, dynamic lng) {
    final a = double.tryParse('${lat ?? ''}');
    final b = double.tryParse('${lng ?? ''}');
    if (a == null || b == null || (a == 0 && b == 0)) return null;
    return GeoPoint(a, b);
  }

  String get text => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

/// Reads where the phone is now (asks for permission the first time). Shows a message and returns null on trouble.
Future<GeoPoint?> currentLocation(BuildContext context) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (context.mounted) toast(context, 'Turn on Location (GPS) on the phone, then try again.');
      await Geolocator.openLocationSettings();
      return null;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied) {
      if (context.mounted) toast(context, 'Allow location so the app can save the place.');
      return null;
    }
    if (p == LocationPermission.deniedForever) {
      if (context.mounted) toast(context, 'Location is blocked for SIO Connect. Allow it in the phone settings.');
      await Geolocator.openAppSettings();
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)),
    );
    return GeoPoint(pos.latitude, pos.longitude);
  } catch (_) {
    if (context.mounted) toast(context, 'Could not get the location. Go outside or near a window and try again.');
    return null;
  }
}

/// Opens the place in Google Maps (directions from there).
Future<void> openInMaps(BuildContext context, GeoPoint g, {String? label}) async {
  final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${g.lat},${g.lng}');
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) toast(context, 'Could not open Maps.');
}

/// House location picker: "Use my current location", see it in Maps, clear it.
class LocationField extends StatefulWidget {
  const LocationField({super.key, this.value, required this.onChanged, this.label = 'House location', this.hint});
  final GeoPoint? value;
  final ValueChanged<GeoPoint?> onChanged;
  final String label;
  final String? hint;

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  late GeoPoint? _v = widget.value;
  bool _busy = false;

  Future<void> _here() async {
    setState(() => _busy = true);
    final g = await currentLocation(context);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (g != null) _v = g;
    });
    if (g != null) {
      widget.onChanged(g);
      toast(context, 'Location taken. Save to keep it.');
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              _v == null ? Icons.location_off_outlined : Icons.location_on,
              color: _v == null ? SioColors.textSecondary : SioColors.red,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    _v == null ? (widget.hint ?? 'Not added yet') : 'Saved point: ${_v!.text}',
                    style: const TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (_v != null)
              IconButton(
                tooltip: 'Open in Maps',
                icon: const Icon(Icons.map_outlined, color: SioColors.blue),
                onPressed: () => openInMaps(context, _v!),
              ),
            if (_v != null)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _v = null);
                  widget.onChanged(null);
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _here,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location),
          label: Text(_busy ? 'Finding you…' : (_v == null ? 'Use my current location' : 'Update to where I am now')),
        ),
        const SizedBox(height: 4),
        const Text(
          'Stand at the house (or near it) and tap the button.',
          style: TextStyle(color: SioColors.textSecondary, fontSize: 12),
        ),
      ],
    ),
  );
}

/// Map pin button for lists (members, donors). Nothing when there is no location.
class MapButton extends StatelessWidget {
  const MapButton({super.key, required this.lat, required this.lng});
  final dynamic lat;
  final dynamic lng;

  @override
  Widget build(BuildContext context) {
    final g = GeoPoint.from(lat, lng);
    if (g == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Directions',
      icon: const Icon(Icons.directions, color: SioColors.blue),
      onPressed: () => openInMaps(context, g),
    );
  }
}
