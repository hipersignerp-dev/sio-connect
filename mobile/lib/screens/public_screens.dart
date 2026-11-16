import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../theme.dart';
import '../app_state.dart';
import '../widgets.dart';
import 'auth_screens.dart';
import 'donors_screen.dart';

/// The first screen for anyone not signed in: about SIO, the area leaders (call / WhatsApp), social media,
/// units, upcoming programmes and donations, with Sign in and Register at the top.
class PublicScreen extends StatelessWidget {
  const PublicScreen({super.key, this.landing = false});
  final bool landing;

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && context.mounted) toast(context, 'Could not open the link.');
  }

  @override
  Widget build(BuildContext context) {
    final notice = AppState.i.notice;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: !landing,
        title: Row(children: [
          const Image(image: AssetImage('assets/sio-logo.png'), width: 36, height: 36),
          const SizedBox(width: 10),
          const Expanded(child: Text('SIO Connect', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
        actions: [
          if (landing) ...[
            TextButton(onPressed: () => push(context, const RegisterScreen()), child: const Text('Register')),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(onPressed: () => push(context, const LoginScreen()), child: const Text('Sign in')),
            ),
          ],
        ],
      ),
      body: Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await Api.guest('info') as Map),
        builder: (context, d) {
          final events = (d['events'] as List?) ?? [];
          final leaders = (d['leaders'] as List?) ?? [];
          final units = (d['units'] as List?) ?? [];
          final social = Map<String, dynamic>.from((d['social'] as Map?) ?? {});
          final links = <(IconData, String, String)>[
            if (social['instagram'] != null) (Icons.camera_alt_outlined, 'Instagram', 'https://instagram.com/${social['instagram']}'),
            if (social['threads'] != null) (Icons.alternate_email, 'Threads', 'https://www.threads.net/@${social['threads']}'),
            if (social['facebook'] != null) (Icons.facebook, 'Facebook', '${social['facebook']}'),
            if (social['youtube'] != null) (Icons.smart_display_outlined, 'YouTube', '${social['youtube']}'),
            if (social['whatsapp_channel'] != null) (Icons.chat_outlined, 'WhatsApp', '${social['whatsapp_channel']}'),
            if (social['website'] != null) (Icons.language, 'Website', '${social['website']}'),
          ];
          final vision = (d['vision'] as List?) ?? [];
          final objectives = (d['objectives'] as List?) ?? [];
          final hadith = d['hadith'] as Map?;
          return [
            if (landing && notice != null) ...[SioBanner(text: notice), const SizedBox(height: 12)],
            _Hero(
              name: '${d['org_name'] ?? 'SIO'}',
              intro: '${d['intro'] ?? 'Students Islamic Organisation of India'}',
              canDonate: d['can_donate'] == true,
              landing: landing,
              donate: () => push(context, DonateScreen(minAmount: numOf(d['min_donation']), hadith: hadith)),
            ),
            if (events.isNotEmpty) ...[
              const SectionTitle('Upcoming programmes'),
              for (final e in events) ...[
                _PublicEvent(e: Map<String, dynamic>.from(e)),
                const SizedBox(height: 10),
              ],
            ],
            if ('${d['mission'] ?? ''}'.isNotEmpty) ...[
              const SectionTitle('Our mission'),
              _MissionCard(text: '${d['mission']}'),
            ],
            if (vision.isNotEmpty) ...[
              const SectionTitle('Our vision'),
              if ('${d['vision_intro'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text('${d['vision_intro']}', style: const TextStyle(fontSize: 15, height: 1.4)),
                ),
              for (var i = 0; i < vision.length; i++) ...[
                _Pillar(i: i, p: Map<String, dynamic>.from(vision[i])),
                const SizedBox(height: 10),
              ],
            ],
            if (objectives.isNotEmpty) ...[
              const SectionTitle('Our objectives'),
              PanelList(children: [
                for (var i = 0; i < objectives.length; i++) _Objective(n: i + 1, o: Map<String, dynamic>.from(objectives[i])),
              ]),
            ],
            if (leaders.isNotEmpty) ...[
              const SectionTitle('Area leaders'),
              for (final l in leaders) ...[
                _LeaderCard(l: Map<String, dynamic>.from(l)),
                const SizedBox(height: 10),
              ],
            ],
            const SectionTitle('Support our work'),
            _GiveCard(
              hadith: hadith,
              canDonate: d['can_donate'] == true,
              donate: () => push(context, DonateScreen(minAmount: numOf(d['min_donation']), hadith: hadith)),
            ),
            if (links.isNotEmpty) ...[
              const SectionTitle('Follow us'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final x in links) ActionChip(avatar: Icon(x.$1, size: 18), label: Text(x.$2), onPressed: () => _open(context, x.$3)),
              ]),
            ],
            if (events.isEmpty) ...[
              const SectionTitle('Upcoming programmes'),
              const EmptyNote('No public programmes announced right now. Check back soon.'),
            ],
            if (units.isNotEmpty) ...[
              const SectionTitle('Our units'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final u in units) Chip(avatar: const Icon(Icons.apartment_outlined, size: 18), label: Text('${u['name']}')),
              ]),
            ],
            const SizedBox(height: 20),
            const Text('Powered by Hipersign ERP',
                textAlign: TextAlign.center, style: TextStyle(color: SioColors.textSecondary, fontSize: 12)),
          ];
        },
      ),
    );
  }
}

