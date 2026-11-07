import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'advisor.dart';
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
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          Row(children: [
            const EkkoLogo(size: 32),
            const Spacer(),
            const ModeBadge(),
          ]),
          const SizedBox(height: 24),
          Text(context.t('hello'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _AdvisorCard(onStart: _startAdvisor),
          const SizedBox(height: 16),
          TrustRow(Icons.rule, context.t('trust_1')),
          TrustRow(Icons.enhanced_encryption_outlined, context.t('trust_2')),
          TrustRow(Icons.track_changes, context.t('trust_3')),
          SectionTitle(context.t('my_orders')),
          FutureBuilder<List<Order>>(
            future: _orders,
            builder: (context, snap) {
              final list = snap.data ?? const <Order>[];
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }
              if (list.isEmpty) return InfoBanner(context.t('no_orders'), icon: Icons.inbox_outlined);
              return Column(children: [
                for (final o in list.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OrderCard(order: o, onChanged: () => setState(_reload)),
                  ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

class _AdvisorCard extends StatelessWidget {
  final VoidCallback onStart;
  const _AdvisorCard({required this.onStart});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [EkkoColors.red, EkkoColors.redDark]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.support_agent, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(context.t('start_advisor_t'),
              style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 6),
          Text(context.t('start_advisor_b'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: EkkoColors.red,
                minimumSize: const Size(140, 46),
              ),
              onPressed: onStart,
              child: Text(context.t('start')),
            ),
          ),
        ]),
      );
}
