import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// A round photo with a camera badge. Tap to take a photo, pick one from the gallery or remove it.
///
/// - [self]: the signed-in person's own photo.
/// - [memberId]: a student someone manages.
/// - Neither: the photo is only held here ([onPicked]) and uploaded after the record is saved.
class PhotoPicker extends StatefulWidget {
  const PhotoPicker({
    super.key,
    required this.name,
    this.photo,
    this.memberId,
    this.self = false,
    this.onChanged,
    this.onPicked,
    this.radius = 46,
  });
  final String name;
  final String? photo;
  final String? memberId;
  final bool self;
  final ValueChanged<String?>? onChanged;
  final ValueChanged<String?>? onPicked; // base64 of the picked photo, for a record not saved yet
  final double radius;

  @override
  State<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends State<PhotoPicker> {
  late String? _photo = widget.photo;
  Uint8List? _local;
  bool _busy = false;

  bool get _live => widget.self || widget.memberId != null;

  Future<void> _choose() async {
    final has = _photo != null || _local != null;
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(s, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(s, 'gallery')),
          if (has)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: SioColors.red),
              title: const Text('Remove photo', style: TextStyle(color: SioColors.red)),
              onTap: () => Navigator.pop(s, 'remove'),
            ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    if (pick == 'remove') {
      await _upload(null);
      return;
    }
    final f = await ImagePicker().pickImage(
      source: pick == 'camera' ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 78,
    );
    if (f == null || !mounted) return;
    await _upload(await f.readAsBytes());
  }

  Future<void> _upload(Uint8List? bytes) async {
    final data = bytes == null ? null : base64Encode(bytes);
    if (!_live) {
      setState(() => _local = bytes);
      widget.onPicked?.call(data);
      return;
    }
    setState(() => _busy = true);
    String? url;
    final ok = await run(context, () async {
      final r = await Api.call('${Api.m}set_member_photo', {
        if (!widget.self) 'member': widget.memberId,
        'photo_data': data,
      });
      url = (r as Map?)?['photo']?.toString();
    }, done: bytes == null ? 'Photo removed.' : 'Photo saved.');
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _photo = url;
        _local = bytes;
      }
    });
    if (ok) widget.onChanged?.call(url);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radius;
    final ImageProvider? img = _local != null
        ? MemoryImage(_local!)
        : (_photo != null && _photo!.isNotEmpty ? NetworkImage('${Api.baseUrl}$_photo') : null);
    return Center(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _busy ? null : _choose,
        child: Stack(children: [
          img != null
              ? CircleAvatar(radius: r, backgroundColor: SioColors.cardHigh, backgroundImage: img)
              : Avatar(widget.name, radius: r, light: true),
          if (_busy)
            Positioned.fill(
              child: CircleAvatar(
                backgroundColor: Colors.black38,
                child: const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: SioColors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.photo_camera, size: 16, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}
