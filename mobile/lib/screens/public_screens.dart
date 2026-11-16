import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

/// For anyone, without signing in: what SIO is, upcoming public programmes, and a way to donate.
class PublicScreen extends StatelessWidget {
  const PublicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About SIO')),
      body: Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await Api.guest('info') as Map),
        builder: (context, d) {
          final events = (d['events'] as List?) ?? [];
          return [
            SioPanel(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: Image(image: AssetImage('assets/sio-logo.png'), width: 72, height: 72)),
                const SizedBox(height: 12),
                Text('${d['intro'] ?? 'Students Islamic Organisation of India'}',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: SioColors.red),
                  onPressed: d['can_donate'] == true
                      ? () => push(context, DonateScreen(minAmount: numOf(d['min_donation'])))
                      : null,
                  icon: const Icon(Icons.volunteer_activism),
                  label: Text(d['can_donate'] == true ? 'Donate to SIO' : 'Online donation coming soon'),
                ),
              ]),
            ),
            const SectionTitle('Upcoming programmes'),
            if (events.isEmpty) const EmptyNote('No public programmes announced right now. Check back soon.'),
            for (final e in events) ...[
              _PublicEvent(e: Map<String, dynamic>.from(e)),
              const SizedBox(height: 10),
            ],
          ];
        },
      ),
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
  const DonateScreen({super.key, this.minAmount = 10});
  final num minAmount;

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
