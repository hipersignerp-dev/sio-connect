// ignore_for_file: sort_child_properties_last
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../ayah_audio.dart';
import '../noor.dart';
import '../notify.dart';
import '../photo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'journey_screens.dart';
import 'more_screen.dart' show StagePicker;

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);
List<Map<String, dynamic>> _l(dynamic v) => [for (final x in (v as List? ?? [])) _m(x)];

/// Shown once, the first time someone opens the app: read the first ayah (streak starts at 1), add a photo,
/// add a few friends from the unit, pick a daily reminder time. Every step can be skipped.
class Onboarding {
  static String get _key => 'onboarded_${AppState.i.me['email'] ?? ''}';
  static bool get done => Api.prefs.getBool(_key) == true;

  static Future<void> maybeShow(BuildContext context) async {
    if (done || (AppState.i.me['member'] == null)) return;
    await Api.prefs.setBool(_key, true);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const _Flow()));
    AppState.i.refreshAll();
  }
}

class _Flow extends StatefulWidget {
  const _Flow();

  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  final _pages = PageController();
  int _at = 0;
  Map<String, dynamic>? _journey;
  List<Map<String, dynamic>> _people = [];
  final _sent = <String>{};
  bool _loading = true;
  bool _reading = false;
  bool _read = false;
  String _remind = Notify.reminderTime ?? '20:00';
  String? _stage = (AppState.i.me['life_stage'] ?? '').toString().isEmpty ? null : '${AppState.i.me['life_stage']}';
  final _what = TextEditingController(); // college, or profession
  final _city = TextEditingController(text: '${AppState.i.me['current_city'] ?? ''}');
  bool _saving = false;

