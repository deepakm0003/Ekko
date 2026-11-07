import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/profile.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// One row in the partner cockpit: a dataset lead or a lead from the app.
class _Lead {
  final String id;
  final String name;
  final String type;
  final Segment segment;
  final String city;
  final int tier;
  final String lang;
  final int employees;
  final int sites;
  final String source;
  final String stage;
  final String? drop;
  final int spend;
  final GstStatus gst;
  final bool udyam;
  final String internet;
  final List<String> interest;
  final String contact;
  final double score;
  final List<String> why;
  final bool fromApp;
  const _Lead(this.id, this.name, this.type, this.segment, this.city, this.tier, this.lang, this.employees, this.sites,
      this.source, this.stage, this.drop, this.spend, this.gst, this.udyam, this.internet, this.interest, this.contact,
      this.score, this.why, this.fromApp);

  BusinessProfile toProfile() => BusinessProfile(
        businessType: type,
        segment: segment,
        employees: employees,
        sites: sites,
        cityTier: tier,
        city: city,
        gstStatus: gst,
        hasUdyam: udyam,
        currentInternet: internet,
        currentMonthlySpend: spend,
      );
}

GstStatus _gst(String? s) => switch (s) {
      'Active' => GstStatus.active,
      'Cancelled' => GstStatus.cancelled,
      'Suspended' => GstStatus.suspended,
      _ => GstStatus.none,
    };

