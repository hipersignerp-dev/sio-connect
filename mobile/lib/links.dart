import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'app_state.dart';
import 'screens/album_screens.dart';
import 'screens/board_screens.dart';
import 'screens/event_detail_screen.dart';
import 'screens/journey_screens.dart';

/// Links shared on WhatsApp (https://(site)/go?e=EVT-00001) open a page that hands over to the app as
/// sioconnect://open?e=EVT-00001. This opens the right screen, or keeps it until the person has signed in.
final navKey = GlobalKey<NavigatorState>();

class Links {
  static Uri? _pending;
  static String? inviteCode; // from an invite link, for the sign-up form
  static StreamSubscription<Uri>? _sub;

  /// https link to share: e (programme), a (album), u (person), q (quiz), b (board), i (invite code).
  static String share(Map<String, String> q) => Uri.parse('${Api.baseUrl}/go').replace(queryParameters: q).toString();

  static Future<void> start() async {
    final links = AppLinks();
    try {
      final first = await links.getInitialLink();
      if (first != null) _take(first);
    } catch (_) {}
    _sub ??= links.uriLinkStream.listen(_take, onError: (_) {});
  }

  static void _take(Uri u) {
    final q = u.queryParameters;
    if (q['i'] != null) inviteCode = q['i'];
    _pending = u;
    if (AppState.i.stage == Stage.signedIn) openPending();
  }

  /// Called once the app (signed in) is showing.
  static void openPending() {
    final u = _pending;
    final nav = navKey.currentState;
    if (u == null || nav == null) return;
    _pending = null;
    final q = u.queryParameters;
    Widget? screen;
    if (q['e'] != null) {
      screen = EventDetailScreen(name: q['e']!, title: 'Programme');
    } else if (q['a'] != null) {
      screen = AlbumScreen(name: q['a']!);
    } else if (q['u'] != null || q['i'] != null) {
      screen = PersonPage(username: q['u'] ?? q['i']);
    } else if (q['q'] != null) {
      screen = const JourneyScreen();
    } else if (q['b'] != null) {
      screen = const BoardScreen();
    }
    if (screen != null) nav.push(MaterialPageRoute<void>(builder: (_) => screen!));
  }
}
