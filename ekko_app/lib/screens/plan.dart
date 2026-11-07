import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/bundle.dart';
import '../engine/catalogue.dart';
import '../engine/eligibility.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(context.t('rec_title'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Text(
          context.t('rec_sub', {'type': p.businessType, 'emp': p.employees, 'sites': p.sites}),
          style: const TextStyle(color: EkkoColors.inkSoft),
        ),
        const SizedBox(height: 14),
        _PriceCard(quote: q, options: options, saving: saving, catalogue: cat, profileSpend: p.currentMonthlySpend,
            onContract: (m) {
          app.contractMonths = m;
          app.touch();
        }),
        if (_explaining || _aiExplanation != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: EkkoColors.greenSoft, borderRadius: BorderRadius.circular(14)),
            child: _explaining
                ? const LinearProgressIndicator(color: EkkoColors.green)
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.auto_awesome, color: EkkoColors.green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_aiExplanation!, style: const TextStyle(height: 1.4))),
                  ]),
          ),
        ],
        SectionTitle(context.t('included')),
        for (final i in core) _ItemTile(item: i, product: cat[i.productId], onChanged: _changed),
        if (addons.isNotEmpty) ...[
          SectionTitle(context.t('addons')),
          for (final i in addons) _ItemTile(item: i, product: cat[i.productId], onChanged: _changed),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Add a product')),
        if (notices.isNotEmpty) ...[
          SectionTitle(context.t('cant_offer')),
          for (final n in notices)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InfoBanner(
                noticeText(app.s, cat, n),
                icon: switch (n.kind) {
                  NoticeKind.upgradePath => Icons.trending_up,
                  NoticeKind.autoAdded => Icons.add_link,
                  NoticeKind.trimmed => Icons.savings_outlined,
                  _ => Icons.block,
                },
                color: n.kind == NoticeKind.upgradePath ? EkkoColors.green : EkkoColors.amber,
                bg: n.kind == NoticeKind.upgradePath ? EkkoColors.greenSoft : EkkoColors.amberSoft,
              ),
            ),
        ],
      ]),
      bottomNavigationBar: BottomBar(children: [
        FilledButton(
          onPressed: b.active.isEmpty
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsentScreen())),
          child: Text(context.t('continue_kyc')),
        ),
        TextButton(
          onPressed: _callback,
          child: Text(context.t('talk_human'), style: const TextStyle(color: EkkoColors.inkSoft)),
        ),
      ]),
    );
  }
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: EkkoColors.ink, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.t('monthly_total'), style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(rupees(q.monthly),
              style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1)),
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4),
            child: Text(context.t('per_month'), style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(context.t('excl_gst', {'amount': rupees(q.monthlyWithGst)}),
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 14),
        _kv(context.t('setup_once'), q.setup == 0 ? '₹0' : rupees(q.setup)),
        _kv(context.t('contract'),
            q.noLockIn ? context.t('no_lock_in') : context.t('months', {'n': q.contractMonths})),
        if (q.contractDrivenBy != null &&
            q.contractMonths > 12 &&
            catalogue[q.contractDrivenBy!].minContract == q.contractMonths)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
                context.t('contract_reason', {'product': catalogue[q.contractDrivenBy!].name, 'n': q.contractMonths}),
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        _kv(context.t('install_eta', {'n': q.installDays}), ''),
        if (profileSpend > 0)
          _kv(context.t('vs_today', {'amount': rupees(profileSpend)}), ''),
        if (options.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final m in options)
              ChoiceChip(
                label: Text(m <= 1 ? context.t('no_lock_in') : context.t('months', {'n': m})),
                selected: q.contractMonths == m,
                onSelected: (_) => onContract(m),
                selectedColor: EkkoColors.red,
                labelStyle: TextStyle(
                    color: q.contractMonths == m ? Colors.white : EkkoColors.ink, fontWeight: FontWeight.w700),
              ),
          ]),
          if (saving > 0 && q.contractMonths < 24)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(context.t('save_24', {'amount': rupees(saving)}),
                  style: const TextStyle(color: Color(0xFF7CE495), fontWeight: FontWeight.w700)),
            ),
        ],
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(color: Colors.white, fontSize: 14))),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      );
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: i.enabled ? EkkoColors.ink : EkkoColors.inkSoft)),
                    const SizedBox(height: 2),
                    Text('${rupees(unit)} ${p.unit} · ${p.category}',
                        style: const TextStyle(color: EkkoColors.inkSoft, fontSize: 12)),
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
                  Text(rupees(unit * i.qty), style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              if (i.enabled) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Text('${context.t('qty')}:', style: const TextStyle(color: EkkoColors.inkSoft)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: i.qty > 1
                        ? () {
                            i.qty--;
                            widget.onChanged();
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${i.qty}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: i.qty < 50
                        ? () {
                            i.qty++;
                            widget.onChanged();
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const Spacer(),
                  if (i.optional)
                    Text(rupees(unit * i.qty), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ],
              Row(children: [
                Icon(_open ? Icons.expand_less : Icons.help_outline, size: 16, color: EkkoColors.red),
                const SizedBox(width: 4),
                Text(context.t('why_this'),
                    style: const TextStyle(color: EkkoColors.red, fontWeight: FontWeight.w700, fontSize: 13)),
                if (i.origin == Origin.dependency || i.origin == Origin.substitute) ...[
                  const SizedBox(width: 8),
                  Pill(i.origin == Origin.dependency ? 'required' : 'alternative',
                      color: EkkoColors.amber, bg: EkkoColors.amberSoft),
                ],
              ]),
              if (_open)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(app.s.productWhy(p.id), style: const TextStyle(height: 1.4)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
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
      builder: (_, controller) => ListView(controller: controller, padding: const EdgeInsets.all(16), children: [
        const Text('Add a product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final p in cat.all.where((p) => !active.contains(p.id)))
          Builder(builder: (_) {
            final v = rules.businessViolations(p.id, app.profile!);
            final reason = v.isEmpty ? null : noticeText(app.s, cat, Notice(NoticeKind.blocked, p.id, block: v.first.block));
            return ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: v.isEmpty,
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(reason ?? '${rupees(p.listPrice)} ${p.unit} · ${app.s.productWhy(p.id)}',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Icon(v.isEmpty ? Icons.add_circle : Icons.block,
                  color: v.isEmpty ? EkkoColors.red : EkkoColors.inkSoft),
              onTap: v.isEmpty ? () => Navigator.pop(context, p.id) : null,
            );
          }),
      ]),
    );
  }
}
