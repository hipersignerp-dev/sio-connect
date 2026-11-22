import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../fx.dart';
import '../links.dart';
import '../theme.dart';
import '../widgets.dart';

// The student board: scholarships, exam & admission notices, careers, study circles, notes and blood requests.

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);
List<Map<String, dynamic>> _l(dynamic v) => [for (final x in (v as List? ?? [])) _m(x)];

const kinds = ['Job', 'Internship', 'Scholarship', 'Exam & Admission', 'Career', 'Notes', 'Blood Request'];

(IconData, Color, String) kindLook(String k) => switch (k) {
  'Scholarship' => (Icons.school, const Color(0xFF1E8E3E), 'Scholarships'),
  'Exam & Admission' => (Icons.assignment, const Color(0xFF1A62A8), 'Exams & admissions'),
  'Career' => (Icons.work_outline, const Color(0xFF7C3AED), 'Careers'),
  'Job' => (Icons.business_center_outlined, const Color(0xFF0E3F70), 'Jobs'),
  'Internship' => (Icons.badge_outlined, const Color(0xFF0E7490), 'Internships'),
  'Study Circle' => (Icons.menu_book, const Color(0xFFE0A100), 'Study circles'),
  'Notes' => (Icons.description_outlined, const Color(0xFF0E7490), 'Notes'),
  'Blood Request' => (Icons.bloodtype, const Color(0xFFC8202A), 'Blood requests'),
  _ => (Icons.push_pin_outlined, SioColors.blue, k),
};

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  String? _kind;
  int _v = 0;
  bool _lead = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SioColors.background,
    appBar: AppBar(
      backgroundColor: SioColors.background,
      surfaceTintColor: SioColors.background,
      title: const Text('Student board', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        final ok = await push<bool>(context, PostBoardScreen(lead: _lead, kind: _kind));
        if (ok == true) setState(() => _v++);
      },
      icon: const Icon(Icons.add),
      label: const Text('Post'),
    ),
    body: Loader<Map<String, dynamic>>(
      key: ValueKey('$_v$_kind'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      load: () async => _m(await Api.call('${Api.m}opportunities', {'kind': _kind})),
      builder: (context, d) {
        _lead = d['can_post_all'] == true;
        final items = _l(d['items']);
        final counts = _m(d['counts']);
        return [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _kind == null,
                    onSelected: (_) => setState(() => _kind = null),
                  ),
                ),
                for (final k in kinds)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(kindLook(k).$1, size: 18, color: _kind == k ? Colors.white : kindLook(k).$2),
                      label: Text('${kindLook(k).$3}${_kind == null && numOf(counts[k]) > 0 ? ' ${counts[k]}' : ''}'),
                      selected: _kind == k,
                      showCheckmark: false,
                      selectedColor: kindLook(k).$2,
                      labelStyle: TextStyle(color: _kind == k ? Colors.white : SioColors.ink),
                      onSelected: (_) => setState(() => _kind = _kind == k ? null : k),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            EmptyNote(
              _kind == null
                  ? 'Nothing on the board yet. Share notes, start a study circle, or ask your leaders to post scholarships.'
                  : 'Nothing here yet.',
            ),
          for (final (i, x) in items.indexed)
            Enter(
              index: i,
              child: _BoardCard(x: x, onChanged: () => setState(() => _v++)),
            ),
        ];
      },
    ),
  );
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.x, required this.onChanged});
  final Map<String, dynamic> x;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = kindLook('${x['kind']}');
    final blood = x['kind'] == 'Blood Request';
    final date = parseDate(x['last_date']);
    final daysLeft = date?.difference(DateTime.now()).inDays;
    final file = '${x['attachment'] ?? ''}';
    final link = '${x['link'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: blood ? SioColors.dangerBg : SioColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: blood ? SioColors.danger.withValues(alpha: 0.35) : SioColors.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(color: color, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800),
                  ),
                ),
                if (blood && '${x['blood_group'] ?? ''}'.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: SioColors.red, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${x['blood_group']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                if (daysLeft != null && !blood && daysLeft >= 0 && daysLeft <= 7)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: SioColors.warningBg, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      daysLeft == 0 ? 'Last day!' : '$daysLeft days left',
                      style: TextStyle(color: SioColors.warning, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                if (x['can_delete'] == true)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (v) async {
                      final ok = await run(
                        context,
                        () => Api.call('${Api.m}opportunity_action', {'name': x['name'], 'action': v}),
                        done: v == 'delete' ? 'Deleted' : 'Marked as closed',
                      );
                      if (ok) onChanged();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'close', child: Text(blood ? 'Found a donor, close' : 'Close')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${x['title']}',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: SioColors.ink),
            ),
            if ('${x['details'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${x['details']}', style: TextStyle(color: SioColors.text, height: 1.4)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (date != null)
                  _Meta(
                    Icons.event,
                    blood || x['kind'] == 'Study Circle' ? fmtDate(x['last_date']) : 'Last date ${fmtDate(x['last_date'])}',
                  ),
                if ('${x['place'] ?? ''}'.isNotEmpty) _Meta(Icons.place_outlined, '${x['place']}'),
                if (x['posted_by_name'] != null)
                  _Meta(Icons.person_outline, '${x['posted_by_name']} · ${timeSince(x['creation'])}'),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (link.isNotEmpty)
                  _Btn(Icons.open_in_new, 'Open link', () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication)),
                if (file.isNotEmpty)
                  _Btn(
                    Icons.download,
                    'Open file',
                    () => launchUrl(Uri.parse('${Api.baseUrl}$file'), mode: LaunchMode.externalApplication),
                  ),
                if ('${x['contact'] ?? ''}'.isNotEmpty)
                  _Btn(Icons.call, 'Call', () => launchUrl(Uri.parse('tel:${x['contact']}')), color: SioColors.green),
                _Btn(
                  Icons.share,
                  'Share',
                  () => SharePlus.instance.share(
                    ShareParams(
                      text: [
                        if (blood) '🩸 ${x['blood_group'] ?? ''} blood needed' else '📌 $label',
                        '${x['title']}',
                        if ('${x['details'] ?? ''}'.isNotEmpty) '${x['details']}',
                        if ('${x['place'] ?? ''}'.isNotEmpty) '📍 ${x['place']}',
                        if (date != null) '🗓 ${fmtDate(x['last_date'])}',
                        if ('${x['contact'] ?? ''}'.isNotEmpty) '📞 ${x['contact']}',
                        if (link.isNotEmpty) link,
                        if (file.isNotEmpty) '${Api.baseUrl}$file',
                        '— SIO Connect student board: ${Links.share({'b': '1'})}',
                      ].join('\n'),
                    ),
                  ),
                  color: const Color(0xFF25D366),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String timeSince(dynamic v) {
  final d = parseDate(v);
  if (d == null) return '';
  final s = DateTime.now().difference(d);
  if (s.inHours < 1) return 'just now';
  if (s.inHours < 24) return '${s.inHours}h ago';
  if (s.inDays < 7) return '${s.inDays}d ago';
  return fmtDate(v, 'd MMM');
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: SioColors.textSecondary),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5)),
    ],
  );
}

