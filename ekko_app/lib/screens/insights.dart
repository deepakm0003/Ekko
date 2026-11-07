import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Results computed from the case data (smb_leads.csv, Apr–Jun 2026):
/// why the current journey leaks, and the targets Ekko is built to hit.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AppState>().data.insights;
    final funnel = (d['funnel'] as List).cast<Map<String, dynamic>>();
    final segments = (d['segments'] as List).cast<Map<String, dynamic>>();
    final drops = (d['dropGroups'] as List).cast<Map<String, dynamic>>();
    final chase = (d['chaseVsChurn'] as List).cast<Map<String, dynamic>>();
    final sources = (d['sources'] as List).cast<Map<String, dynamic>>();
    final langs = (d['languages'] as List).cast<Map<String, dynamic>>();
    final prop = d['propensity'] as Map<String, dynamic>;
    final targets = (d['targets'] as List).cast<Map<String, dynamic>>();
    final total = d['totalLeads'] as int;
    final dropTotal = drops.fold<int>(0, (s, g) => s + (g['count'] as int));

    return Scaffold(
      appBar: AppBar(title: Text(context.t('nav_insights'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        Text('From ${d['totalLeads']} SMB leads · ${d['period']} (case data)',
            style: const TextStyle(color: EkkoColors.inkSoft)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: [
            _Kpi('${(d['activated'] / total * 100).toStringAsFixed(1)}%', 'lead → activation'),
            _Kpi('${d['avgDays']} days', 'lead to activation'),
            _Kpi(rupees(d['blendedCac']), 'cost per activation'),
            _Kpi('${d['avgChases']}×', 'status calls per customer'),
          ],
        ),
        const SectionTitle('Funnel — where leads are lost'),
        for (var i = 0; i < funnel.length; i++)
          _Bar(
            label: funnel[i]['stage'],
            value: (funnel[i]['count'] as int) / total,
            text: '${funnel[i]['count']}'
                '${i == 0 ? '' : ' · ${((funnel[i]['count'] as int) / (funnel[i - 1]['count'] as int) * 100).round()}%'}',
            highlight: funnel[i]['stage'] == 'Quote accepted',
          ),
        const InfoBanner('Biggest leak: only 44% of assessed leads accept the quote. Ekko gives one clear price instantly.',
            icon: Icons.lightbulb_outline, color: EkkoColors.redDark, bg: EkkoColors.redSoft),
        const SectionTitle('Why leads drop'),
        for (final g in drops)
          _Bar(label: g['group'], value: (g['count'] as int) / dropTotal, text: '${g['count']}'),
        InfoBanner(
          '${d['soldNotAsked']} of ${d['activated']} customers bought none of the products they asked about; '
          '${d['ineligibleSold']} were sold bundles that break catalogue rules '
          '(${d['cancelledGstinActivated']} on a cancelled GSTIN). Ekko\'s rules engine prevents both.',
          icon: Icons.rule,
        ),
        const SectionTitle('Segments — who to target first'),
        _SegmentTable(rows: segments),
        const SizedBox(height: 8),
        const InfoBanner('Micro retail takes 8+ months to pay back at today\'s cost — only viable fully digital. '
            'Professional offices pay back in under 2 months: wave 1.', icon: Icons.flag_outlined),
        const SectionTitle('Status calls drive churn'),
        for (final c in chase)
          _Bar(
            label: '${c['calls']} call${c['calls'] == 1 ? '' : 's'} (n=${c['n']})',
            value: (c['churn'] as num) / 30,
            text: '${c['churn']}% churn · NPS ${c['nps']}',
            highlight: (c['churn'] as num) >= 20,
          ),
        const InfoBanner('Customers who chased 5 times churned at 28% vs 6% for one call. The live tracker removes the reason to call.',
            icon: Icons.track_changes),
        const SectionTitle('Channels'),
        for (final s in sources)
          _Bar(
            label: s['source'],
            value: (s['activation'] as num) / 16,
            text: '${s['activation']}% · CAC ${rupees(s['cac'])}',
          ),
        const SectionTitle('Language gap'),
        for (final l in langs)
          _Bar(label: l['language'], value: (l['activation'] as num) / 10, text: '${l['activation']}% (${l['leads']})'),
        SectionTitle('Who to call — propensity model (AUC ${prop['auc']})'),
        SizedBox(
          height: 170,
          child: BarChart(BarChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Text('D${v.toInt() + 1}', style: const TextStyle(fontSize: 10)),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < (prop['deciles'] as List).length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: ((prop['deciles'] as List)[i] as num).toDouble(),
                    color: i >= 7 ? EkkoColors.red : EkkoColors.line,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ]),
            ],
          )),
        ),
        InfoBanner('Calling the top 30% of leads (red) reaches ${prop['top30Share']}% of all activations.',
            icon: Icons.call_outlined),
        const SectionTitle('Ekko targets'),
        Card(
          child: Column(children: [
            for (final t in targets)
              ListTile(
                dense: true,
                title: Text(t['metric'], style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text('${t['today']}  →  ${t['target']}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: EkkoColors.red)),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String value;
  final String label;
  const _Kpi(this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: EkkoColors.redSoft, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          FittedBox(
            child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: EkkoColors.red)),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: EkkoColors.ink)),
        ]),
      );
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final String text;
  final bool highlight;
  const _Bar({required this.label, required this.value, required this.text, this.highlight = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: highlight ? FontWeight.w800 : FontWeight.w500)),
            ),
            Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 10,
              color: highlight ? EkkoColors.red : EkkoColors.ink,
              backgroundColor: EkkoColors.surface,
            ),
          ),
        ]),
      );
}

class _SegmentTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _SegmentTable({required this.rows});
  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 11, color: EkkoColors.inkSoft, fontWeight: FontWeight.w700);
    const cell = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(2.2)},
          children: [
            const TableRow(children: [
              Text('Segment', style: head), Text('Activ.', style: head), Text('ARPU', style: head),
              Text('Churn', style: head), Text('Payback', style: head),
            ]),
            for (final r in rows)
              TableRow(children: [
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(r['segment'], style: cell)),
                Padding(padding: const EdgeInsets.only(top: 8), child: Text('${r['activation']}%', style: cell)),
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(rupees(r['arpu']), style: cell)),
                Padding(padding: const EdgeInsets.only(top: 8), child: Text('${r['churn']}%', style: cell)),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${r['payback']} mo',
                      style: cell.copyWith(color: (r['payback'] as num) > 3 ? EkkoColors.redDark : EkkoColors.green)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
