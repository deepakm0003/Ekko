import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/self_test.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Runs the advisor edge cases live on the phone so anyone (judges included)
/// can see the rules engine reject ineligible products.
class SelfTestScreen extends StatefulWidget {
  const SelfTestScreen({super.key});
  @override
  State<SelfTestScreen> createState() => _SelfTestScreenState();
}

class _SelfTestScreenState extends State<SelfTestScreen> {
  final _results = <SelfTestResult>[];
  (int, int)? _sweep;
  bool _running = false;

  Future<void> _run() async {
    final runner = SelfTestRunner(context.read<AppState>().data.catalogue);
    setState(() {
      _running = true;
      _results.clear();
      _sweep = null;
    });
    for (final t in selfTests) {
      await Future.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;
      setState(() => _results.add(runner.run(t)));
    }
    await Future.delayed(const Duration(milliseconds: 200));
    final s = runner.sweep();
    if (mounted) {
      setState(() {
        _sweep = s;
        _running = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  Widget build(BuildContext context) {
    final passed = _results.where((r) => r.passed).length;
    final cat = context.read<AppState>().data.catalogue;
    return Scaffold(
      appBar: AppBar(title: const Text('Rules self-test')),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xxl), children: [
        InkPanel(
          child: Row(children: [
            ScoreRing(score: selfTests.isEmpty ? 0 : (passed * 100 / selfTests.length).round(), size: 96, caption: 'PASS %'),
            const Gap(Sp.xl),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$passed / ${selfTests.length} scenarios', style: T.h2.copyWith(color: Colors.white)),
                const Gap(4),
                Text(
                  _sweep == null
                      ? 'Running on this phone…'
                      : '${_sweep!.$1} random profiles · ${_sweep!.$2} rule violations',
                  style: T.bodySoft.copyWith(color: Colors.white70),
                ),
                const Gap(8),
                Text('The AI only talks. Eligibility & prices come from these rules.',
                    style: T.small.copyWith(color: Colors.white54)),
              ]),
            ),
          ]),
        ),
        const SectionTitle('Edge cases from the catalogue', subtitle: 'Tier, GSTIN status, size, sites, dependencies, feasibility, budget'),
        for (final r in _results)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.sm + 2),
            child: EkkoCard(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(r.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: r.passed ? EkkoColors.green : EkkoColors.redDark, size: 24),
                const Gap(Sp.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.test.title, style: T.h3.copyWith(fontSize: 14.5)),
                    const Gap(2),
                    Text(r.test.expect, style: T.small),
                    const Gap(6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final p in r.products)
                        Pill(cat[p].name, color: EkkoColors.inkSoft, bg: EkkoColors.canvas),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        if (!_running) ...[
          const Gap(Sp.md),
          OutlinedButton.icon(onPressed: _run, icon: const Icon(Icons.replay_rounded), label: const Text('Run again')),
        ],
      ]),
    );
  }
}
