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
  late final _summary = TextEditingController(
    text: '${widget.meeting['summary'] ?? ''}'.trim().isNotEmpty
        ? '${widget.meeting['summary']}'
        : '${widget.meeting['minutes'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
  );
  String _lang = 'English';
  bool _wantListen = false; // the person pressed the mic and has not stopped it
  bool _ready = false;
  // Notes are only ever added to: [_committed] holds every finished sentence, [_partial] the one being heard.
  String _committed = '';
  String _partial = '';
  String _lastCommitted = '';
  DateTime _lastAt = DateTime.now();
  int _session = 0; // results from an older listening session are ignored
  bool _restarting = false;
  final _notesScroll = ScrollController();
  double _level = 0;
  bool _aiBusy = false;
  bool _saving = false;

  bool get _aiReady => widget.meeting['ai_ready'] == true;
  String get _locale => _lang == 'Malayalam' ? 'ml_IN' : 'en_IN';

  @override
  void dispose() {
    _wantListen = false;
    _speech.cancel();
    _notesScroll.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_wantListen) {
      _session++; // ignore anything the recogniser still sends for this session
      setState(() {
        _wantListen = false;
        _commit(_partial);
        _partial = '';
        _show();
      });
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
    _committed = _notes.text.trim(); // keep anything typed by hand
    _lastCommitted = '';
    setState(() => _wantListen = true);
    await _listen();
  }

  Future<void> _listen() async {
    if (!_wantListen || !mounted) return;
    final session = ++_session;
    _commit(_partial);
    _partial = '';
    _lastCommitted = '';
    await _speech.listen(
      onResult: (r) => _onResult(r, session),
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

  /// Adds a finished sentence to the notes (never twice in a row, never replacing what is there).
  void _commit(String sentence) {
    var t = sentence.trim();
    if (t.isEmpty) return;
    final last = _lastCommitted.toLowerCase();
    if (last.isNotEmpty) {
      if (t.toLowerCase() == last) return;
      if (t.toLowerCase().startsWith(last)) t = t.substring(last.length).trim();
      if (t.isEmpty) return;
    }
    _committed = _committed.isEmpty ? t : '$_committed $t';
    _lastCommitted = sentence.trim();
  }

  /// Shows the notes plus the words being heard, and keeps the end in view.
  void _show() {
    final text = _partial.isEmpty ? _committed : (_committed.isEmpty ? _partial : '$_committed $_partial');
    _notes.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_notesScroll.hasClients) _notesScroll.jumpTo(_notesScroll.position.maxScrollExtent);
    });
  }

  void _onResult(SpeechRecognitionResult r, int session) {
    if (!mounted || session != _session) return;
    var t = r.recognizedWords.trim();
    // some phones repeat the previous sentence at the start of the next one
    final last = _lastCommitted.toLowerCase();
    if (last.isNotEmpty && t.toLowerCase().startsWith(last) && t.length > last.length) {
      t = t.substring(last.length).trim();
    }
    final now = DateTime.now();
    final gap = now.difference(_lastAt);
    _lastAt = now;
    setState(() {
      if (r.finalResult || r.resultTypeValue == ResultType.intermediate) {
        // a finished sentence
        _commit(t.isEmpty ? _partial : t);
        _partial = '';
      } else {
        // Android starts each new sentence from empty: keep the previous one before showing the new one
        if (_partial.isNotEmpty && t.isNotEmpty && _isNewSentence(_partial, t, gap)) _commit(_partial);
        _partial = t;
      }
      _show();
    });
  }

  /// True when [now] is a fresh sentence rather than a longer or corrected version of [before].
  static bool _isNewSentence(String before, String now, Duration gap) {
    final b = before.toLowerCase();
    final n = now.toLowerCase();
    final bw = b.split(RegExp(r'\s+'));
    final nw = n.split(RegExp(r'\s+'));
    // after a pause, a much shorter text is a new sentence even if it starts with the same word
    if (gap > const Duration(milliseconds: 1200) && nw.length + 2 <= bw.length) return true;
    if (n.startsWith(b) || b.startsWith(n)) return false;
    // the recogniser may revise the last words, but a continuing sentence keeps its first word
    if (bw.isNotEmpty && nw.isNotEmpty && bw.first == nw.first && nw.length >= bw.length - 2) return false;
    return true;
  }

  // Android stops listening after a pause; keep going until the person taps stop.
  void _onStatus(String s) {
    if ((s == 'done' || s == 'notListening') && _wantListen && !_restarting) {
      _restarting = true;
      Future.delayed(const Duration(milliseconds: 300), () async {
        _restarting = false;
        if (_wantListen && !_speech.isListening) await _listen();
      });
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
    } else if (_wantListen && !_restarting) {
      _restarting = true;
      Future.delayed(const Duration(milliseconds: 400), () async {
        _restarting = false;
        if (_wantListen && !_speech.isListening) await _listen();
      });
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            '${m['topic']}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SioColors.ink),
          ),
          Text(
            [
              m['where'] ?? m['unit'],
              fmtDate(m['meeting_date'], 'EEE d MMM'),
            ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
            style: const TextStyle(color: SioColors.textSecondary),
          ),
          const SizedBox(height: 18),
          // 1. speak
          Row(
            children: [
              const Expanded(
                child: Text('1. Speak your rough notes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
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
                  if (restart) {
                    _session++;
                    setState(() {
                      _commit(_partial);
                      _partial = '';
                      _show();
                    });
                    await _speech.stop();
                  }
                  setState(() => _lang = v.first);
                  if (restart && _wantListen) await _listen();
                },
              ),
            ],
          ),
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
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            scrollController: _notesScroll,
            readOnly: _wantListen,
            minLines: 4,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _wantListen ? (_partial.isEmpty ? 'Rough notes · listening…' : 'Rough notes · writing…') : 'Rough notes',
              hintText: 'Who came, what was discussed, what was decided, who will do what…',
              alignLabelWithHint: true,
              suffixIcon: _notes.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _notes.clear();
                        _committed = '';
                        _partial = '';
                        _lastCommitted = '';
                      }),
                    ),
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
            const SioBanner(
              text: 'AI clean-up is not switched on yet (an AI key is needed in SIO Settings). You can copy your notes below and correct them yourself.',
            ),
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
            decoration: const InputDecoration(labelText: 'Summary (you can correct it)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Save summary'),
          ),
        ],
      ),
    );
  }
}
