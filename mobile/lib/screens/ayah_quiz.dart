import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../noor.dart';
import '../theme.dart';

/// Two quick questions about today's ayah, after listening or reading it.
/// Returns true when both are answered right (a wrong answer shows the right one; try again).
Future<bool> askAyahQuiz(BuildContext context, Map reading) async {
  final qs = <_Q>[
    for (final n in [1, 2])
      if ('${reading['q$n'] ?? ''}'.trim().isNotEmpty && '${reading['q${n}_answer'] ?? ''}'.trim().isNotEmpty)
        _Q(
          '${reading['q$n']}',
          '${reading['q${n}_answer']}',
          [
            for (final w in ['${reading['q${n}_wrong_1'] ?? ''}', '${reading['q${n}_wrong_2'] ?? ''}'])
              if (w.trim().isNotEmpty) w,
          ],
        ),
  ];
  if (qs.isEmpty) return true; // no questions for this one yet
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuizSheet(qs: qs),
  );
  return ok ?? false;
}

class _Q {
  _Q(this.question, this.answer, List<String> wrong) : options = ([answer, ...wrong]..shuffle(Random()));
  final String question;
  final String answer;
  final List<String> options;
}

class _QuizSheet extends StatefulWidget {
  const _QuizSheet({required this.qs});
  final List<_Q> qs;

  @override
  State<_QuizSheet> createState() => _QuizSheetState();
}

class _QuizSheetState extends State<_QuizSheet> {
  static const _deep = Color(0xFF0E3F70);
  static const _sio = Color(0xFF1A62A8);
  static const _green = Color(0xFF2E9E5B);
  static const _red = Color(0xFFD64545);

  int _i = 0;
  String? _picked;
  bool _wrongOnce = false;

  _Q get _q => widget.qs[_i];
  bool get _right => _picked == _q.answer;

  void _pick(String o) {
    if (_picked != null) return;
    setState(() {
      _picked = o;
      if (o != _q.answer) _wrongOnce = true;
    });
    if (o == _q.answer) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _next() {
    if (!_right) {
      // try again: same question, options shuffled
      setState(() {
        _q.options.shuffle(Random());
        _picked = null;
      });
      return;
    }
    if (_i + 1 < widget.qs.length) {
      setState(() {
        _i++;
        _picked = null;
      });
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _i + 1 == widget.qs.length;
    final mood = _picked == null
        ? NoorMood.hello
        : _right
        ? NoorMood.celebrate
        : NoorMood.worried;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // progress: two dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var k = 0; k < widget.qs.length; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: k == _i ? 28 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: k <= _i ? _sio : const Color(0xFFCFE5FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Noor(mood: mood, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question ${_i + 1} of ${widget.qs.length}',
                      style: const TextStyle(color: _sio, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _q.question,
                      style: malayalamStyle(color: _deep, size: 18, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final o in _q.options) _option(o),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _picked == null
                ? const SizedBox(height: 52)
                : SizedBox(
                    key: ValueKey('$_i$_picked'),
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _right ? _green : _sio,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _next,
                      child: Text(
                        !_right
                            ? 'Try again'
                            : last
                            ? (_wrongOnce ? 'Water Noor 💧' : 'Perfect! Water Noor 💧')
                            : 'Next question',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _option(String o) {
    final picked = _picked == o;
    final showRight = _picked != null && _right && o == _q.answer;
    final wrong = picked && !_right;
    final bg = showRight
        ? const Color(0xFFE3F5EA)
        : wrong
        ? const Color(0xFFFDE8E8)
        : const Color(0xFFF2F7FD);
    final border = showRight
        ? _green
        : wrong
        ? _red
        : const Color(0xFFCFE5FA);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _pick(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1.6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(o, style: malayalamStyle(color: const Color(0xFF1F2B38), size: 15.5, weight: FontWeight.w600)),
                ),
                if (showRight) const Icon(Icons.check_circle_rounded, color: _green),
                if (wrong) const Icon(Icons.cancel_rounded, color: _red),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