const _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1A62A8), Color(0xFF3B3FB6), Color(0xFF6A2FB0)],
);

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.intro, required this.canDonate, required this.landing, required this.donate});
  final String name;
  final String intro;
  final bool canDonate;
  final bool landing;
  final VoidCallback donate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(gradient: _gradient, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Image(image: AssetImage('assets/sio-logo.png'), width: 72, height: 72),
          ),
        ),
        const SizedBox(height: 14),
        Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(intro, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (final m in const ['Study', 'Struggle', 'Service'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
              child: Text(m, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: SioColors.red, foregroundColor: Colors.white),
          onPressed: canDonate ? donate : null,
          icon: const Icon(Icons.volunteer_activism),
          label: Text(canDonate ? 'Donate to SIO' : 'Online donation coming soon'),
        ),
        if (landing) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
            onPressed: () => push(context, const RegisterScreen()),
            child: const Text('Join SIO: register as an associate'),
          ),
        ],
      ]),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: SioColors.card,
          borderRadius: BorderRadius.circular(18),
          border: const Border(left: BorderSide(color: SioColors.blue, width: 5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.format_quote, color: SioColors.blue, size: 32),
          Text(text, style: const TextStyle(fontSize: 17, height: 1.45, fontWeight: FontWeight.w600, color: SioColors.ink)),
        ]),
      );
}

class _Pillar extends StatelessWidget {
  const _Pillar({required this.i, required this.p});
  final int i;
  final Map<String, dynamic> p;

  static const _icons = [Icons.auto_stories, Icons.how_to_vote_outlined, Icons.lightbulb_outline, Icons.flag_outlined];
  static const _colors = [SioColors.blue, SioColors.purple, SioColors.red, SioColors.green];

  @override
  Widget build(BuildContext context) {
    final c = _colors[i % _colors.length];
    return SioPanel(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(_icons[i % _icons.length], color: c, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['title']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)),
            if ('${p['text']}'.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${p['text']}', style: const TextStyle(height: 1.4)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Objective extends StatelessWidget {
  const _Objective({required this.n, required this.o});
  final int n;
  final Map<String, dynamic> o;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: SioColors.blue,
            child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          title: Text('${o['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(64, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('${o['text']}', style: const TextStyle(height: 1.4))],
        ),
      );
}

class _GiveCard extends StatelessWidget {
  const _GiveCard({required this.hadith, required this.canDonate, required this.donate});
  final Map? hadith;
  final bool canDonate;
  final VoidCallback donate;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: SioColors.warningBg, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (hadith != null) ...[
            const Icon(Icons.format_quote, color: SioColors.warning, size: 30),
            Text('"${hadith!['text']}"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, height: 1.4, fontWeight: FontWeight.w700, color: SioColors.ink)),
            const SizedBox(height: 6),
            Text('${hadith!['source'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: SioColors.warning)),
            const SizedBox(height: 14),
          ],
          const Text('Your support funds student programmes, camps, relief and community service.',
              textAlign: TextAlign.center, style: TextStyle(height: 1.4)),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: SioColors.red),
            onPressed: canDonate ? donate : null,
            icon: const Icon(Icons.volunteer_activism),
            label: Text(canDonate ? 'Donate with UPI' : 'Online donation coming soon'),
          ),
        ]),
      );
}

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({required this.l});
  final Map<String, dynamic> l;

  @override
  Widget build(BuildContext context) {
    final phone = '${l['phone'] ?? ''}';
    final photo = '${l['photo'] ?? ''}';
    return SioPanel(
      child: Row(children: [
        photo.isNotEmpty
            ? CircleAvatar(radius: 28, backgroundImage: NetworkImage('${Api.baseUrl}$photo'))
            : Avatar('${l['leader_name']}', radius: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${l['leader_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SioColors.ink)),
            Text('${l['designation']}', style: const TextStyle(color: SioColors.textSecondary)),
          ]),
        ),
        if (phone.isNotEmpty) ...[
          IconButton.filledTonal(tooltip: 'Call', icon: const Icon(Icons.call), onPressed: () => callNumber(context, phone)),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: 'WhatsApp',
            icon: const Icon(Icons.chat_outlined),
            onPressed: () => whatsApp(context, phone, 'Assalamu alaikum ${l['leader_name']}, '),
          ),
        ],
      ]),
    );
  }
}

