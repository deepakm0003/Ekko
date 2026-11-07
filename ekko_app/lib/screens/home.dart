import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'advisor.dart';
import 'self_test.dart';
import 'tracker.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenOrders;
  const HomeScreen({super.key, required this.onOpenOrders});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Order>> _orders;
  int _version = -1;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final app = context.read<AppState>();
    _version = app.ordersVersion;
    _orders = Repository.orders(app.user!.id);
  }

  Future<void> _startAdvisor() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdvisorScreen()));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AppState>().ordersVersion != _version) _reload();
    return SafeArea(
      child: RefreshIndicator(
        color: EkkoColors.red,
        onRefresh: () async => setState(_reload),
        child: ListView(padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.md, Sp.xl, Sp.xxl), children: [
          const Row(children: [EkkoLogo(size: 32), Spacer(), ModeBadge()]),
          const Gap(Sp.xxl),
          Text('${context.t('hello')} 👋', style: T.display),
          const Gap(Sp.xs),
          Text('Let\'s get your business connected.', style: T.bodySoft),
          const Gap(Sp.xl),
          HeroPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 26),
                ),
                const Spacer(),
                Pill('हिं · தமிழ் · मराठी', color: Colors.white, bg: Colors.white.withValues(alpha: 0.18)),
              ]),
              const Gap(Sp.lg),
              Text(context.t('start_advisor_t'), style: T.h1.copyWith(color: Colors.white)),
              const Gap(6),
              Text(context.t('start_advisor_b'), style: T.body.copyWith(color: Colors.white.withValues(alpha: 0.85))),
              const Gap(Sp.xl),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: EkkoColors.red,
                    minimumSize: const Size(170, 50),
                  ),
                  onPressed: _startAdvisor,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(context.t('start')),
                    const Gap(Sp.sm),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ]),
                ),
              ),
            ]),
          ),
          const Gap(Sp.xl),
          Row(children: [
            Expanded(child: _Stat(icon: Icons.bolt_rounded, value: '10 min', label: 'to order')),
            const Gap(Sp.md),
            Expanded(child: _Stat(icon: Icons.receipt_long_rounded, value: '1 bill', label: 'all services')),
            const Gap(Sp.md),
            Expanded(child: _Stat(icon: Icons.phone_disabled_rounded, value: '0 calls', label: 'live tracking')),
          ]),
          SectionTitle(context.t('my_orders')),
          FutureBuilder<List<Order>>(
            future: _orders,
            builder: (context, snap) {
              final list = snap.data ?? const <Order>[];
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }
              if (list.isEmpty) {
                return EkkoCard(
                  child: Row(children: [
                    const IconBadge(Icons.inventory_2_rounded, color: EkkoColors.muted, bg: EkkoColors.canvas),
                    const Gap(Sp.md),
                    Expanded(child: Text(context.t('no_orders'), style: T.bodySoft)),
                  ]),
                );
              }
              return Column(children: [
                for (final o in list.take(3))
                  Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: OrderCard(order: o, onChanged: () => setState(_reload))),
              ]);
            },
          ),
          const SectionTitle('Why you can trust Ekko'),
          EkkoCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SelfTestScreen())),
            child: Row(children: [
              const IconBadge(Icons.fact_check_rounded, color: EkkoColors.green, bg: EkkoColors.greenSoft, size: 46),
              const Gap(Sp.md),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Never sells the wrong plan', style: T.h3),
                  Gap(2),
                  Text('Every plan is checked against all catalogue rules. Tap to run the live self-test.', style: T.small),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: EkkoColors.muted),
            ]),
          ),
          const Gap(Sp.md),
          TrustRow(Icons.enhanced_encryption_rounded, context.t('trust_2')),
          TrustRow(Icons.track_changes_rounded, context.t('trust_3')),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => EkkoCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: EkkoColors.red, size: 22),
          const Gap(Sp.sm),
          Text(value, style: T.h3.copyWith(fontSize: 15.5)),
          Text(label, style: T.small.copyWith(fontSize: 11.5)),
        ]),
      );
}