class _Btn extends StatelessWidget {
  const _Btn(this.icon, this.label, this.onTap, {this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Squish(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: (color ?? SioColors.blue).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? SioColors.blue),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color ?? SioColors.blue, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

class PostBoardScreen extends StatefulWidget {
  const PostBoardScreen({super.key, required this.lead, this.kind, this.shared});
  final bool lead;
  final String? kind;
  final String? shared; // text forwarded from another app (Share > SIO Connect)

  @override
  State<PostBoardScreen> createState() => _PostBoardScreenState();
}

class _PostBoardScreenState extends State<PostBoardScreen> {
  late String _kind = widget.kind != null && (widget.lead || !_leadOnly.contains(widget.kind)) ? widget.kind! : 'Notes';
  static const _leadOnly = ['Career'];

  @override
  void initState() {
    super.initState();
    final t = (widget.shared ?? '').trim();
    if (t.isEmpty) return;
    // fill the post from the forwarded message: first line as title, the rest as details, the first link as link
    final url = RegExp(r'https?://\S+').firstMatch(t)?.group(0);
    final lines = t.split('\n').map((l) => l.replaceAll('*', '').trim()).where((l) => l.isNotEmpty).toList();
    final first = lines.isEmpty ? '' : lines.first;
    _title.text = first.length > 100 ? '${first.substring(0, 97)}…' : first;
    _details.text = t;
    if (url != null) _link.text = url;
    final low = t.toLowerCase();
    _kind = low.contains('intern')
        ? 'Internship'
        : low.contains('scholarship')
        ? 'Scholarship'
        : RegExp(r'vacanc|hiring|job|walk-in|recruit|opening').hasMatch(low)
        ? 'Job'
        : RegExp(r'exam|admission|entrance|apply|application|last date').hasMatch(low)
        ? 'Exam & Admission'
        : RegExp(r'blood|donor').hasMatch(low)
        ? 'Blood Request'
        : 'Notes';
  }

  final _title = TextEditingController();
  final _details = TextEditingController();
  final _link = TextEditingController();
  final _place = TextEditingController();
  final _contact = TextEditingController();
  DateTime? _date;
  String? _blood;
  PlatformFile? _file;
  bool _everywhere = false;
  bool _busy = false;

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'ppt', 'pptx'],
    );
    if (files.isEmpty) return;
    final f = files.first;
    final size = await f.length() ?? 0;
    if (size > 5 * 1024 * 1024) {
      if (mounted) toast(context, 'That file is bigger than 5 MB.');
      return;
    }
    setState(() => _file = f);
  }

