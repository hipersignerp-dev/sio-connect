import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Updates')),
      floatingActionButton: AppState.i.can('send_notice')
          ? AddFab(tooltip: 'Send update', onPressed: () => push(context, const SendNoticeScreen()))
          : null,
      body: Loader<List<dynamic>>(
        load: () async => (await Api.call('${Api.m}notices') as List?) ?? [],
        builder: (context, list) => [
          if (list.isEmpty) const EmptyNote('No updates yet.'),
          for (final n in list) ...[
            SioPanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n['title'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SioColors.ink)),
                const SizedBox(height: 4),
                Text(
                  [n['audience'] == 'Unit' ? n['unit'] : n['audience'] == 'Role' ? n['member_role'] : n['audience'], fmtDate(n['sent_on'], 'd MMM, h:mm a')]
                      .where((x) => x != null && '$x'.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(color: SioColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(n['message'].toString(), style: const TextStyle(fontSize: 15, height: 1.4)),
              ]),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class SendNoticeScreen extends StatefulWidget {
  const SendNoticeScreen({super.key});

  @override
  State<SendNoticeScreen> createState() => _SendNoticeScreenState();
}

class _SendNoticeScreenState extends State<SendNoticeScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  late String _audience;
  String _role = 'Member';
  String? _event;
  bool _wa = true;
  bool _email = false;
  bool _busy = false;
  List<dynamic> _events = [];

  bool get _admin => AppState.i.can('all_units') && AppState.i.role == 'Area Admin';
  List<String> get _audiences => _admin ? const ['Everyone', 'Unit', 'Role', 'Event Registrants'] : const ['Unit', 'Event Registrants'];

  @override
  void initState() {
    super.initState();
    _audience = _audiences.first;
    Api.call('${Api.m}events').then((v) {
      if (mounted) setState(() => _events = (v as List?) ?? []);
    }).catchError((_) {});
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      toast(context, 'Add a title and a message.');
      return;
    }
    if (_audience == 'Event Registrants' && _event == null) {
      toast(context, 'Pick the event.');
      return;
    }
    setState(() => _busy = true);
    String? done;
    final ok = await run(context, () async {
      final r = await Api.call('${Api.m}send_notice', {
        'title': _title.text.trim(),
        'message': _message.text.trim(),
        'audience': _audience,
        'member_role': _audience == 'Role' ? _role : null,
        'event': _audience == 'Event Registrants' ? _event : null,
        'send_whatsapp': _wa,
        'send_email': _email,
      });
      done = 'Sent to ${(r as Map)['recipients']} members.';
    });
    if (mounted) {
      setState(() => _busy = false);
      if (ok) {
        toast(context, done ?? 'Sent.');
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = AppState.i.me['unit'] ?? 'your unit';
    return Scaffold(
      appBar: AppBar(title: const Text('Send update')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 14),
        TextField(controller: _message, maxLines: 5, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Message')),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _audience,
          decoration: const InputDecoration(labelText: 'Send to'),
          items: [
            for (final a in _audiences)
              DropdownMenuItem(value: a, child: Text(a == 'Unit' ? (_admin ? 'A unit (yours)' : '$unit members') : a)),
          ],
          onChanged: (v) => setState(() => _audience = v ?? _audience),
        ),
        if (_audience == 'Role') ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [
              for (final r in const ['Associate', 'Member', 'Unit Secretary', 'Unit President', 'Finance', 'Area Admin'])
                DropdownMenuItem(value: r, child: Text(r))
            ],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
        ],
        if (_audience == 'Event Registrants') ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _event,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Event'),
            items: [for (final e in _events) DropdownMenuItem(value: e['name'].toString(), child: Text(e['title'].toString(), overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _event = v),
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(value: _wa, onChanged: (v) => setState(() => _wa = v), title: const Text('Also send on WhatsApp'), contentPadding: EdgeInsets.zero),
        SwitchListTile(value: _email, onChanged: (v) => setState(() => _email = v), title: const Text('Also send by email'), contentPadding: EdgeInsets.zero),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _busy ? null : _send, icon: const Icon(Icons.send), label: const Text('Send')),
      ]),
    );
  }
}
