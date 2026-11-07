import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../engine/bundle.dart';
import '../engine/catalogue.dart';
import '../engine/eligibility.dart';
import '../engine/health.dart';
import '../engine/pricing.dart';
import '../l10n/strings.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'consent.dart';

/// Human sentence for an eligibility notice.
String noticeText(S s, Catalogue cat, Notice n) {
  final name = cat[n.productId].name;
  switch (n.kind) {
    case NoticeKind.substituted:
    case NoticeKind.blocked:
      final why = switch (n.block) {
        Block.tier => s.t('block_tier', {'product': name}),
        Block.gstin => s.t('block_gstin', {'product': name}),
        Block.employees => s.t('block_employees', {'product': name, 'n': cat[n.productId].minEmployees}),
        Block.sites => s.t('block_sites', {'product': name, 'n': cat[n.productId].minSites}),
        Block.feasibility => s.t('block_feasibility', {'product': name}),
        _ => s.t('block_dependency', {'product': name}),
      };
      if (n.kind == NoticeKind.blocked) return why;
      return '$why ${s.t('substituted', {'from': name, 'to': n.alternatives.map((a) => cat[a].name).join(' + ')})}';
    case NoticeKind.autoAdded:
      return s.t('auto_added', {'product': name, 'needed': n.alternatives.map((a) => cat[a].name).join(', ')});
    case NoticeKind.upgradePath:
      return s.t('upgrade_gst', {'product': name});
    case NoticeKind.trimmed:
      return s.t('trimmed', {'product': name});
  }
}

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  String? _aiExplanation;
  bool _explaining = false;

  @override
  void initState() {
    super.initState();
    _explain();
  }

  Future<void> _explain() async {
    final app = context.read<AppState>();
    if (!app.backend.online) return;
    setState(() => _explaining = true);
    final cat = app.data.catalogue;
    final q = app.quote!;
    final text = await app.backend.explain(
      language: app.lang,
      profile: app.profile!.toJson(),
      items: [
        for (final i in app.bundle!.active)
          {'name': cat[i.productId].name, 'qty': i.qty, 'description': cat[i.productId].description}
      ],
      monthly: q.monthly,
      notices: app.bundle!.notices.map((n) => noticeText(app.s, cat, n)).toList(),
    );
    if (mounted) {
      setState(() {
        _aiExplanation = text;
        _explaining = false;
      });
    }
  }

  void _changed() {
    final app = context.read<AppState>();
    app.data.recommender.revalidate(app.bundle!, app.profile!);
    app.touch();
  }

  Future<void> _addProduct() async {
    final app = context.read<AppState>();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddProductSheet(app: app),
    );
    if (picked == null) return;
    final b = app.bundle!;
    final existing = b.item(picked);
    if (existing != null) {
      existing.enabled = true;
    } else {
      b.items.add(LineItem(picked, 1, origin: Origin.user));
    }
    _changed();
  }

  Future<void> _callback() async {
    final app = context.read<AppState>();
    await Repository.saveLead(
        userId: app.user?.id, profile: app.profile!, model: app.data.propensity, stage: 'plan', reason: 'callback');
    if (mounted) context.toast(app.s.t('callback_requested'));
  }

  /// Owners often decide with family or a partner: share the plan as text.
  Future<void> _share() async {
    final app = context.read<AppState>();
    final cat = app.data.catalogue;
    final q = app.quote!;
    final lines = [
      'My Ekko business plan (${app.profile!.businessType})',
      for (final l in q.lines) '• ${cat[l.productId].name} × ${l.qty} — ${rupees(l.monthly)}/mo',
      'Total: ${rupees(q.monthly)}/month + GST · setup ${rupees(q.setup)} · '
          '${q.noLockIn ? 'no lock-in' : '${q.contractMonths} months'}',
      'Ready in about ${q.installDays} days. Get yours on the Ekko app.',
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n'), subject: 'My Ekko plan'));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.profile == null || app.bundle == null) return const Scaffold();
    final p = app.profile!;
    final b = app.bundle!;
    final cat = app.data.catalogue;
    final q = app.quote!;
    final options = app.pricing.contractOptions(b);
    final saving = app.pricing.longTermSaving(b);
    final core = b.items.where((i) => !i.optional).toList();
    final addons = b.items.where((i) => i.optional).toList();
    final notices = b.notices.toList();
    final health = digitalHealth(p, b);
    final vendors = vendorsReplaced(b, (id) => cat[id].category);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('rec_title')),
        actions: [
          IconButton(onPressed: _share, tooltip: 'Share plan', icon: const Icon(Icons.ios_share_rounded)),
          const Gap(Sp.sm),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xxl), children: [
        Text(context.t('rec_sub', {'type': p.businessType, 'emp': p.employees, 'sites': p.sites}), style: T.bodySoft),
        const Gap(Sp.lg),
        _PriceCard(quote: q, options: options, saving: saving, catalogue: cat, profileSpend: p.currentMonthlySpend,
            onContract: (m) {
          app.contractMonths = m;
          app.touch();
        }),
        const Gap(Sp.lg),
        _HealthCard(report: health),
        const Gap(Sp.md),
        EkkoCard(
          child: Row(children: [
            const IconBadge(Icons.receipt_long_rounded, color: EkkoColors.blue, bg: EkkoColors.blueSoft, size: 44),
            const Gap(Sp.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Replaces $vendors vendor${vendors == 1 ? '' : 's'}', style: T.h3),
                const Gap(2),
                const Text('One bill, one support number, one app to track it all.', style: T.small),
              ]),
            ),
          ]),
        ),
        if (_explaining || _aiExplanation != null) ...[
          const Gap(Sp.md),
          EkkoCard(
            color: EkkoColors.greenSoft,
            child: _explaining
                ? const LinearProgressIndicator(color: EkkoColors.green)
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.auto_awesome_rounded, color: EkkoColors.green, size: 20),
                    const Gap(Sp.md),
                    Expanded(child: Text(_aiExplanation!, style: T.body)),
                  ]),
          ),
        ],
        SectionTitle(context.t('included'), subtitle: 'Needed for your plan to work'),
        for (final i in core) _ItemTile(item: i, product: cat[i.productId], onChanged: _changed),
        if (addons.isNotEmpty) ...[
          SectionTitle(context.t('addons'), subtitle: 'Picked from what you told me — switch any off'),
          for (final i in addons) _ItemTile(item: i, product: cat[i.productId], onChanged: _changed),
        ],
        const Gap(Sp.sm),
        OutlinedButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add_rounded), label: const Text('Add a product')),
        if (notices.isNotEmpty) ...[
          SectionTitle(context.t('cant_offer'), subtitle: 'Checked against the catalogue rules'),
          for (final n in notices)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.sm),
              child: InfoBanner(
                noticeText(app.s, cat, n),
                icon: switch (n.kind) {
                  NoticeKind.upgradePath => Icons.trending_up_rounded,
                  NoticeKind.autoAdded => Icons.add_link_rounded,
                  NoticeKind.trimmed => Icons.savings_rounded,
                  _ => Icons.block_rounded,
                },
                color: n.kind == NoticeKind.upgradePath ? EkkoColors.green : EkkoColors.amber,
                bg: n.kind == NoticeKind.upgradePath ? EkkoColors.greenSoft : EkkoColors.amberSoft,
              ),
            ),
        ],
      ]),
      bottomNavigationBar: BottomBar(children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(rupees(q.monthly), style: T.h1.copyWith(fontSize: 22)),
              Text('${context.t('per_month')} · ${q.noLockIn ? context.t('no_lock_in') : context.t('months', {'n': q.contractMonths})}',
                  style: T.small),
            ]),
          ),
          SizedBox(
            width: 190,
            child: FilledButton(
              onPressed: b.active.isEmpty
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsentScreen())),
              child: Text(context.t('continue_kyc'), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ]),
        TextButton.icon(
          onPressed: _callback,
          icon: const Icon(Icons.headset_mic_rounded, size: 18, color: EkkoColors.inkSoft),
          label: Text(context.t('talk_human'), style: const TextStyle(color: EkkoColors.inkSoft)),
        ),
      ]),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final HealthReport report;
  const _HealthCard({required this.report});
  @override
  Widget build(BuildContext context) => EkkoCard(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ScoreRing(score: report.after, before: report.before, size: 92, caption: 'SCORE'),
            const Gap(Sp.xl),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Digital Health Score', style: T.label.copyWith(color: EkkoColors.red)),
                const Gap(4),
                Text('${report.before} → ${report.after}', style: T.h1),
                const Gap(2),
                Text('How ready your business is today vs with this plan', style: T.small),
              ]),
            ),
          ]),
          const Gap(Sp.lg),
          for (final p in report.pillars)
            MeterBar(label: p.label, value: p.after / 100, before: p.before / 100, trailing: '${p.before} → ${p.after}'),
        ]),
      );
}

