import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';

/// Play / stop the recitation of today's ayah (one or more files, played one after another).
class AyahAudioButton extends StatefulWidget {
  const AyahAudioButton({super.key, required this.urls, this.light = false, this.onComplete});
  final List<String> urls;
  final VoidCallback? onComplete; // played to the end
  final bool light; // white on a dark card

  @override
  State<AyahAudioButton> createState() => _AyahAudioButtonState();
}

class _AyahAudioButtonState extends State<AyahAudioButton> {
  AudioPlayer? _p;
  bool _playing = false;
  bool _loading = false;

  @override
  void dispose() {
    _p?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _p?.stop();
      setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      _p ??= AudioPlayer()
        ..playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed && mounted) {
            if (_playing) widget.onComplete?.call();
            setState(() => _playing = false);
            _p?.stop();
            _p?.seek(Duration.zero, index: 0);
          }
        });
      await _p!.setAudioSources([for (final u in widget.urls) AudioSource.uri(Uri.parse(u))]);
      setState(() {
        _loading = false;
        _playing = true;
      });
      await _p!.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _playing = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not play the recitation. Check your internet.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.light ? Colors.white : const Color(0xFF1A62A8);
    return Material(
      color: widget.light ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFE8F0FA),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _loading ? null : _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _loading
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                  : Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded, color: fg, size: 20),
              const SizedBox(width: 4),
              Text(
                _playing ? 'Stop' : 'Listen',
                style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reads the Malayalam meaning (and today's lesson) aloud with the phone's Malayalam voice.
/// Reads the Malayalam meaning and lesson aloud. Uses the natural recording the server makes for the reading
/// (Gemini text-to-speech, made once and shared); falls back to the phone's own voice only if that fails.
class MalayalamSpeakButton extends StatefulWidget {
  const MalayalamSpeakButton({super.key, required this.text, this.light = false, this.onComplete, this.reading});
  final String text;
  final VoidCallback? onComplete; // read to the end
  final bool light;

  /// The daily reading (needs 'name'; 'ml_audio' if already recorded). Null = phone voice only.
  final Map? reading;

  @override
  State<MalayalamSpeakButton> createState() => _MalayalamSpeakButtonState();
}

class _MalayalamSpeakButtonState extends State<MalayalamSpeakButton> {
  static final FlutterTts _tts = FlutterTts();
  AudioPlayer? _p;
  StreamSubscription<PlayerState>? _sub;
  bool _speaking = false;
  bool _loading = false;
  bool _usingTts = false;

  @override
  void dispose() {
    if (_speaking && _usingTts) _tts.stop();
    _sub?.cancel();
    _p?.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    if (_usingTts) {
      await _tts.stop();
    } else {
      await _p?.stop();
    }
    if (mounted) setState(() => _speaking = false);
  }

  Future<String?> _recording() async {
    final r = widget.reading;
    if (r == null || '${r['name'] ?? ''}'.isEmpty) return null;
    var url = '${r['ml_audio'] ?? ''}';
    if (url.isEmpty) {
      final res = await Api.call('sio_connect.tts.ml_audio', {'reading': '${r['name']}'});
      url = '${(res is Map ? res['url'] : null) ?? ''}';
      if (url.isNotEmpty) r['ml_audio'] = url;
    }
    if (url.isEmpty) return null;
    return url.startsWith('http') ? url : '${Api.baseUrl}$url';
  }

  Future<void> _toggle() async {
    if (_speaking) return _stop();
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final url = await _recording();
      if (url != null) {
        _p ??= AudioPlayer();
        await _p!.setUrl(url);
        _usingTts = false;
        await _sub?.cancel();
        _sub = _p!.playerStateStream.listen((st) {
          if (st.processingState == ProcessingState.completed && _speaking) {
            widget.onComplete?.call();
            if (mounted) setState(() => _speaking = false);
          }
        });
        if (mounted) {
          setState(() {
            _loading = false;
            _speaking = true;
          });
        }
        await _p!.play();
        return;
      }
    } catch (_) {
      // fall back to the phone's voice below
    }
    if (mounted) setState(() => _loading = false);
    await _phoneVoice();
  }

  Future<void> _phoneVoice() async {
    final ok = await _tts.isLanguageAvailable('ml-IN');
    if (ok != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text('Couldn’t load the Malayalam audio. Check your internet and try again.'),
          ),
        );
      }
      return;
    }
    _usingTts = true;
    await _tts.setLanguage('ml-IN');
    await _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() {
      if (mounted) {
        if (_speaking) widget.onComplete?.call();
        setState(() => _speaking = false);
      }
    });
    setState(() => _speaking = true);
    await _tts.speak(widget.text);
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.light ? Colors.white : const Color(0xFF1A62A8);
    return Material(
      color: widget.light ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFE8F0FA),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else
                Icon(_speaking ? Icons.stop_rounded : Icons.record_voice_over_outlined, color: fg, size: 18),
              const SizedBox(width: 4),
              Text(
                _loading
                    ? 'Preparing…'
                    : _speaking
                    ? 'Stop'
                    : 'മലയാളം',
                style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the Malayalam button reads: the meaning, then today's lesson.
String malayalamToRead(Map r) => [
  if ('${r['text_ml'] ?? ''}'.isNotEmpty) '${r['text_ml']}',
  if ('${r['lesson_ml'] ?? ''}'.isNotEmpty) 'ഇന്നത്തെ പാഠം. ${r['lesson_ml']}',
].join('\n');

/// One big button: plays the Arabic recitation, then the Malayalam meaning, in one go.
class ListenAllButton extends StatefulWidget {
  const ListenAllButton({super.key, required this.urls, required this.reading, required this.malayalam, this.onComplete});
  final List<String> urls; // the Arabic recitation, one or more files
  final Map reading; // the daily reading, for its Malayalam recording
  final String malayalam; // the text, if the phone's voice has to read it
  final VoidCallback? onComplete;

  @override
  State<ListenAllButton> createState() => _ListenAllButtonState();
}

class _ListenAllButtonState extends State<ListenAllButton> {
  static final FlutterTts _tts = FlutterTts();
  final AudioPlayer _p = AudioPlayer();
  String _part = ''; // '' idle, 'ar' Arabic, 'ml' Malayalam, 'load'
  int _run = 0; // a new tap cancels the old run

  @override
  void dispose() {
    _run++;
    _tts.stop();
    _p.dispose();
    super.dispose();
  }

  Future<String?> _mlUrl() async {
    final r = widget.reading;
    var url = '${r['ml_audio'] ?? ''}';
    if (url.isEmpty && '${r['name'] ?? ''}'.isNotEmpty) {
      try {
        final res = await Api.call('sio_connect.tts.ml_audio', {'reading': '${r['name']}'});
        url = '${(res is Map ? res['url'] : null) ?? ''}';
        if (url.isNotEmpty) r['ml_audio'] = url;
      } catch (_) {}
    }
    if (url.isEmpty) return null;
    return url.startsWith('http') ? url : '${Api.baseUrl}$url';
  }

  Future<bool> _playUrl(String url, int run) async {
    await _p.setUrl(url);
    if (run != _run) return false;
    await _p.play(); // returns when it stops or finishes
    return run == _run && _p.processingState == ProcessingState.completed;
  }

  Future<void> _stop() async {
    _run++;
    await _p.stop();
    await _tts.stop();
    if (mounted) setState(() => _part = '');
  }

  Future<void> _start() async {
    final run = ++_run;
    setState(() => _part = widget.urls.isEmpty ? 'load' : 'ar');
    final ml = widget.malayalam.isEmpty ? Future<String?>.value(null) : _mlUrl(); // fetch while Arabic plays
    try {
      for (final u in widget.urls) {
        if (!await _playUrl(u, run)) return;
      }
      if (widget.malayalam.isEmpty) return _done(run);
      if (mounted) setState(() => _part = 'load');
      final url = await ml;
      if (run != _run) return;
      if (mounted) setState(() => _part = 'ml');
      if (url != null) {
        if (await _playUrl(url, run)) _done(run);
        return;
      }
      // no recording yet: the phone's voice
      if (await _tts.isLanguageAvailable('ml-IN') != true) return _done(run);
      await _tts.setLanguage('ml-IN');
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(widget.malayalam);
      if (run == _run) _done(run);
    } catch (_) {
      if (run == _run && mounted) {
        setState(() => _part = '');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t play. Check your internet.')));
      }
    }
  }

  void _done(int run) {
    if (run != _run) return;
    widget.onComplete?.call();
    if (mounted) setState(() => _part = '');
  }

  @override
  Widget build(BuildContext context) {
    final busy = _part.isNotEmpty;
    final label = switch (_part) {
      'ar' => 'Playing Arabic…  then മലയാളം',
      'load' => 'Getting മലയാളം…',
      'ml' => 'Playing മലയാളം…',
      _ => 'Listen  ·  Arabic + മലയാളം',
    };
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1A62A8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: busy ? _stop : _start,
        icon: Icon(busy ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 26),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
