import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/app_data.dart';
import '../engine/identifiers.dart';
import '../engine/profile.dart';
import '../l10n/strings.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'plan.dart';

enum Step { type, employees, sites, city, cityTier, internet, spend, needs, gstin, pincode, budget, done }

class _Msg {
  final bool bot;
  final String text;
  final Color? tone;
  const _Msg(this.bot, this.text, {this.tone});
}

class _Chip {
  final String label;
  final Object value;
  const _Chip(this.label, this.value);
}

/// Conversational needs discovery. Works fully offline with tap-to-answer
/// chips; when the AI backend is online, free text in any language is
/// understood too. Answers only fill the profile — the plan comes from rules.
class AdvisorScreen extends StatefulWidget {
  const AdvisorScreen({super.key});
  @override
  State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  final _msgs = <_Msg>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  final _profile = BusinessProfile();
  final _picked = <Need>{};
  Step _step = Step.type;
  bool _typing = false;
  bool _listening = false;
  bool _finished = false;
  bool _showAllTypes = false;
  String? _businessName;
  String _pendingCity = '';

  AppState get app => context.read<AppState>();
  S get s => app.s;

  @override
  void initState() {
    super.initState();
    _profile.language = app.lang;
    _bot(s.t('adv_hello'));
    _ask(Step.type);
  }

