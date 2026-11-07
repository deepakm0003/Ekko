import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'account.dart';
import 'home.dart';
import 'insights.dart';
import 'partner.dart';
import 'tracker.dart';

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});
  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenOrders: () => setState(() => _i = 1)),
      const OrdersScreen(),
      const InsightsScreen(),
      const AccountScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: context.t('nav_home')),
          NavigationDestination(icon: const Icon(Icons.local_shipping_outlined), selectedIcon: const Icon(Icons.local_shipping), label: context.t('nav_orders')),
          NavigationDestination(icon: const Icon(Icons.insights_outlined), selectedIcon: const Icon(Icons.insights), label: context.t('nav_insights')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: context.t('nav_account')),
        ],
      ),
    );
  }
}

class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key});
  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    const pages = [PartnerScreen(), InsightsScreen(), AccountScreen()];
    return Scaffold(
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.call_outlined), selectedIcon: const Icon(Icons.call), label: context.t('nav_leads')),
          NavigationDestination(icon: const Icon(Icons.insights_outlined), selectedIcon: const Icon(Icons.insights), label: context.t('nav_insights')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: context.t('nav_account')),
        ],
      ),
    );
  }
}