class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});
  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  List<_Lead>? _leads;
  Set<String> _contacted = {};
  Segment? _seg;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final appRows = await Repository.appLeads();
    final contacted = await Repository.contactedIds();
    final list = <_Lead>[
      for (final r in appRows)
        () {
          final p = BusinessProfile.fromJson(jsonDecode(r['profile'] as String));
          return _Lead(r['id'] as String, p.businessType.isEmpty ? 'New business' : p.businessType, p.businessType,
              p.segment, p.city, p.cityTier, p.language, p.employees, p.sites, 'Ekko app', r['stage'] as String,
              r['reason'] as String?, p.currentMonthlySpend, p.gstStatus, p.hasUdyam, p.currentInternet,
              const [], '—', (r['score'] as num).toDouble(), ['Started in Ekko app', 'Asked: ${r['reason']}'], true);
        }(),
      for (final j in app.data.cockpitLeads)
        _Lead(j['id'], j['name'], j['type'], Segment.values.byName(j['segment']), j['city'], j['tier'], j['lang'],
            j['employees'], j['sites'], j['source'], j['stage'], j['drop'], j['spend'], _gst(j['gst']),
            j['udyam'] == true, j['internet'] ?? '', List<String>.from(j['interest']), j['contact'],
            (j['score'] as num).toDouble(), List<String>.from(j['why']), false),
    ]..sort((a, b) => b.score.compareTo(a.score));
    if (mounted) {
      setState(() {
        _leads = list;
        _contacted = contacted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = _leads;
    if (all == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final q = _q.toLowerCase();
    final shown = all
        .where((l) => _seg == null || l.segment == _seg)
        .where((l) => q.isEmpty || l.name.toLowerCase().contains(q) || l.city.toLowerCase().contains(q))
        .toList();
    final auc = (app.data.insights['propensity']['auc'] as num).toStringAsFixed(2);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('leads_title'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t('leads_sub', {'auc': auc}), style: const TextStyle(color: EkkoColors.inkSoft)),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name or city'),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final s in <Segment?>[null, ...Segment.values])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s == null ? context.t('all') : _segLabel(s)),
                          selected: _seg == s,
                          onSelected: (_) => setState(() => _seg = s),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
                Text('${shown.length} leads · ${_contacted.length} contacted',
                    style: const TextStyle(fontSize: 12, color: EkkoColors.inkSoft)),
              ]),
            ),
          ),
          SliverList.builder(
            itemCount: shown.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _LeadCard(
                lead: shown[i],
                contacted: _contacted.contains(shown[i].id),
                onTap: () => _open(shown[i]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _open(_Lead l) async {
    final app = context.read<AppState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LeadDetail(
        lead: l,
        app: app,
        contacted: _contacted.contains(l.id),
        onContacted: () async {
          await Repository.markContacted(l.id, app.user!.id);
          setState(() => _contacted.add(l.id));
        },
      ),
    );
  }
}

String _segLabel(Segment s) => const {
      Segment.micro: 'Micro retail',
      Segment.prof: 'Professional',
      Segment.multi: 'Multi-site',
      Segment.mfg: 'Manufacturer',
    }[s]!;

class _LeadCard extends StatelessWidget {
  final _Lead lead;
  final bool contacted;
  final VoidCallback onTap;
  const _LeadCard({required this.lead, required this.contacted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = (lead.score * 100).round();
    final hot = lead.score >= 0.15;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Pill('$pct%',
                  icon: Icons.local_fire_department,
                  color: hot ? EkkoColors.red : EkkoColors.inkSoft,
                  bg: hot ? EkkoColors.redSoft : EkkoColors.surface),
            ]),
            const SizedBox(height: 4),
            Text('${lead.type} · ${lead.city} · ${lead.employees} staff · ${lead.source}',
                style: const TextStyle(color: EkkoColors.inkSoft, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (lead.fromApp) Pill(context.t('in_app'), color: EkkoColors.green, bg: EkkoColors.greenSoft),
              if (contacted) Pill(context.t('contacted'), color: EkkoColors.green, bg: EkkoColors.greenSoft, icon: Icons.check),
              for (final w in lead.why) Pill(w, color: EkkoColors.ink, bg: EkkoColors.surface),
            ]),
            if (lead.drop != null && !lead.fromApp) ...[
              const SizedBox(height: 6),
              Text('Dropped at ${lead.stage}: ${lead.drop}',
                  style: const TextStyle(fontSize: 12, color: EkkoColors.amber)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _LeadDetail extends StatelessWidget {
  final _Lead lead;
  final AppState app;
  final bool contacted;
  final Future<void> Function() onContacted;
  const _LeadDetail({required this.lead, required this.app, required this.contacted, required this.onContacted});

  @override
  Widget build(BuildContext context) {
    final cat = app.data.catalogue;
    final profile = lead.toProfile();
    final bundle = app.data.recommender.recommend(profile);
    final quote = app.pricing.quote(bundle);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (_, controller) => ListView(controller: controller, padding: const EdgeInsets.all(16), children: [
        Text(lead.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text('${lead.id} · ${lead.type} · ${lead.city} (tier ${lead.tier}) · ${lead.lang}',
            style: const TextStyle(color: EkkoColors.inkSoft)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill('Score ${(lead.score * 100).round()}%', icon: Icons.local_fire_department),
          Pill('${lead.employees} staff · ${lead.sites} site(s)', color: EkkoColors.ink, bg: EkkoColors.surface),
          Pill('GST: ${lead.gst.name}', color: EkkoColors.ink, bg: EkkoColors.surface),
          if (lead.spend > 0) Pill('Spends ${rupees(lead.spend)}/mo', color: EkkoColors.ink, bg: EkkoColors.surface),
        ]),
        SectionTitle(context.t('why_call')),
        for (final w in lead.why) TrustRow(Icons.check, w),
        if (lead.interest.isNotEmpty) ...[
          const SectionTitle('Asked about'),
          Text(lead.interest.map((p) => cat[p].name).join(', ')),
        ],
        SectionTitle(context.t('suggested_bundle')),
        for (final i in bundle.active)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• ${cat[i.productId].name} × ${i.qty}')),
        const SizedBox(height: 6),
        Text('${rupees(quote.monthly)}/month · setup ${rupees(quote.setup)} · ${quote.noLockIn ? 'no lock-in' : '${quote.contractMonths} months'}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        if (bundle.notices.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${bundle.notices.length} rule adjustment(s) applied automatically',
              style: const TextStyle(fontSize: 12, color: EkkoColors.inkSoft)),
        ],
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.toast('Calling ${lead.contact} (demo — number masked)'),
              icon: const Icon(Icons.call),
              label: Text(context.t('call')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: contacted
                  ? null
                  : () async {
                      await onContacted();
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text(contacted ? context.t('contacted') : context.t('mark_contacted')),
            ),
          ),
        ]),
      ]),
    );
  }
}
