import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _stageKeys = {
  Stage.placed: 'stage_placed',
  Stage.kyc: 'stage_kyc',
  Stage.scheduled: 'stage_scheduled',
  Stage.install: 'stage_install',
  Stage.active: 'stage_active',
};

final _date = DateFormat('d MMM');
final _dateTime = DateFormat('d MMM, h:mm a');

/// Proactive message the owner gets at each stage (sent as WhatsApp/SMS in production).
String? bookedSlot(Order o) {
  for (final e in o.events.reversed) {
    if (e.note != null && e.note!.startsWith('slot:')) return e.note!.substring(5);
  }
  return null;
}

String stageUpdate(Order o, Stage s) => switch (s) {
      Stage.placed => 'Order ${o.id} received. Your KYC is being verified instantly.',
      Stage.kyc => 'KYC verified ✓ — no paperwork pending. Scheduling your installation now.',
      Stage.scheduled => bookedSlot(o) != null
          ? 'Engineer visit confirmed for ${bookedSlot(o)} — the slot you picked. Reply 1 to reschedule.'
          : 'Engineer visit booked for ${_date.format(o.eta.subtract(const Duration(days: 1)))}, 10 am – 1 pm. Reply 1 to reschedule.',
      Stage.install => 'Your engineer is on the way. Lines and devices will be activated on site.',
      Stage.active => 'All services are live! One bill, one support number: 121 for business.',
    };

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Future<List<Order>>? _orders;

  void _reload() => _orders = Repository.orders(context.read<AppState>().user!.id);

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    _reload();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('my_orders'))),
      body: FutureBuilder<List<Order>>(
        future: _orders,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return Padding(padding: const EdgeInsets.all(16), child: InfoBanner(context.t('no_orders')));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => OrderCard(order: list[i], onChanged: () => setState(_reload)),
            ),
          );
        },
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onChanged;
  const OrderCard({super.key, required this.order, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final done = o.status == Stage.active;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackerScreen(orderId: o.id)));
          onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(o.businessName ?? o.id, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Pill(context.t(_stageKeys[o.status]!),
                  color: done ? EkkoColors.green : EkkoColors.red, bg: done ? EkkoColors.greenSoft : EkkoColors.redSoft),
            ]),
            const SizedBox(height: 6),
            Text('${o.id} · ${rupees(o.monthly)}${context.t('per_month')}',
                style: const TextStyle(color: EkkoColors.inkSoft)),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (o.status.index + 1) / Stage.values.length,
              color: done ? EkkoColors.green : EkkoColors.red,
              backgroundColor: EkkoColors.line,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
            if (!done) ...[
              const SizedBox(height: 8),
              Text(context.t('eta_on', {'date': _date.format(o.eta)}), style: const TextStyle(fontSize: 13)),
            ],
          ]),
        ),
      ),
    );
  }
}

class TrackerScreen extends StatefulWidget {
  final String orderId;
  const TrackerScreen({super.key, required this.orderId});
  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  late Future<Order?> _order = Repository.order(widget.orderId);

  Future<void> _advance() async {
    await Repository.advance(widget.orderId, context.read<AppState>().user!.id);
    setState(() => _order = Repository.order(widget.orderId));
  }

  Future<void> _book(String slot) async {
    await Repository.bookSlot(widget.orderId, slot, context.read<AppState>().user!.id);
    setState(() => _order = Repository.order(widget.orderId));
    if (mounted) context.toast('Visit booked: $slot');
  }

