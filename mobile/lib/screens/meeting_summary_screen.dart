import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

/// Write the summary of a meeting. Speak rough notes (English or Malayalam) and the phone turns the
/// speech into text; then AI cleans the notes into proper minutes, which can still be corrected by hand.
class MeetingSummaryScreen extends StatefulWidget {
  const MeetingSummaryScreen({super.key, required this.meeting});
  final Map<String, dynamic> meeting;

  @override
  State<MeetingSummaryScreen> createState() => _MeetingSummaryScreenState();
}

class _MeetingSummaryScreenState extends State<MeetingSummaryScreen> {
  final _speech = SpeechToText();
  final _notes = TextEditingController();
  late final _summary = TextEditingController(text: '${widget.meeting['summary'] ?? ''}'.trim().isNotEmpty
      ? '${widget.meeting['summary']}'
      : '${widget.meeting['minutes'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '').trim());
  String _lang = 'English';
  bool _wantListen = false; // the person pressed the mic and has not stopped it
  bool _ready = false;
  String _partial = '';
  double _level = 0;
  bool _aiBusy = false;
  bool _saving = false;

  bool get _aiReady => widget.meeting['ai_ready'] == true;
  String get _locale => _lang == 'Malayalam' ? 'ml_IN' : 'en_IN';

  @override
  void dispose() {
    _wantListen = false;
    _speech.cancel();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_wantListen) {
      setState(() => _wantListen = false);
      await _speech.stop();
      return;
    }
    if (!_ready) {
      _ready = await _speech.initialize(onStatus: _onStatus, onError: _onError);
      if (!_ready) {
        if (mounted) toast(context, 'Voice typing is not available. Allow the microphone, or install Google speech services.');
        return;
      }
    }
    setState(() => _wantListen = true);
    await _listen();
  }

  Future<void> _listen() async {
    if (!_wantListen || !mounted) return;
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: (l) {
        if (mounted) setState(() => _level = l);
      },
      listenOptions: SpeechListenOptions(
        localeId: _locale,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        autoPunctuation: true,
        pauseFor: const Duration(seconds: 8),
        listenFor: const Duration(minutes: 5),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted) return;
    setState(() {
      if (r.finalResult) {
        final t = r.recognizedWords.trim();
        if (t.isNotEmpty) {
          final cur = _notes.text.trimRight();
          _notes.text = cur.isEmpty ? t : '$cur $t';
          _notes.selection = TextSelection.collapsed(offset: _notes.text.length);
        }
        _partial = '';
      } else {
        _partial = r.recognizedWords;
      }
    });
  }

  // Android stops listening after a pause; keep going until the person taps stop.
  void _onStatus(String s) {
    if ((s == 'done' || s == 'notListening') && _wantListen) {
      Future.delayed(const Duration(milliseconds: 250), _listen);
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted) return;
    final m = e.errorMsg;
    if (m.contains('permission') || m.contains('insufficient')) {
      setState(() => _wantListen = false);
      toast(context, 'Allow microphone access to speak your notes.');
    } else if (m.contains('language') || m.contains('not_supported')) {
      setState(() => _wantListen = false);
      toast(context, '$_lang voice typing is not available on this phone. Try the other language.');
    } else if (_wantListen) {
      Future.delayed(const Duration(milliseconds: 400), _listen);
    }
  }

  Future<void> _makeSummary() async {
    final notes = _notes.text.trim();
    if (notes.length < 10) {
      toast(context, 'Speak or type a few lines first.');
      return;
    }
    if (_wantListen) {
      setState(() => _wantListen = false);
      await _speech.stop();
    }
    if (!mounted) return;
    setState(() => _aiBusy = true);
    await run(context, () async {
      final r = await Api.call('${Api.m}ai_summary', {'name': widget.meeting['name'], 'notes': notes, 'language': _lang});
      _summary.text = '${(r as Map)['summary']}';
    }, done: 'Summary ready. Check it and save.');
    if (mounted) setState(() => _aiBusy = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await run(
      context,
      () => Api.call('${Api.m}save_meeting_summary', {'name': widget.meeting['name'], 'summary': _summary.text.trim()}),
      done: 'Summary saved.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meeting;
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting summary')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text('${m['topic']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SioColors.ink)),
        Text([m['unit'], fmtDate(m['meeting_date'], 'EEE d MMM')].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
            style: const TextStyle(color: SioColors.textSecondary)),
        const SizedBox(height: 18),
        // 1. speak
        Row(children: [
          const Expanded(child: Text('1. Speak your rough notes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 'English', label: Text('English')),
              ButtonSegment(value: 'Malayalam', label: Text('മലയാളം')),
            ],
            selected: {_lang},
            onSelectionChanged: (v) async {
              final restart = _wantListen;
              if (restart) await _speech.stop();
              setState(() => _lang = v.first);
              if (restart) _listen();
            },
          ),
        ]),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: _toggleMic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 92 + (_wantListen ? (_level.clamp(0, 10) * 2.4) : 0),
              height: 92 + (_wantListen ? (_level.clamp(0, 10) * 2.4) : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _wantListen ? SioColors.red : SioColors.blue,
                boxShadow: [
                  BoxShadow(
                    color: (_wantListen ? SioColors.red : SioColors.blue).withValues(alpha: 0.35),
                    blurRadius: _wantListen ? 26 : 14,
                    spreadRadius: _wantListen ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(_wantListen ? Icons.stop_rounded : Icons.mic, color: Colors.white, size: 42),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _wantListen ? 'Listening… tap to stop' : 'Tap the mic and talk about the meeting',
          textAlign: TextAlign.center,
          style: TextStyle(color: _wantListen ? SioColors.red : SioColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        if (_partial.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_partial,
                textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic, color: SioColors.textSecondary)),
          ),
        const SizedBox(height: 14),
        TextField(
          controller: _notes,
          minLines: 4,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Rough notes',
            hintText: 'Who came, what was discussed, what was decided, who will do what…',
            alignLabelWithHint: true,
            suffixIcon: _notes.text.isEmpty
                ? null
                : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close), onPressed: () => setState(() => _notes.clear())),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 22),
        // 2. clean up
        const Text('2. Make it a proper summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 10),
        if (_aiReady)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: SioColors.purple, minimumSize: const Size.fromHeight(50)),
            onPressed: _aiBusy ? null : _makeSummary,
            icon: _aiBusy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(_aiBusy ? 'Writing the summary…' : 'Write the summary with AI'),
          )
        else ...[
          const SioBanner(text: 'AI clean-up is not switched on yet (an AI key is needed in SIO Settings). You can copy your notes below and correct them yourself.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _notes.text.trim().isEmpty ? null : () => setState(() => _summary.text = _notes.text.trim()),
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Use my notes as the summary'),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _summary,
          minLines: 8,
          maxLines: 30,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Summary (you can correct it)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: const Text('Save summary'),
        ),
      ]),
    );
  }
}
