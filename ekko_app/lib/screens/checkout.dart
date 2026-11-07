import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/identifiers.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'tracker.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _name = TextEditingController();
  bool _accept = false;
  bool _paying = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _accept && _name.text.trim().length >= 3;

  Future<void> _place() async {
    final app = context.read<AppState>();
    setState(() => _paying = true);
    // Mock UPI collect: a real build would hand off to a UPI intent / PSP SDK.
    await Future.delayed(const Duration(milliseconds: 1600));
    final q = app.quote!;
    final g = app.profile!.gstin;
    final id = await Repository.placeOrder(
      userId: app.user!.id,
      profile: app.profile!,
      bundle: app.bundle!,
      quote: q,
      businessName: app.businessName ?? app.profile!.businessType,
      gstinMasked: g == null ? null : Gstin.mask(g),
      signedName: _name.text.trim(),
    );
    if (!mounted) return;
    app.resetJourney();
    await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => _PlacedScreen(orderId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final q = app.quote;
    if (q == null) return const Scaffold();
    final cat = app.data.catalogue;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('review_title'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (app.businessName != null)
          Text(app.businessName!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              for (final l in q.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text('${cat[l.productId].name} × ${l.qty}')),
                    Text(rupees(l.monthly), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              const Divider(height: 20),
              _row(context.t('monthly_total'), '${rupees(q.monthly)}${context.t('per_month')}', bold: true),
              _row('GST 18%', rupees(q.monthlyWithGst - q.monthly)),
              _row(context.t('setup_once'), rupees(q.setup)),
              _row(context.t('contract'), q.noLockIn ? context.t('no_lock_in') : context.t('months', {'n': q.contractMonths})),
              _row(context.t('install_eta', {'n': q.installDays}), ''),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: context.t('esign_name'), prefixIcon: const Icon(Icons.draw_outlined)),
        ),
        CheckboxListTile(
          value: _accept,
          onChanged: (v) => setState(() => _accept = v ?? false),
          activeColor: EkkoColors.red,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(context.t('esign_cb')),
        ),
        const SizedBox(height: 6),
        InfoBanner('${context.t('pay_title')} · demo payment, no money moves.', icon: Icons.account_balance_wallet_outlined),
      ]),
      bottomNavigationBar: BottomBar(children: [
        FilledButton(
          onPressed: _valid && !_paying ? _place : null,
          child: _paying
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  const SizedBox(width: 10),
                  Text(context.t('paying')),
                ])
              : Text(q.setup > 0 ? context.t('pay_now', {'amount': rupees(q.setupWithGst)}) : context.t('place_order')),
        ),
      ]),
    );
  }

  Widget _row(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
        ]),
      );
}

class _PlacedScreen extends StatelessWidget {
  final String orderId;
  const _PlacedScreen({required this.orderId});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: EkkoColors.greenSoft, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: EkkoColors.green, size: 56),
              ),
              const SizedBox(height: 24),
              Text(context.t('order_placed'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(context.t('order_id', {'id': orderId}), style: const TextStyle(color: EkkoColors.inkSoft, fontSize: 16)),
              const SizedBox(height: 16),
              InfoBanner(context.t('no_calls_needed'), icon: Icons.notifications_active_outlined),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => TrackerScreen(orderId: orderId))),
                child: Text(context.t('track_order')),
              ),
            ]),
          ),
        ),
      );
}