class _PriceCard extends StatelessWidget {
  final Quote quote;
  final List<int> options;
  final int saving;
  final Catalogue catalogue;
  final int profileSpend;
  final ValueChanged<int> onContract;
  const _PriceCard({
    required this.quote,
    required this.options,
    required this.saving,
    required this.catalogue,
    required this.profileSpend,
    required this.onContract,
  });

  @override
  Widget build(BuildContext context) {
    final q = quote;
    const w = TextStyle(fontFamily: 'Jakarta', color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600);
    return InkPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(context.t('monthly_total').toUpperCase(), style: T.label.copyWith(color: Colors.white60)),
          const Spacer(),
          Pill(context.t('install_eta', {'n': q.installDays}), icon: Icons.bolt_rounded, color: Colors.white, bg: Colors.white.withValues(alpha: 0.14)),
        ]),
        const Gap(Sp.md),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: q.monthly.toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(rupees(v), style: T.money),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 5, left: 6),
            child: Text(context.t('per_month'), style: w.copyWith(color: Colors.white60, fontSize: 16)),
          ),
        ]),
        const Gap(6),
        Text(context.t('excl_gst', {'amount': rupees(q.monthlyWithGst)}), style: T.small.copyWith(color: Colors.white54)),
        const Gap(Sp.lg),
        Container(height: 1, color: Colors.white12),
        const Gap(Sp.md),
        KV(context.t('setup_once'), q.setup == 0 ? '₹0' : rupees(q.setup), color: Colors.white),
        KV(context.t('contract'), q.noLockIn ? context.t('no_lock_in') : context.t('months', {'n': q.contractMonths}), color: Colors.white),
        if (q.contractDrivenBy != null && q.contractMonths > 12 && catalogue[q.contractDrivenBy!].minContract == q.contractMonths)
          Text(context.t('contract_reason', {'product': catalogue[q.contractDrivenBy!].name, 'n': q.contractMonths}),
              style: T.small.copyWith(color: Colors.white54)),
        if (profileSpend > 0) KV(context.t('vs_today', {'amount': rupees(profileSpend)}), '', color: Colors.white),
        if (options.length > 1) ...[
          const Gap(Sp.md),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              for (final m in options)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onContract(m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: q.contractMonths == m ? EkkoColors.red : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m <= 1 ? context.t('no_lock_in') : context.t('months', {'n': m}),
                          textAlign: TextAlign.center, style: w.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
            ]),
          ),
          if (saving > 0 && q.contractMonths < 24)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                const Icon(Icons.savings_rounded, color: Color(0xFF7CE495), size: 18),
                const Gap(6),
                Text(context.t('save_24', {'amount': rupees(saving)}),
                    style: w.copyWith(color: const Color(0xFF7CE495), fontWeight: FontWeight.w800)),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _ItemTile extends StatefulWidget {
  final LineItem item;
  final Product product;
  final VoidCallback onChanged;
  const _ItemTile({required this.item, required this.product, required this.onChanged});
  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i = widget.item;
    final p = widget.product;
    final unit = (app.contractMonths ?? 0) >= 24 ? p.longTermPrice : p.listPrice;
    final on = i.enabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: on ? 1 : 0.55,
        child: EkkoCard(
          onTap: () => setState(() => _open = !_open),
          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.md, Sp.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(productIcon(p.id), size: 42, color: on ? EkkoColors.red : EkkoColors.muted, bg: on ? EkkoColors.redSoft : EkkoColors.canvas),
              const Gap(Sp.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(p.name, style: T.h3.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
                    if (i.origin == Origin.dependency || i.origin == Origin.substitute) ...[
                      const Gap(6),
                      Pill(i.origin == Origin.dependency ? 'required' : 'alternative', color: EkkoColors.amber, bg: EkkoColors.amberSoft),
                    ],
                  ]),
                  const Gap(2),
                  Text('${rupees(unit)} ${p.unit}', style: T.small),
                ]),
              ),
              if (i.optional)
                Switch(
                  value: i.enabled,
                  onChanged: (v) {
                    i.enabled = v;
                    widget.onChanged();
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(rupees(unit * i.qty), style: T.h3),
                ),
            ]),
            if (on) ...[
              const Gap(Sp.sm),
              Row(children: [
                const Gap(54),
                _Stepper(
                  qty: i.qty,
                  onMinus: i.qty > 1
                      ? () {
                          i.qty--;
                          widget.onChanged();
                        }
                      : null,
                  onPlus: i.qty < 50
                      ? () {
                          i.qty++;
                          widget.onChanged();
                        }
                      : null,
                ),
                const Spacer(),
                Icon(_open ? Icons.expand_less_rounded : Icons.help_outline_rounded, size: 17, color: EkkoColors.red),
                const Gap(4),
                Text(context.t('why_this'), style: T.small.copyWith(color: EkkoColors.red, fontWeight: FontWeight.w700)),
                const Gap(Sp.md),
                if (i.optional) Text(rupees(unit * i.qty), style: T.h3.copyWith(fontSize: 15)),
                const Gap(4),
              ]),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(54, Sp.sm, Sp.sm, 0),
                      child: Text(app.s.productWhy(p.id), style: T.bodySoft),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int qty;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  const _Stepper({required this.qty, this.onMinus, this.onPlus});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: EkkoColors.canvas, borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              visualDensity: VisualDensity.compact, iconSize: 18, onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
          Text('$qty', style: T.h3),
          IconButton(visualDensity: VisualDensity.compact, iconSize: 18, onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
        ]),
      );
}