  Future<void> _saveStage() async {
    if (_stage == null) {
      _next();
      return;
    }
    setState(() => _saving = true);
    try {
      final w = _what.text.trim();
      final r = await Api.call('${Api.m}update_my_profile', {
        'life_stage': _stage,
        if (w.isNotEmpty && _stage == 'Working') 'profession': w,
        if (w.isNotEmpty && _stage != 'Working') 'campus': w,
        if (_city.text.trim().isNotEmpty) 'current_city': _city.text.trim(),
      });
      AppState.i.me = Map<String, dynamic>.from(r as Map);
      if (mounted) _next();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _stagePage() => _Page(
    emoji: '👋',
    title: 'Tell us about you',
    text: 'So the app shows what’s useful for you: exam and scholarship alerts, internships, or jobs and mentoring.',
    content: Column(
      children: [
        StagePicker(value: _stage, onChanged: (v) => setState(() => _stage = v)),
        if (_stage != null) ...[
          const SizedBox(height: 18),
          TextField(
            controller: _what,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: _stage == 'Working'
                  ? 'What do you do?'
                  : _stage == 'School'
                  ? 'School'
                  : 'College',
              hintText: _stage == 'Working' ? 'e.g. Engineer, Teacher, Business' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Lives in (city or town now)'),
          ),
        ],
      ],
    ),
    action: _saving ? 'Saving…' : (_stage == null ? 'Skip' : 'Next'),
    onAction: _saving ? () {} : _saveStage,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        Api.call('${Api.m}journey').catchError((_) => null),
        Api.call('${Api.m}suggest_people').catchError((_) => []),
      ]);
      _journey = r[0] == null ? null : _m(r[0]);
      _people = _l(r[1]).take(8).toList();
      _read = _m(_journey?['reading_streak'])['today'] == true;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<String> get _steps => [
    if (_journey?['reading'] != null) 'ayah',
    if ('${AppState.i.me['photo'] ?? ''}'.isEmpty) 'photo',
    if (_people.isNotEmpty) 'friends',
    'reminder',
  ];

  void _next() {
    if (_at >= _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _markRead() async {
    if (_read || _reading) return;
    setState(() => _reading = true);
    try {
      final r = _m(await Api.call('${Api.m}read_today'));
      Notify.markReadToday(numOf(r['current']).toInt());
      if (!mounted) return;
      setState(() => _read = true);
      await celebrateRead(context, r);
      if (mounted) _next();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Widget _ayah() {
    final r = _m(_journey?['reading']);
    final audio = [for (final u in (r['audio'] as List? ?? [])) '$u'];
    return _Page(
      emoji: '',
      hero: const Noor(mood: NoorMood.hello, size: 110, stage: 0),
      title: 'Meet Noor, your little sprout',
      text:
          'One ayah a day waters Noor. Keep going and it grows, gets a bud and blooms. '
          'Forget, and it gets thirsty. Read today’s ayah to plant it. Today is day 1!',
      action: _read ? 'Next' : (_reading ? 'Saving…' : '💧  I read it'),
      onAction: _read ? _next : _markRead,
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0E3F70), Color(0xFF1A62A8)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ('${r['text_ar'] ?? ''}'.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: Text(
                  '${r['text_ar']}',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: arabicStyle(color: Colors.white, size: 22),
                ),
              ),
            const SizedBox(height: 8),
            if ('${r['text_ml'] ?? ''}'.isNotEmpty)
              Text(
                '${r['text_ml']}',
                style: malayalamStyle(color: Colors.white, size: 16, weight: FontWeight.w600),
              ),
            const SizedBox(height: 6),
            Text('“${r['text_en'] ?? ''}”', style: const TextStyle(color: Colors.white70, height: 1.4)),
            Text('— ${r['reference'] ?? ''}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (audio.isNotEmpty) AyahAudioButton(urls: audio, light: true, onComplete: _markRead),
                if (malayalamToRead(r).isNotEmpty)
                  MalayalamSpeakButton(text: malayalamToRead(r), reading: r, light: true, onComplete: _markRead),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo() => _Page(
    emoji: '🤳',
    title: 'Add your photo',
    text: 'So friends from your unit recognise you on the leaderboard and in programme photos.',
    action: 'Next',
    onAction: _next,
    content: Center(
      child: PhotoPicker(
        name: '${AppState.i.me['full_name'] ?? ''}',
        photo: AppState.i.me['photo']?.toString(),
        self: true,
        onChanged: (u) {
          AppState.i.me['photo'] = u;
          AppState.i.touch();
          setState(() {});
        },
      ),
    ),
  );

  Widget _friends() => _Page(
    emoji: '🤝',
    title: 'Add a few friends',
    text: 'See who read today, nudge them, and race them on the leaderboard. Add at least 3.',
    action: _sent.isEmpty ? 'Skip for now' : 'Next (${_sent.length} added)',
    onAction: _next,
    content: Column(
      children: [
        for (final p in _people)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Avatar('${p['full_name'] ?? ''}', radius: 22, light: true, photo: p['photo']),
            title: Text('${p['full_name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(p['same_unit'] == true ? 'In your unit' : 'SIO ${p['unit'] ?? ''}'),
            trailing: _sent.contains('${p['member']}')
                ? Icon(Icons.check_circle, color: SioColors.green)
                : FilledButton.tonal(
                    onPressed: () async {
                      try {
                        await Api.call('${Api.m}friend_request', {'member': p['member']});
                        setState(() => _sent.add('${p['member']}'));
                      } catch (e) {
                        if (mounted) toast(context, friendlyError(e));
                      }
                    },
                    child: const Text('Add'),
                  ),
          ),
      ],
    ),
  );

  Widget _reminder() {
    const options = [
      ('05:30', 'After Fajr', '🌅'),
      ('07:30', 'Morning', '☀️'),
      ('13:30', 'After lunch', '🍽️'),
      ('20:00', 'Evening', '🌙'),
      ('22:00', 'Before sleep', '😴'),
    ];
    return _Page(
      emoji: '⏰',
      title: 'When should we remind you?',
      text: 'One gentle reminder a day, only if you haven’t read yet.',
      action: 'Let’s go 🚀',
      onAction: () async {
        await Notify.setReminder(_remind == 'off' ? null : _remind);
        _next();
      },
      content: Column(
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChoiceChip(
                showCheckmark: false,
                avatar: Text(o.$3),
                label: SizedBox(width: double.infinity, child: Text('${o.$2} · ${_hm(o.$1)}')),
                selected: _remind == o.$1,
                onSelected: (_) => setState(() => _remind = o.$1),
              ),
            ),
          TextButton(
            onPressed: () => setState(() => _remind = 'off'),
            child: Text(_remind == 'off' ? '✓ No reminder' : 'No reminder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: i <= _at ? SioColors.blue : SioColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Skip'))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _at = i),
              children: [
                for (final s in steps)
                  switch (s) {
                    'stage' => _stagePage(),
                    'ayah' => _ayah(),
                    'photo' => _photo(),
                    'friends' => _friends(),
                    _ => _reminder(),
                  },
              ],
            ),
    );
  }
}

String _hm(String hm) {
  final p = hm.split(':');
  final h = int.parse(p[0]);
  return '${h % 12 == 0 ? 12 : h % 12}:${p[1]} ${h < 12 ? 'AM' : 'PM'}';
}

class _Page extends StatelessWidget {
  const _Page({
    required this.emoji,
    required this.title,
    required this.text,
    required this.content,
    required this.action,
    required this.onAction,
    this.hero,
  });
  final Widget? hero;
  final String emoji;
  final String title;
  final String text;
  final Widget content;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            if (hero != null)
              Align(alignment: Alignment.centerLeft, child: hero!)
            else
              Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(text, style: TextStyle(fontSize: 15, color: SioColors.textSecondary, height: 1.4)),
            const SizedBox(height: 20),
            content,
          ],
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: const StadiumBorder()),
              onPressed: onAction,
              child: Text(action, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    ],
  );
}