  Future<void> _callback(Order o) async {
    final app = context.read<AppState>();
    await Repository.saveLead(
        userId: app.user?.id, profile: o.profile, model: app.data.propensity, stage: 'order_${o.status.name}', reason: 'support');
    if (mounted) context.toast(app.s.t('callback_requested'));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('tracker_title'))),
      body: FutureBuilder<Order?>(
        future: _order,
        builder: (context, snap) {
          final o = snap.data;
          if (o == null) return const Center(child: CircularProgressIndicator());
          final reached = {for (final e in o.events) e.stage: e.at};
          final cat = app.data.catalogue;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(o.businessName ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text('${o.id}${o.gstinMasked == null ? '' : ' · GSTIN ${o.gstinMasked}'}',
                style: const TextStyle(color: EkkoColors.inkSoft)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: EkkoColors.ink, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                const Icon(Icons.event_available, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    o.status == Stage.active
                        ? context.t('stage_active')
                        : context.t('eta_on', {'date': _date.format(o.eta)}),
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ]),
            ),
            if (o.status.index <= Stage.kyc.index) ...[
              const SizedBox(height: 16),
              _SlotPicker(start: o.createdAt, onBook: _book),
            ],
            const SizedBox(height: 16),
            for (final s in Stage.values) _TimelineRow(
              title: context.t(_stageKeys[s]!),
              at: reached[s],
              current: s == o.status,
              last: s == Stage.active,
            ),
            const SizedBox(height: 6),
            if (o.status != Stage.active)
              OutlinedButton.icon(
                onPressed: _advance,
                icon: const Icon(Icons.fast_forward_outlined),
                label: Text(context.t('simulate_next')),
              ),
            SectionTitle(context.t('updates')),
            for (final e in o.events.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: EkkoColors.greenSoft, borderRadius: BorderRadius.circular(12)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.chat, size: 18, color: EkkoColors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(stageUpdate(o, e.stage), style: const TextStyle(height: 1.35)),
                        const SizedBox(height: 2),
                        Text(_dateTime.format(e.at), style: const TextStyle(fontSize: 11, color: EkkoColors.inkSoft)),
                      ]),
                    ),
                  ]),
                ),
              ),
            SectionTitle('Plan'),
            for (final i in o.bundle.active)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${cat[i.productId].name} × ${i.qty}'),
              ),
            const SizedBox(height: 4),
            Text('${rupees(o.monthly)}${context.t('per_month')} · '
                '${o.contract <= 1 ? context.t('no_lock_in') : context.t('months', {'n': o.contract})}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            SectionTitle(context.t('need_help')),
            InfoBanner(context.t('no_calls_needed'), icon: Icons.notifications_active_outlined),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _callback(o),
              icon: const Icon(Icons.phone_callback_outlined),
              label: Text(context.t('request_callback')),
            ),
          ]);
        },
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String title;
  final DateTime? at;
  final bool current;
  final bool last;
  const _TimelineRow({required this.title, required this.at, required this.current, required this.last});

  @override
  Widget build(BuildContext context) {
    final done = at != null;
    final color = done ? (current && !last ? EkkoColors.red : EkkoColors.green) : EkkoColors.line;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: done ? color : Colors.white, shape: BoxShape.circle,
                border: Border.all(color: color, width: 2)),
            child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
          if (!last) Expanded(child: Container(width: 2, color: done ? color : EkkoColors.line)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: current ? FontWeight.w900 : FontWeight.w600,
                      color: done ? EkkoColors.ink : EkkoColors.inkSoft,
                      fontSize: 15)),
              if (at != null)
                Text(_dateTime.format(at!), style: const TextStyle(fontSize: 12, color: EkkoColors.inkSoft)),
            ]),
          ),
        ),
      ]),
    );
  }
}


/// Owner picks the engineer visit — the #1 reason customers used to call.
class _SlotPicker extends StatefulWidget {
  final DateTime start;
  final ValueChanged<String> onBook;
  const _SlotPicker({required this.start, required this.onBook});
  @override
  State<_SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<_SlotPicker> {
  int _day = 0;
  int _win = 0;
  static const _windows = ['9 – 12', '12 – 3', '3 – 6'];

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 1; i <= 4; i++) widget.start.add(Duration(days: i))];
    return EkkoCard(
      padding: const EdgeInsets.all(Sp.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          IconBadge(Icons.event_rounded, size: 38),
          Gap(Sp.md),
          Expanded(child: Text('Pick your installation slot', style: T.h3)),
        ]),
        const Gap(Sp.md),
        Row(children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _day = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _day == i ? EkkoColors.red : EkkoColors.canvas,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    Text(DateFormat('EEE').format(days[i]),
                        style: T.small.copyWith(color: _day == i ? Colors.white70 : EkkoColors.muted)),
                    Text(DateFormat('d').format(days[i]),
                        style: T.h2.copyWith(color: _day == i ? Colors.white : EkkoColors.ink)),
                  ]),
                ),
              ),
            ),
        ]),
        const Gap(Sp.md),
        Wrap(spacing: 8, children: [
          for (var i = 0; i < _windows.length; i++)
            ChoiceChip(
              label: Text(_windows[i]),
              selected: _win == i,
              onSelected: (_) => setState(() => _win = i),
              selectedColor: EkkoColors.redSoft,
            ),
        ]),
        const Gap(Sp.md),
        FilledButton(
          onPressed: () => widget.onBook('${DateFormat('EEE d MMM').format(days[_day])}, ${_windows[_win]}'),
          child: const Text('Book this slot'),
        ),
      ]),
    );
  }
}
