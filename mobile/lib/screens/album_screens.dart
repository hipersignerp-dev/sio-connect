import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../app_state.dart';
import '../fx.dart';
import '../links.dart';
import '../theme.dart';
import '../widgets.dart';
import 'journey_screens.dart';
import 'social_screens.dart';

// Programme photo albums: leaders upload, everyone finds themselves, tags friends and shares to WhatsApp.

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);
List<Map<String, dynamic>> _l(dynamic v) => [for (final x in (v as List? ?? [])) _m(x)];
String _url(dynamic path) => '${Api.baseUrl}${path ?? ''}';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  int _v = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SioColors.background,
    appBar: AppBar(
      backgroundColor: SioColors.background,
      surfaceTintColor: SioColors.background,
      title: const Text('Albums', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: Loader<Map<String, dynamic>>(
      cacheKey: 'albums',
      key: ValueKey(_v),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      load: () async => _m(await Api.call('${Api.m}albums')),
      builder: (context, d) {
        final albums = _l(d['albums']);
        return [
          if (numOf(d['my_photos']) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Squish(
                onTap: () => push(context, const MyPhotosScreen()),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(gradient: sioGradient, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      const Text('📸', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You’re in ${d['my_photos']} photo${numOf(d['my_photos']) == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          if (albums.isEmpty) const EmptyNote('No albums yet. After the next programme, photos will appear here.'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: [
              for (final (i, a) in albums.indexed)
                Enter(
                  index: i,
                  child: Squish(
                    onTap: () async {
                      await push(context, AlbumScreen(name: '${a['name']}'));
                      setState(() => _v++);
                    },
                    child: _AlbumTile(a: a),
                  ),
                ),
            ],
          ),
        ];
      },
    ),
    floatingActionButton: AppState.i.can('manage_events')
        ? FloatingActionButton.extended(
            onPressed: () async {
              final name = await newAlbum(context);
              if (name != null && context.mounted) {
                await push(context, AlbumScreen(name: name));
                setState(() => _v++);
              }
            },
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('New album'),
          )
        : null,
  );
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.a});
  final Map<String, dynamic> a;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (a['cover'] != null)
          Image.network(
            _url(a['cover']),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: SioColors.card),
          )
        else
          Container(decoration: const BoxDecoration(gradient: sioGradient)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Color(0xCC000000)],
              begin: Alignment.center,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${a['title']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
              ),
              Text(
                ['${a['photo_count'] ?? 0} photos', if (a['album_date'] != null) fmtDate(a['album_date'], 'd MMM')].join(' · '),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        if (numOf(a['me_in']) > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text(
                '📸 you ×${a['me_in']}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF1F1F23)),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Leaders: start an album, from a programme (fills the title and date) or with a title of its own.
Future<String?> newAlbum(BuildContext context, {String? event}) async {
  if (event != null) {
    final r = _m(await Api.call('${Api.m}save_album', {'event': event}));
    return '${r['name']}';
  }
  // past programmes too (up to two years back), newest first, so photos of an old programme can be added
  final events = _l(await Api.call('${Api.m}events', {'since_days': 730, 'limit': 300}))
    ..sort((a, b) => '${b['starts_on']}'.compareTo('${a['starts_on']}'));
  if (!context.mounted) return null;
  final title = TextEditingController();
  String? ev;
  DateTime day = DateTime.now();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('New album'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: ev,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Programme (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('No programme')),
                for (final e in events)
                  DropdownMenuItem(
                    value: '${e['name']}',
                    child: Text('${e['title']} · ${fmtDate(e['starts_on'])}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => set(() => ev = v),
            ),
            if (ev == null) ...[
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Unit meet, Nov 2026'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text('Date: ${fmtDate(day.toIso8601String().substring(0, 10))}'),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: day,
                    firstDate: DateTime(2010),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) set(() => day = d);
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    ),
  );
  if (ok != true) return null;
  try {
    final r = _m(
      await Api.call('${Api.m}save_album', {
        'event': ev,
        'title': title.text.trim(),
        if (ev == null) 'album_date': day.toIso8601String().substring(0, 10),
      }),
    );
    return '${r['name']}';
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message);
    return null;
  }
}

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, required this.name});
  final String name;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  Map<String, dynamic>? _a;
  String? _error;
  int _uploading = 0;
  int _uploaded = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = _m(await Api.call('${Api.m}album', {'name': widget.name}));
      if (mounted) setState(() => _a = a);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _add() async {
    final files = await ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    if (files.isEmpty) return;
    setState(() {
      _uploading = files.length;
      _uploaded = 0;
    });
    for (final f in files) {
      try {
        final bytes = await f.readAsBytes();
        await Api.call('${Api.m}album_photo', {'album': widget.name, 'photo_data': base64Encode(bytes)});
      } on ApiException catch (e) {
        if (mounted) toast(context, e.message);
      }
      if (mounted) setState(() => _uploaded++);
    }
    if (mounted) setState(() => _uploading = 0);
    await _load();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final photos = a == null ? <Map<String, dynamic>>[] : _l(a['photos']);
    final mine = photos.where((p) => p['me'] == true).length;
    return Scaffold(
      backgroundColor: SioColors.background,
      appBar: AppBar(
        backgroundColor: SioColors.background,
        surfaceTintColor: SioColors.background,
        title: Text(a == null ? 'Album' : '${a['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (a?['can_manage'] == true)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: const Text('Delete this album and all its photos?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    final done = await run(
                      context,
                      () => Api.call('${Api.m}save_album', {'name': widget.name, 'delete': 1}),
                      done: 'Album deleted',
                    );
                    if (done && context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete album'))],
            ),
        ],
      ),
      floatingActionButton: a?['can_manage'] == true
          ? FloatingActionButton.extended(
              onPressed: _uploading > 0 ? null : _add,
              icon: _uploading > 0
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(_uploading > 0 ? 'Uploading $_uploaded / $_uploading' : 'Add photos'),
            )
          : null,
      body: a == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Text(
                        [
                          '${photos.length} photos',
                          if (a['album_date'] != null) fmtDate(a['album_date']),
                          if (mine > 0) 'you’re in $mine',
                        ].join(' · '),
                        style: TextStyle(color: SioColors.textSecondary),
                      ),
                    ),
                  ),
                  if (photos.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: EmptyNote(
                          a['can_manage'] == true ? 'Tap “Add photos” to upload from your gallery.' : 'No photos yet.',
                        ),
                      ),
                    ),
                  SliverGrid.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    children: [
                      for (final (i, p) in photos.indexed)
                        GestureDetector(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PhotoViewer(photos: photos, start: i, album: a),
                              ),
                            );
                            _load();
                          },
                          child: Hero(
                            tag: 'ph-${p['name']}',
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(_url(p['file_url']), fit: BoxFit.cover, cacheWidth: 400),
                                if (p['me'] == true)
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: CircleAvatar(
                                      radius: 11,
                                      backgroundColor: SioColors.background,
                                      child: Text('🙋', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
    );
  }
}

/// Full-screen photos: swipe, pinch to zoom, "That's me", tag a friend, share to WhatsApp.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.photos, this.start = 0, this.album});
  final List<Map<String, dynamic>> photos;
  final int start;
  final Map<String, dynamic>? album;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _pc = PageController(initialPage: widget.start);
  late int _i = widget.start;
  late final List<Map<String, dynamic>> _photos = [for (final p in widget.photos) Map<String, dynamic>.from(p)];
  bool _busy = false;
  final _meKey = GlobalKey();

  Map<String, dynamic> get _p => _photos[_i];

  Future<void> _toggleMe() async {
    HapticFeedback.mediumImpact();
    final on = _p['me'] != true;
    setState(() => _busy = true);
    try {
      await Api.call('${Api.m}tag_photo', {'photo': _p['name'], 'remove': on ? null : 1});
      final me = AppState.i.me;
      setState(() {
        _p['me'] = on;
        final tags = _l(_p['tags']);
        tags.removeWhere((t) => t['member'] == me['member']);
        if (on) tags.add({'member': me['member'], 'full_name': me['full_name'], 'photo': me['photo']});
        _p['tags'] = tags;
      });
      final c = _meKey.currentContext;
      if (on && c != null && c.mounted) burst(c, emojis: const ['📸', '✨', '💙', '🙋'], count: 14, power: 0.7);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tagFriend() async {
    final f = _m(await Api.call('${Api.m}friends'));
    final friends = _l(f['friends']);
    if (!mounted) return;
    if (friends.isEmpty) {
      toast(context, 'Add friends first, then you can tag them.');
      return;
    }
    final pick = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Who’s in this photo?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            for (final x in friends)
              ListTile(
                leading: Avatar('${x['full_name']}', photo: x['photo'], light: true),
                title: Text('${x['full_name']}'),
                subtitle: Text('${x['username'] ?? ''}'.isEmpty ? '' : '@${x['username']}'),
                onTap: () => Navigator.pop(ctx, x),
              ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      await Api.call('${Api.m}tag_photo', {'photo': _p['name'], 'member': pick['member']});
      setState(() {
        final tags = _l(_p['tags'])..removeWhere((t) => t['member'] == pick['member']);
        tags.add(pick);
        _p['tags'] = tags;
      });
      if (mounted) toast(context, 'Tagged ${pick['full_name']}. They’ll get a notification.');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final res = await http.get(Uri.parse(_url(_p['file_url'])));
      final title = widget.album?['title'] ?? _p['album_title'] ?? 'SIO programme';
      await SharePlus.instance.share(
        ShareParams(
          text:
              '$title 📸\nSee all the photos: ${Links.share({if (widget.album != null) 'a': '${widget.album!['name']}' else 'a': '${_p['album'] ?? ''}'})}',
          files: [XFile.fromData(res.bodyBytes, mimeType: 'image/jpeg', name: 'sio-photo.jpg')],
          fileNameOverrides: const ['sio-photo.jpg'],
        ),
      );
    } catch (_) {
      if (mounted) toast(context, 'Could not share the photo. Check your internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = _l(_p['tags']);
    final canManage = widget.album?['can_manage'] == true;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_i + 1} / ${_photos.length}', style: const TextStyle(color: Colors.white)),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Delete photo',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await run(
                  context,
                  () => Api.call('${Api.m}album_photo', {'album': widget.album!['name'], 'photo': _p['name'], 'delete': 1}),
                  done: 'Photo deleted',
                );
                if (ok && context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _photos.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) => GestureDetector(
                onDoubleTap: _p['me'] == true ? null : _toggleMe,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Hero(
                    tag: 'ph-${_photos[i]['name']}',
                    child: Image.network(
                      _url(_photos[i]['file_url']),
                      fit: BoxFit.contain,
                      loadingBuilder: (c, child, p) =>
                          p == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tags.isNotEmpty)
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final t in tags)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                backgroundColor: Colors.white12,
                                side: BorderSide.none,
                                avatar: Avatar('${t['full_name'] ?? ''}', radius: 10, photo: t['photo'], light: true),
                                label: Text('${t['full_name']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                onPressed: () => push(context, PersonPage(member: '${t['member']}')),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  ReactionBar(key: ValueKey('rx-${_p['name']}'), photo: _p, light: true),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: _meKey,
                          style: FilledButton.styleFrom(
                            backgroundColor: _p['me'] == true ? Colors.white : const Color(0xFF1A62A8),
                            foregroundColor: _p['me'] == true ? SioColors.ink : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _busy ? null : _toggleMe,
                          icon: Text(_p['me'] == true ? '✓' : '🙋', style: const TextStyle(fontSize: 16)),
                          label: Text(_p['me'] == true ? 'You’re tagged' : 'That’s me!'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.white12),
                        tooltip: 'Tag a friend',
                        onPressed: _busy ? null : _tagFriend,
                        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                        tooltip: 'Share to WhatsApp',
                        onPressed: _busy ? null : _share,
                        icon: const Icon(Icons.share, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MyPhotosScreen extends StatelessWidget {
  const MyPhotosScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Photos of you')),
    body: Loader<List<Map<String, dynamic>>>(
      padding: EdgeInsets.zero,
      load: () async => _l(await Api.call('${Api.m}my_photos')),
      builder: (context, photos) => [
        if (photos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: EmptyNote('When you or a friend tag you in a programme photo, it shows here.'),
          ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: [
            for (final (i, p) in photos.indexed)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PhotoViewer(
                      photos: [
                        for (final x in photos) {...x, 'me': true, 'tags': []},
                      ],
                      start: i,
                    ),
                  ),
                ),
                child: Image.network(_url(p['file_url']), fit: BoxFit.cover, cacheWidth: 400),
              ),
          ],
        ),
      ],
    ),
  );
}

/// A strip of recent albums for the home screen.
class AlbumStrip extends StatelessWidget {
  const AlbumStrip({super.key, required this.albums});
  final List<Map<String, dynamic>> albums;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 170,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: albums.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) => SizedBox(
        width: 140,
        child: Squish(
          onTap: () => push(context, AlbumScreen(name: '${albums[i]['name']}')),
          child: _AlbumTile(a: albums[i]),
        ),
      ),
    ),
  );
}

/// A programme photo in the home feed: which programme, the photo, who is in it, and quick actions.
class PhotoFeedCard extends StatelessWidget {
  const PhotoFeedCard({super.key, required this.photos, required this.index});
  final List<Map<String, dynamic>> photos;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = photos[index];
    final tags = _l(p['tags']);
    final me = AppState.i.me['member'];
    final names = [
      if (p['me'] == true) 'You',
      for (final t in tags)
        if (t['member'] != me) AppState.callName('${t['full_name'] ?? ''}'),
    ];
    final who = names.isEmpty
        ? ''
        : names.length <= 3
        ? names.join(', ')
        : '${names.take(2).join(', ')} and ${names.length - 2} more';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            leading: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(gradient: sioGradient, shape: BoxShape.circle),
              child: const Icon(Icons.photo_camera, color: Colors.white, size: 20),
            ),
            title: Text('${p['album_title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            subtitle: Text(p['album_date'] != null ? fmtDate(p['album_date'], 'd MMM yyyy') : ''),
            trailing: TextButton(
              onPressed: () => push(context, AlbumScreen(name: '${p['album']}')),
              child: const Text('Album'),
            ),
            onTap: () => push(context, AlbumScreen(name: '${p['album']}')),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PhotoViewer(photos: photos, start: index),
              ),
            ),
            child: Hero(
              tag: 'ph-${p['name']}',
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  _url(p['file_url']),
                  fit: BoxFit.cover,
                  cacheWidth: 1080,
                  errorBuilder: (_, _, _) => Container(color: SioColors.card),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ReactionBar(key: ValueKey('rx-${p['name']}'), photo: p),
          ),
          if (who.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 22.0 + 16 * (tags.take(3).length - 1).clamp(0, 2),
                    height: 26,
                    child: Stack(
                      children: [
                        for (final (i, t) in tags.take(3).indexed)
                          Positioned(
                            left: i * 16.0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Avatar('${t['full_name'] ?? ''}', radius: 11, photo: t['photo'], light: true),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: who,
                            style: TextStyle(fontWeight: FontWeight.w800, color: SioColors.ink),
                          ),
                          TextSpan(text: names.length == 1 && names.first != 'You' ? ' is in this photo' : ' are in this photo'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// ❤️ 🔥 😂 👏 under a photo, with counts. Tap to react (tap again to take it back); the people in the photo and
/// the person who added it get a notice.
class ReactionBar extends StatefulWidget {
  const ReactionBar({super.key, required this.photo, this.light = false});
  final Map<String, dynamic> photo;
  final bool light; // on the dark photo viewer

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  static const emojis = ['❤️', '🔥', '😂', '👏'];
  late Map<String, int> _counts = {
    for (final e in (Map<String, dynamic>.from((widget.photo['reactions'] ?? {}) as Map)).entries) e.key: numOf(e.value).toInt(),
  };
  late String? _mine = widget.photo['my_reaction']?.toString();
  bool _busy = false;

  Future<void> _react(String e) async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    final before = (Map<String, int>.from(_counts), _mine);
    setState(() {
      // update straight away; the server answer replaces it
      if (_mine != null) _counts[_mine!] = (_counts[_mine!] ?? 1) - 1;
      if (_mine == e) {
        _mine = null;
      } else {
        _mine = e;
        _counts[e] = (_counts[e] ?? 0) + 1;
      }
      _busy = true;
    });
    try {
      final r = Map<String, dynamic>.from(
        await Api.call('${Api.m}react_photo', {'photo': widget.photo['name'], 'emoji': e}) as Map,
      );
      if (!mounted) return;
      setState(() {
        _counts = {
          for (final x in Map<String, dynamic>.from((r['reactions'] ?? {}) as Map).entries) x.key: numOf(x.value).toInt(),
        };
        _mine = r['my_reaction']?.toString();
      });
      widget.photo['reactions'] = _counts;
      widget.photo['my_reaction'] = _mine;
    } catch (err) {
      if (mounted) {
        setState(() {
          _counts = before.$1;
          _mine = before.$2;
        });
        toast(context, friendlyError(err));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final e in emojis)
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _react(e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _mine == e
                  ? (widget.light ? Colors.white24 : SioColors.blue.withValues(alpha: 0.14))
                  : (widget.light ? Colors.white10 : SioColors.card),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _mine == e ? (widget.light ? Colors.white70 : SioColors.blue) : Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _mine == e ? 1.2 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: Text(e, style: const TextStyle(fontSize: 16)),
                ),
                if ((_counts[e] ?? 0) > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${_counts[e]}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: widget.light ? Colors.white : SioColors.text),
                  ),
                ],
              ],
            ),
          ),
        ),
    ],
  );
}
