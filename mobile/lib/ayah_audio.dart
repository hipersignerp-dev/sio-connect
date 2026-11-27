import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

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
class MalayalamSpeakButton extends StatefulWidget {
  const MalayalamSpeakButton({super.key, required this.text, this.light = false, this.onComplete});
  final String text;
  final VoidCallback? onComplete; // read to the end
  final bool light;

  @override
  State<MalayalamSpeakButton> createState() => _MalayalamSpeakButtonState();
}

class _MalayalamSpeakButtonState extends State<MalayalamSpeakButton> {
  static final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  @override
  void dispose() {
    if (_speaking) _tts.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final ok = await _tts.isLanguageAvailable('ml-IN');
    if (ok != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              'Your phone has no Malayalam voice yet. Open Settings → Text-to-speech (Speech services by Google) '
              '→ Install voice data → Malayalam.',
            ),
          ),
        );
      }
      return;
    }
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
              Icon(_speaking ? Icons.stop_rounded : Icons.record_voice_over_outlined, color: fg, size: 18),
              const SizedBox(width: 4),
              Text(
                _speaking ? 'Stop' : 'മലയാളം',
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