/// Every catalogue product; ineligible ones are shown with the rule that blocks them.
class _AddProductSheet extends StatelessWidget {
  final AppState app;
  const _AddProductSheet({required this.app});

  @override
  Widget build(BuildContext context) {
    final cat = app.data.catalogue;
    final rules = app.data.recommender.rules;
    final active = app.bundle!.activeIds;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (_, controller) => ListView(controller: controller, padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl), children: [
        const Text('Add a product', style: T.h2),
        const Gap(4),
        const Text('Greyed-out items aren\'t possible for your business — here\'s why.', style: T.small),
        const Gap(Sp.md),
        for (final p in cat.all.where((p) => !active.contains(p.id)))
          Builder(builder: (_) {
            final v = rules.businessViolations(p.id, app.profile!);
            final reason = v.isEmpty ? null : noticeText(app.s, cat, Notice(NoticeKind.blocked, p.id, block: v.first.block));
            return Padding(
              padding: const EdgeInsets.only(bottom: Sp.sm),
              child: Opacity(
                opacity: v.isEmpty ? 1 : 0.6,
                child: EkkoCard(
                  padding: const EdgeInsets.all(Sp.md),
                  onTap: v.isEmpty ? () => Navigator.pop(context, p.id) : null,
                  child: Row(children: [
                    IconBadge(productIcon(p.id),
                        size: 38, color: v.isEmpty ? EkkoColors.red : EkkoColors.muted, bg: v.isEmpty ? EkkoColors.redSoft : EkkoColors.canvas),
                    const Gap(Sp.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: T.h3.copyWith(fontSize: 14.5)),
                        Text(reason ?? '${rupees(p.listPrice)} ${p.unit}',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: T.small.copyWith(color: v.isEmpty ? EkkoColors.muted : EkkoColors.amber)),
                      ]),
                    ),
                    Icon(v.isEmpty ? Icons.add_circle_rounded : Icons.block_rounded,
                        color: v.isEmpty ? EkkoColors.red : EkkoColors.muted),
                  ]),
                ),
              ),
            );
          }),
      ]),
    );
  }
}