  Future<void> _save() async {
    if (_kind == 'Blood Request' && _blood == null) {
      toast(context, 'Pick the blood group.');
      return;
    }
    setState(() => _busy = true);
    try {
      String? data;
      if (_file != null) data = base64Encode(await _file!.readAsBytes());
      await Api.call('${Api.m}save_opportunity', {
        'kind': _kind,
        'title': _title.text.trim(),
        'details': _details.text.trim(),
        'link': _link.text.trim(),
        'place': _place.text.trim(),
        'contact': _contact.text.trim(),
        'last_date': _date == null ? null : apiDate(_date!),
        'blood_group': _blood,
        'everywhere': _everywhere ? 1 : null,
        'file_data': data,
        'file_name': _file?.name,
      });
      if (!mounted) return;
      toast(context, _kind == 'Blood Request' ? 'Posted. Everyone in your area has been alerted 🩸' : 'Posted');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.lead ? kinds : kinds.where((k) => !_leadOnly.contains(k)).toList();
    final blood = _kind == 'Blood Request';
    return Scaffold(
      appBar: AppBar(title: const Text('Post on the board')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in options)
                ChoiceChip(
                  avatar: Icon(kindLook(k).$1, size: 18, color: _kind == k ? Colors.white : kindLook(k).$2),
                  label: Text(k),
                  selected: _kind == k,
                  showCheckmark: false,
                  selectedColor: kindLook(k).$2,
                  labelStyle: TextStyle(color: _kind == k ? Colors.white : SioColors.ink),
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          if (!widget.lead)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Saw a job, scholarship or exam alert on WhatsApp? Share it here: in WhatsApp, long-press the message → Share → SIO Connect.',
                style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: switch (_kind) {
                'Notes' => 'e.g. Physics sem 3 notes, module 2',
                'Blood Request' => 'e.g. Needed for surgery tomorrow',
                'Study Circle' => 'e.g. Weekly Quran study, Saturday 7 pm',
                'Scholarship' => 'e.g. Merit scholarship for degree students',
                'Exam & Admission' => 'e.g. Plus One admission: apply by 30 Nov',
                'Job' => 'e.g. Accountant needed at our firm in Kochi (referral)',
                'Internship' => 'e.g. 2-month web development internship, Calicut',
                _ => 'e.g. Free coaching for UPSC prelims',
              },
            ),
          ),
          if (blood) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _blood,
              decoration: const InputDecoration(labelText: 'Blood group'),
              items: [
                for (final g in ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']) DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (v) => setState(() => _blood = v),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(labelText: 'Details (optional)'),
          ),
          if (!blood && _kind != 'Notes') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Link (optional)', prefixIcon: Icon(Icons.link)),
            ),
          ],
          if (blood || _kind == 'Study Circle' || _kind == 'Job' || _kind == 'Internship') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _place,
              decoration: InputDecoration(labelText: blood ? 'Hospital / place' : 'Place'),
            ),
          ],
          if (blood || _kind == 'Study Circle' || _kind == 'Job' || _kind == 'Internship' || widget.lead) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _contact,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact number (optional)', prefixIcon: Icon(Icons.call)),
            ),
          ],
          if (_kind != 'Notes') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (d != null) setState(() => _date = d);
              },
              icon: const Icon(Icons.event),
              label: Text(
                _date == null
                    ? (blood
                          ? 'When is it needed? (optional)'
                          : (_kind == 'Study Circle' ? 'Date (optional)' : 'Last date (optional)'))
                    : fmtDate(apiDate(_date!)),
              ),
            ),
          ],
          if (_kind == 'Notes' || widget.lead) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_file == null ? 'Attach a file (PDF, image, Word, PPT · up to 5 MB)' : _file!.name),
            ),
          ],
          if (widget.lead && !blood)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _everywhere,
              onChanged: (v) => setState(() => _everywhere = v),
              title: const Text('Show to every area'),
              subtitle: const Text('Off: only your area sees it'),
            ),
          if (blood)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: SioBanner(text: 'Everyone in your area will get a notification. Post only real, urgent needs.'),
            ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: blood ? SioColors.red : null,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Posting…' : (blood ? 'Alert my area' : 'Post')),
          ),
        ],
      ),
    );
  }
}