class _PublicEvent extends StatelessWidget {
  const _PublicEvent({required this.e});
  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final d = parseDate(e['starts_on']);
    return SioPanel(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (d != null)
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: SioColors.cardHigh, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(DateFormat('MMM').format(d).toUpperCase(),
                  style: const TextStyle(color: SioColors.red, fontWeight: FontWeight.w800, fontSize: 12)),
              Text('${d.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SioColors.ink)),
            const SizedBox(height: 2),
            Text(
              [if (d != null) DateFormat('EEE, h:mm a').format(d), e['venue'], e['unit']]
                  .where((x) => x != null && '$x'.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(color: SioColors.textSecondary, fontSize: 13),
            ),
            if ('${e['description'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${e['description']}', maxLines: 4, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// A visitor donates: details, then pay with any UPI app, then give the UPI reference so SIO can confirm it.
class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key, this.minAmount = 10, this.hadith});
  final num minAmount;
  final Map? hadith;

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _place = TextEditingController();
  final _amount = TextEditingController();
  final _utr = TextEditingController();
  Map<String, dynamic>? _donation; // after the donation is recorded
  bool _busy = false;
  bool _done = false;

  Future<void> _start() async {
    final amount = num.tryParse(_amount.text.trim()) ?? 0;
    if (amount < widget.minAmount) {
      toast(context, 'The smallest donation is ${inr(widget.minAmount)}.');
      return;
    }
    setState(() => _busy = true);
    try {
      final d = Map<String, dynamic>.from(await Api.guest('donate', {
        'full_name': _name.text.trim(),
        'mobile': _mobile.text.trim(),
        'place': _place.text.trim(),
        'amount': _amount.text.trim(),
      }) as Map);
      setState(() => _donation = d);
      await _openUpi();
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openUpi() async {
    final d = _donation!;
    final uri = Uri(scheme: 'upi', host: 'pay', queryParameters: {
      'pa': '${d['upi_id']}',
      'pn': '${d['payee']}',
      'am': numOf(d['amount']).toStringAsFixed(2),
      'cu': 'INR',
      'tn': '${d['note']}',
    });
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) {
      toast(context, 'No UPI app found. Pay ${inr(d['amount'])} to ${d['upi_id']} and enter the reference below.');
    }
  }

  Future<void> _paid() async {
    setState(() => _busy = true);
    try {
      await Api.guest('donation_paid', {'ref': _donation!['ref'], 'mobile': _mobile.text.trim(), 'payment_ref': _utr.text.trim()});
      setState(() => _done = true);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = _donation;
    return Scaffold(
      appBar: AppBar(title: const Text('Donate to SIO')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        if (_done) ...[
          const SizedBox(height: 40),
          const Icon(Icons.check_circle, size: 72, color: SioColors.green),
          const SizedBox(height: 16),
          const Text('Jazakallah khair!', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('SIO will confirm your donation of ${inr(d!['amount'])} once the payment is matched. Reference ${d['ref']}.',
              textAlign: TextAlign.center, style: const TextStyle(color: SioColors.textSecondary)),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ] else if (d == null) ...[
          if (widget.hadith != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: SioColors.warningBg, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text('"${widget.hadith!['text']}"',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SioColors.ink)),
                const SizedBox(height: 4),
                Text('${widget.hadith!['source'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: SioColors.warning, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Your name')),
          const SizedBox(height: 14),
          TextField(controller: _mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile')),
          const SizedBox(height: 14),
          TextField(controller: _place, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Place (optional)')),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final a in const [100, 500, 1000, 5000])
              ActionChip(label: Text(inr(a)), onPressed: () => setState(() => _amount.text = '$a')),
          ]),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Pay with UPI'),
          ),
          const SizedBox(height: 10),
          const Text('Opens GPay, PhonePe, Paytm or any UPI app with the amount filled in.',
              textAlign: TextAlign.center, style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5)),
        ] else ...[
          SioPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Pay ${inr(d['amount'])} to', style: const TextStyle(color: SioColors.textSecondary)),
              const SizedBox(height: 4),
              SelectableText('${d['upi_id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _openUpi, icon: const Icon(Icons.open_in_new), label: const Text('Open UPI app again')),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('After paying, enter the UPI reference (UTR / transaction ID) from your payment app.'),
          const SizedBox(height: 10),
          TextField(controller: _utr, decoration: const InputDecoration(labelText: 'UPI reference')),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _paid, child: const Text("I've paid")),
        ],
      ]),
    );
  }
}