  @override
  void dispose() {
    // A conversation that got real answers but never reached a plan is a lead
    // for partners to follow up ("leads the advisor could not close").
    if (!_finished && _step.index > Step.employees.index) {
      Repository.saveLead(
          userId: app.user?.id,
          profile: _profile,
          model: app.data.propensity,
          stage: 'advisor_${_step.name}',
          reason: 'left_advisor');
    }
    _speech.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---- conversation helpers ---------------------------------------------------
  void _bot(String text, {Color? tone}) => _msgs.add(_Msg(true, text, tone: tone));

  void _user(String text) => _msgs.add(_Msg(false, text));

  Future<void> _say(String text, {Color? tone}) async {
    setState(() => _typing = true);
    _scrollDown();
    await Future.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;
    setState(() {
      _typing = false;
      _bot(text, tone: tone);
    });
    _scrollDown();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  String _question(Step st) => switch (st) {
        Step.type => s.t('q_type'),
        Step.employees => s.t('q_employees'),
        Step.sites => s.t('q_sites'),
        Step.city => s.t('q_city'),
        Step.cityTier => s.t('q_city_unknown', {'city': _pendingCity}),
        Step.internet => s.t('q_internet'),
        Step.spend => s.t('q_spend'),
        Step.needs => s.t('q_needs'),
        Step.gstin => s.t('q_gstin'),
        Step.pincode => s.t('q_pincode'),
        Step.budget => s.t('budget_q'),
        Step.done => '',
      };

  Future<void> _ask(Step st) async {
    _step = st;
    if (st == Step.done) return _finish();
    if (_msgs.length == 1) {
      setState(() => _bot(_question(st)));
    } else {
      await _say(_question(st));
    }
    setState(() {});
  }

  List<_Chip> _chips() {
    switch (_step) {
      case Step.type:
        final list = _showAllTypes ? businessTypes : businessTypes.take(12);
        return [for (final t in list) _Chip(t, t), if (!_showAllTypes) _Chip('${s.t('other')} …', '_more')];
      case Step.employees:
        return [
          _Chip(s.t('emp_1'), 1), _Chip(s.t('emp_2_5'), 4), _Chip(s.t('emp_6_10'), 8),
          _Chip(s.t('emp_11_25'), 18), _Chip(s.t('emp_26_50'), 38), _Chip(s.t('emp_50p'), 75),
        ];
      case Step.sites:
        return [
          _Chip(s.t('sites_1'), 1), _Chip(s.t('sites_2'), 2), _Chip(s.t('sites_3_5'), 4),
          _Chip(s.t('sites_6_10'), 8), _Chip(s.t('sites_10p'), 12),
        ];
      case Step.city:
        return [for (final c in cities.keys.where((c) => c != 'Bangalore' && c != 'New Delhi')) _Chip(c, c)];
      case Step.cityTier:
        return [_Chip(s.t('metro_yes'), 1), _Chip(s.t('metro_no'), 2)];
      case Step.internet:
        return [
          _Chip(s.t('net_hotspot'), 'Mobile hotspot'), _Chip(s.t('net_home'), 'Home broadband'),
          _Chip(s.t('net_business'), 'Business broadband'), _Chip(s.t('net_leased'), 'Leased line'),
          _Chip(s.t('net_none'), ''),
        ];
      case Step.spend:
        return [
          _Chip(s.t('spend_lt1k'), 700), _Chip(s.t('spend_1_3k'), 2000), _Chip(s.t('spend_3_8k'), 5000),
          _Chip(s.t('spend_8_20k'), 12000), _Chip(s.t('spend_20kp'), 25000),
        ];
      case Step.needs:
        return [for (final n in _needsFor(_profile.segment)) _Chip(s.t('need_${n.name}'), n)];
      case Step.gstin:
        return [_Chip(s.t('no_gstin'), '_none')];
      case Step.budget:
        return [
          _Chip(s.t('no_budget'), 0), _Chip('₹1,500', 1500), _Chip('₹3,000', 3000), _Chip('₹8,000', 8000),
          _Chip('₹25,000', 25000),
        ];
      case Step.pincode:
      case Step.done:
        return const [];
    }
  }

  static List<Need> _needsFor(Segment seg) => switch (seg) {
        Segment.micro => [Need.upiPos, Need.cctv, Need.whatsapp, Need.guestWifi, Need.website, Need.sms,
            Need.deviceSecurity, Need.failover, Need.cloudEmail],
        Segment.prof => [Need.cloudEmail, Need.deviceSecurity, Need.backup, Need.failover, Need.staticIp,
            Need.telephony, Need.whatsapp, Need.sms, Need.website, Need.tollFree, Need.firewall, Need.guestWifi],
        Segment.multi => [Need.upiPos, Need.cctv, Need.failover, Need.multiSiteMgmt, Need.guestWifi, Need.whatsapp,
            Need.tollFree, Need.cloudEmail, Need.firewall, Need.fleet, Need.sms],
        Segment.mfg => [Need.dedicatedLine, Need.firewall, Need.machineIot, Need.cloudEmail, Need.deviceSecurity,
            Need.cctv, Need.staticIp, Need.fleet, Need.backup],
      };

  // ---- answers ---------------------------------------------------------------
  Future<void> _onChip(_Chip c) async {
    if (_typing) return;
    if (_step == Step.type && c.value == '_more') return setState(() => _showAllTypes = true);
    if (_step == Step.needs) {
      setState(() {
        final n = c.value as Need;
        _picked.contains(n) ? _picked.remove(n) : _picked.add(n);
      });
      return;
    }
    setState(() => _user(c.label));
    await _apply(_step, c.value);
  }

  Future<void> _onText([String? raw]) async {
    final text = (raw ?? _input.text).trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    setState(() => _user(text));
    final local = _parseLocal(_step, text);
    if (local != null) return _apply(_step, local);

    // Not understood on-device: ask the AI backend (any language).
    if (app.backend.online) {
      setState(() => _typing = true);
      final fields = await app.backend.understand(
          step: _step.name, text: text, language: app.lang, profile: _profile.toJson());
      if (!mounted) return;
      setState(() => _typing = false);
      final v = fields == null ? null : _fromBackend(_step, fields);
      if (v != null) return _apply(_step, v);
      final answer = await app.backend.ask(language: app.lang, question: text, context: _profile.toJson());
      if (answer != null && mounted) {
        await _say(answer);
        return _ask(_step);
      }
    }
    await _say(_step == Step.needs ? s.t('q_needs') : _question(_step));
  }

  Object? _fromBackend(Step st, Map<String, dynamic> f) => switch (st) {
        Step.type => f['businessType'],
        Step.employees => (f['employees'] as num?)?.toInt(),
        Step.sites => (f['sites'] as num?)?.toInt(),
        Step.city => f['city'],
        Step.cityTier => (f['cityTier'] as num?)?.toInt(),
        Step.internet => f['currentInternet'],
        Step.spend => (f['currentMonthlySpend'] as num?)?.toInt(),
        Step.gstin => f['gstin'] ?? (f['noGstin'] == true ? '_none' : null),
        Step.pincode => f['pincode']?.toString(),
        Step.budget => (f['budget'] as num?)?.toInt() ?? (f['noBudget'] == true ? 0 : null),
        Step.needs => (f['needs'] as List?)?.map((e) => Need.values.where((n) => n.name == e)).expand((x) => x).toSet(),
        Step.done => null,
      };

  /// Small on-device understanding so typed/spoken answers work offline.
  Object? _parseLocal(Step st, String text) {
    final t = _latinDigits(text).toLowerCase();
    int? num() {
      final m = RegExp(r'(\d[\d,]*)\s*(k|हज़ार|हजार)?').firstMatch(t);
      if (m == null) return null;
      var n = int.tryParse(m[1]!.replaceAll(',', ''));
      if (n != null && m[2] != null) n *= 1000;
      return n;
    }

    switch (st) {
      case Step.type:
        // Longest full-name match first ("pharmacy chain" beats "pharmacy"), then first-word tokens.
        final byLength = [...businessTypes]..sort((a, b) => b.length.compareTo(a.length));
        for (final b in byLength) {
          if (t.contains(b.toLowerCase())) return b;
        }
        final tokens = t.split(RegExp(r'[^a-z0-9]+')).toSet();
        for (final b in businessTypes) {
          if (tokens.contains(b.toLowerCase().split(' ').first)) return b;
        }
        const words = {
          'किराना': 'Kirana store', 'दुकान': 'Kirana store', 'shop': 'Kirana store', 'store': 'Kirana store',
          'सैलून': 'Salon', 'पार्लर': 'Salon', 'parlour': 'Salon', 'क्लिनिक': 'Dental clinic', 'doctor': 'Dental clinic',
          'दवा': 'Pharmacy', 'medical': 'Pharmacy', 'chemist': 'Pharmacy', 'फैक्ट्री': 'Auto-parts unit',
          'factory': 'Auto-parts unit', 'रेस्टोरेंट': 'Restaurant chain', 'restaurant': 'Restaurant chain',
          'cafe': 'Restaurant chain', 'होटल': 'Budget hotel group', 'hotel': 'Budget hotel group',
          'कोचिंग': 'Coaching centre', 'tuition': 'Coaching centre', 'वकील': 'Law office', 'lawyer': 'Law office',
          'ca ': 'CA firm', 'accountant': 'CA firm', 'gym': 'Gym chain', 'बेकरी': 'Bakery',
        };
        for (final e in words.entries) {
          if (t.contains(e.key)) return e.value;
        }
        return text.length >= 3 ? text : null;
      case Step.employees:
      case Step.sites:
        return num();
      case Step.spend:
        return num();
      case Step.budget:
        if (t.contains('no') || t.contains('नहीं') || t.contains('limit')) return 0;
        return num();
      case Step.city:
        const hi = {
          'मुंबई': 'Mumbai', 'दिल्ली': 'Delhi', 'पुणे': 'Pune', 'जयपुर': 'Jaipur', 'लखनऊ': 'Lucknow', 'पटना': 'Patna',
          'इंदौर': 'Indore', 'भोपाल': 'Bhopal', 'नागपुर': 'Nagpur', 'बेंगलुरु': 'Bengaluru', 'चेन्नई': 'Chennai',
          'कोलकाता': 'Kolkata', 'हैदराबाद': 'Hyderabad', 'अहमदाबाद': 'Ahmedabad', 'सूरत': 'Surat', 'नासिक': 'Nashik',
          'लुधियाना': 'Ludhiana', 'वडोदरा': 'Vadodara', 'சென்னை': 'Chennai', 'கோயம்புத்தூர்': 'Coimbatore',
          'मुम्बई': 'Mumbai', 'पुणें': 'Pune',
        };
        for (final e in hi.entries) {
          if (text.contains(e.key)) return e.value;
        }
        for (final c in cities.keys) {
          if (t.contains(c.toLowerCase())) return c;
        }
        return text.length >= 3 ? text : null;
      case Step.cityTier:
        if (t.contains('yes') || t.contains('हाँ') || t.contains('metro')) return 1;
        if (t.contains('no') || t.contains('नहीं')) return 2;
        return null;
      case Step.internet:
        if (t.contains('hotspot') || t.contains('mobile') || t.contains('फ़ोन') || t.contains('फोन')) return 'Mobile hotspot';
        if (t.contains('leased')) return 'Leased line';
        if (t.contains('business')) return 'Business broadband';
        if (t.contains('home') || t.contains('broadband') || t.contains('wifi') || t.contains('wi-fi')) return 'Home broadband';
        if (t.contains('none') || t.contains('nothing') || t.contains('कुछ नहीं')) return '';
        return null;
      case Step.gstin:
        final g = Gstin.normalise(text);
        if (RegExp(r'[0-9]{2}[A-Z0-9]{13}').hasMatch(g)) return RegExp(r'[0-9]{2}[A-Z0-9]{13}').firstMatch(g)![0];
        if (t.contains('no') || t.contains('नहीं') || t.contains('illa') || t.contains('nahi')) return '_none';
        return null;
      case Step.pincode:
        final m = RegExp(r'\b\d{6}\b').firstMatch(t);
        return m?[0];
      case Step.needs:
        final found = <Need>{};
        for (final n in Need.values) {
          if (t.contains(s.t('need_${n.name}').toLowerCase().split(' ').first)) found.add(n);
        }
        if (t.contains('cctv') || t.contains('camera')) found.add(Need.cctv);
        if (t.contains('whatsapp')) found.add(Need.whatsapp);
        if (t.contains('upi') || t.contains('billing') || t.contains('pos')) found.add(Need.upiPos);
        if (t.contains('wifi') || t.contains('wi-fi')) found.add(Need.guestWifi);
        if (t.contains('email')) found.add(Need.cloudEmail);
        return found.isEmpty ? null : found;
      case Step.done:
        return null;
    }
  }

  static String _latinDigits(String s) {
    const dev = '०१२३४५६७८९';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = dev.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return b.toString();
  }

  Future<void> _apply(Step st, Object value) async {
    switch (st) {
      case Step.type:
        _profile.businessType = value as String;
        return _ask(Step.employees);
      case Step.employees:
        _profile.employees = (value as int).clamp(1, 5000);
        return _ask(Step.sites);
      case Step.sites:
        _profile.sites = (value as int).clamp(1, 500);
        _profile.segment = segmentFor(_profile.businessType, _profile.employees, _profile.sites);
        return _ask(Step.city);
      case Step.city:
        final name = value as String;
        final known = cities.entries.where((e) => e.key.toLowerCase() == name.toLowerCase());
        if (known.isNotEmpty) {
          _profile.city = known.first.key;
          _profile.cityTier = known.first.value.$1;
          _profile.state = known.first.value.$2;
          return _ask(Step.internet);
        }
        _pendingCity = name;
        _profile.city = name;
        return _ask(Step.cityTier);
      case Step.cityTier:
        _profile.cityTier = value as int;
        return _ask(Step.internet);
      case Step.internet:
        _profile.currentInternet = value as String;
        return _ask(Step.spend);
      case Step.spend:
        _profile.currentMonthlySpend = value as int;
        return _ask(Step.needs);
      case Step.needs:
        _picked.addAll(value as Set<Need>);
        return _confirmNeeds();
      case Step.gstin:
        return _handleGstin(value as String);
      case Step.pincode:
        return _handlePincode(value as String);
      case Step.budget:
        final b = value as int;
        _profile.budget = b > 0 ? b : null;
        return _ask(Step.done);
      case Step.done:
        return;
    }
  }

  Future<void> _confirmNeeds({bool mobileOnly = false}) async {
    _profile.mobileOnly = mobileOnly;
    _profile.needs = {..._picked};
    final label = mobileOnly
        ? s.t('mobile_only')
        : (_picked.isEmpty ? '—' : _picked.map((n) => s.t('need_${n.name}')).join(', '));
    if (_msgs.last.bot) setState(() => _user(label));
    return _ask(Step.gstin);
  }

  Future<void> _handleGstin(String v) async {
    if (v == '_none') {
      _profile.gstStatus = GstStatus.none;
      await _say(s.t('gst_no_ack'));
      return _ask(_profile.mobileOnly ? Step.done : Step.pincode);
    }
    final g = Gstin.normalise(v);
    if (!Gstin.hasValidFormat(g) || !Gstin.hasValidChecksum(g)) {
      await _say(s.t('gst_invalid', {'reason': Gstin.hasValidFormat(g) ? 'check digit' : 'format'}),
          tone: EkkoColors.redDark);
      return;
    }
    final rec = app.data.registry.gstin(g);
    if (rec == null) {
      await _say(s.t('gst_not_found'), tone: EkkoColors.redDark);
      return;
    }
    _profile.gstin = g;
    _businessName = rec.tradeName;
    _profile.hasUdyam = app.data.registry.udyamByName(rec.tradeName).isNotEmpty;
    _profile.gstStatus = switch (rec.status) {
      'Active' => GstStatus.active,
      'Cancelled' => GstStatus.cancelled,
      'Suspended' => GstStatus.suspended,
      _ => GstStatus.none,
    };
    await _say(s.t('gst_found', {'name': rec.tradeName, 'state': rec.state, 'status': rec.status}),
        tone: rec.isActive ? EkkoColors.green : EkkoColors.amber);
    if (!rec.isActive) await _say(s.t('gst_inactive', {'status': rec.status}), tone: EkkoColors.amber);
    if (rec.isActive && _profile.state.isNotEmpty && rec.state != _profile.state) {
      await _say('Note: this GSTIN is registered in ${rec.state}.', tone: EkkoColors.amber);
    }
    return _ask(_profile.mobileOnly ? Step.done : Step.pincode);
  }

  /// Mock feasibility API. Demo rule: pincodes ending in 0 have no fibre yet.
  Future<void> _handlePincode(String pin) async {
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(pin)) {
      await _say(s.t('pin_invalid'));
      return;
    }
    _profile.fibreFeasible = !pin.endsWith('0');
    await _say(s.t(_profile.fibreFeasible ? 'feasible_yes' : 'feasible_no', {'pin': pin}),
        tone: _profile.fibreFeasible ? EkkoColors.green : EkkoColors.amber);
    return _ask(Step.budget);
  }

  Future<void> _finish() async {
    await _say(s.t('building'));
    final bundle = app.data.recommender.recommend(_profile);
    _finished = true;
    if (!mounted) return;
    app.setPlan(_profile, bundle, name: _businessName);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PlanScreen()));
  }

  // ---- voice ---------------------------------------------------------------------
  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      return setState(() => _listening = false);
    }
    final ok = await _speech.initialize(onStatus: (st) {
      if (st == 'done' || st == 'notListening') setState(() => _listening = false);
    });
    if (!ok) {
      if (mounted) context.toast('Voice input is not available on this phone.');
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(
          localeId: S.speechLocales[app.lang], partialResults: true, listenMode: ListenMode.dictation),
      onResult: (r) {
        _input.text = r.recognizedWords;
        if (r.finalResult) {
          setState(() => _listening = false);
          _onText(r.recognizedWords);
        }
      },
    );
  }

  // ---- UI --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final chips = _chips();
    final multi = _step == Step.needs;
    final progress = (_step.index / Step.done.index).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('adv_title')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: progress, minHeight: 3, color: EkkoColors.red, backgroundColor: EkkoColors.line),
        ),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Center(child: ModeBadge()))],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            itemCount: _msgs.length + (_typing ? 1 : 0),
            itemBuilder: (_, i) => i == _msgs.length ? const _TypingBubble() : _Bubble(_msgs[i]),
          ),
        ),
        if (!_typing && _step != Step.done)
          Container(
            constraints: const BoxConstraints(maxHeight: 230),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: SingleChildScrollView(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in chips)
                  multi
                      ? FilterChip(
                          label: Text(c.label),
                          selected: _picked.contains(c.value),
                          checkmarkColor: EkkoColors.red,
                          onSelected: (_) => _onChip(c),
                        )
                      : ActionChip(label: Text(c.label), onPressed: () => _onChip(c)),
              ]),
            ),
          ),
        if (multi && !_typing)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmNeeds(mobileOnly: true),
                  child: Text(context.t('mobile_only'), textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _confirmNeeds(),
                  child: Text('${context.t('done_selecting')}${_picked.isEmpty ? '' : ' (${_picked.length})'}'),
                ),
              ),
            ]),
          ),
        _Composer(
          controller: _input,
          listening: _listening,
          hint: _listening ? context.t('listening') : context.t('type_message'),
          numeric: _step == Step.pincode,
          onSend: _onText,
          onMic: _toggleMic,
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg m;
  const _Bubble(this.m);
  @override
  Widget build(BuildContext context) {
    final bot = m.bot;
    return Align(
      alignment: bot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bot ? (m.tone == null ? EkkoColors.surface : m.tone!.withValues(alpha: 0.1)) : EkkoColors.red,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(bot ? 4 : 16),
            bottomRight: Radius.circular(bot ? 16 : 4),
          ),
        ),
        child: Text(m.text,
            style: TextStyle(
                color: bot ? (m.tone ?? EkkoColors.ink) : Colors.white, fontSize: 15, height: 1.35,
                fontWeight: bot && m.tone != null ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: EkkoColors.surface, borderRadius: BorderRadius.circular(16)),
          child: const SizedBox(
              width: 28, height: 10, child: LinearProgressIndicator(color: EkkoColors.red, minHeight: 3)),
        ),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool listening;
  final bool numeric;
  final String hint;
  final void Function([String?]) onSend;
  final VoidCallback onMic;
  const _Composer({
    required this.controller,
    required this.listening,
    required this.hint,
    required this.numeric,
    required this.onSend,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: numeric ? TextInputType.number : TextInputType.text,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(hintText: hint),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                  backgroundColor: listening ? EkkoColors.red : EkkoColors.redSoft,
                  foregroundColor: listening ? Colors.white : EkkoColors.red,
                  fixedSize: const Size(48, 48)),
              onPressed: onMic,
              icon: Icon(listening ? Icons.stop : Icons.mic),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: EkkoColors.ink, fixedSize: const Size(48, 48)),
              onPressed: () => onSend(),
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ]),
        ),
      );
}
