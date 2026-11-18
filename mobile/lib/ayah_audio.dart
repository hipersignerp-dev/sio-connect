import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

/// Play / stop the recitation of today's ayah (one or more files, played one after another).
class AyahAudioButton extends StatefulWidget {
  const AyahAudioButton({super.key, required this.urls, this.light = true});
  final List<String> urls;
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
