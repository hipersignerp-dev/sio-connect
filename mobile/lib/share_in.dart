import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'links.dart';
import 'screens/board_screens.dart';

/// Share > SIO Connect from another app (WhatsApp forwards of jobs, scholarships, exam dates): opens the
/// "post on the board" form filled in with the shared text. Android hands the text to MainActivity.
class ShareIn {
  static const _ch = MethodChannel('com.hipersign.sio_connect/share');
  static bool _listening = false;

  /// Call once the person is signed in (the home shell is up).
  static Future<void> start() async {
    if (!_listening) {
      _listening = true;
      _ch.setMethodCallHandler((call) async {
        if (call.method == 'shared') await _open();
      });
    }
    await _open();
  }

  static Future<void> _open() async {
    String? text;
    try {
      text = await _ch.invokeMethod<String>('take');
    } catch (_) {
      return;
    }
    if (text == null || text.trim().isEmpty) return;
    final nav = navKey.currentState;
    if (nav == null || AppState.i.me['member'] == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => PostBoardScreen(lead: AppState.i.isLeader, shared: text),
      ),
    );
  }
}
