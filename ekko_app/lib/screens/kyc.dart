import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../engine/identifiers.dart';
import '../engine/kyc.dart';
import '../engine/profile.dart';
import '../services/ocr_service.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'checkout.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});
  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _ocr = OcrService();
  final _picker = ImagePicker();
  final _docs = <DocType, ExtractedDoc>{};
  final _busy = <DocType>{};
  final _source = <DocType, String>{};
  KycReport? _report;
  bool _verifying = false;

  static const _samples = ['K01', 'K02', 'K03', 'K04', 'K05', 'K06', 'K07', 'K08', 'K09', 'K10', 'K11', 'K12'];

  @override
  void initState() {
    super.initState();
    SecureWindow.set(true); // no screenshots while identity data is on screen
  }

  @override
  void dispose() {
    SecureWindow.set(false);
    _ocr.dispose();
    super.dispose();
  }

  AppState get app => context.read<AppState>();

  bool get _gstRequired {
    final cat = app.data.catalogue;
    return app.profile!.gstin != null || app.bundle!.active.any((i) => cat[i.productId].requiresGstin);
  }

  Future<void> _scan(DocType type, ImageSource src) async {
    final x = await _picker.pickImage(source: src, imageQuality: 92, maxWidth: 2000);
    if (x == null) return;
    setState(() => _busy.add(type));
    try {
      final doc = await _ocr.readFile(type, File(x.path));
      _set(type, doc, src == ImageSource.camera ? 'camera' : 'gallery');
    } catch (_) {
      if (mounted) context.toast(app.s.t('error_generic'));
    } finally {
      if (mounted) setState(() => _busy.remove(type));
    }
  }

  Future<void> _sample(DocType type, String applicant) async {
    if (!await OcrService.sampleExists(type, applicant)) {
      setState(() {
        _docs.remove(type);
        _source[type] = '$applicant: not provided';
        _report = null;
      });
      return;
    }
    setState(() => _busy.add(type));
    try {
      _set(type, await _ocr.readSample(type, applicant), 'specimen $applicant');
    } catch (_) {
      if (mounted) context.toast(app.s.t('error_generic'));
    } finally {
      if (mounted) setState(() => _busy.remove(type));
    }
  }

  void _set(DocType type, ExtractedDoc doc, String src) {
    if (!mounted) return;
    setState(() {
      _docs[type] = doc;
      _source[type] = src;
      _report = null;
    });
  }

  Future<void> _pickApplicant({DocType? only}) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.s.t('pick_sample'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in _samples) ActionChip(label: Text(s), onPressed: () => Navigator.pop(context, s)),
            ]),
          ]),
        ),
      ),
    );
    if (a == null) return;
    for (final t in only == null ? DocType.values : [only]) {
      await _sample(t, a);
    }
  }

  /// Mock DigiLocker / Entity Locker: issued records come straight from the
  /// registry with the owner's consent, so no photo or OCR is needed.
  void _digilocker(DocType type) {
    final g = app.profile!.gstin;
    final rec = g == null ? null : app.data.registry.gstin(g);
    if (rec == null) {
      context.toast('Enter your GSTIN in the advisor first to link DigiLocker (demo).');
      return;
    }
    if (type == DocType.gstCertificate) {
      _set(type, ExtractedDoc(type, {
        'gstin': rec.gstin, 'legalName': rec.legalName, 'tradeName': rec.tradeName,
        'constitution': rec.constitution, 'address': rec.address, 'dateOfLiability': rec.registrationDate,
      }), 'DigiLocker');
    } else {
      final u = app.data.registry.udyamByName(rec.tradeName);
      if (u.isEmpty) {
        context.toast('No Udyam registration found in DigiLocker for ${rec.tradeName}.');
        return;
      }
      _set(type, ExtractedDoc(type, {
        'number': u.first.number, 'enterpriseName': u.first.enterpriseName, 'majorActivity': u.first.majorActivity,
        'city': u.first.city, 'state': u.first.state, 'registrationDate': u.first.registrationDate,
      }), 'DigiLocker');
    }
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final report = app.data.kyc.validate(_docs, gstRequired: _gstRequired);
    await Repository.saveKycReport(app.user!.id, report);
    if (!mounted) return;
    app.kycReport = report;
    if (report.gst != null) {
      app.businessName = report.gst!.tradeName;
      app.profile!.hasUdyam = report.udyam != null;
    }
    setState(() {
      _report = report;
      _verifying = false;
    });
  }

  void _continueWithoutGst() {
    final p = app.profile!;
    p.gstStatus = GstStatus.none;
    p.gstin = null;
    final b = app.data.recommender.recommend(p);
    app.setPlan(p, b);
    setState(() {
      _docs.remove(DocType.gstCertificate);
      _report = null;
    });
    context.toast('Plan updated: GST-only products removed.');
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AppState>();
    final g = a.profile?.gstin;
    final rec = g == null ? null : a.data.registry.gstin(g);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('kyc_title'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xxl), children: [
        Text(context.t('kyc_sub'), style: T.bodySoft),
        const Gap(Sp.md),
        EkkoCard(
          child: Row(children: [
            ScoreRing(score: (_docs.length * 25).clamp(0, 100), size: 64, caption: '%'),
            const Gap(Sp.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_docs.length} of 4 documents read', style: T.h3),
                const Gap(2),
                const Text('On-device OCR · photos deleted right after reading · screenshots blocked', style: T.small),
              ]),
            ),
          ]),
        ),
        if (rec != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified, color: EkkoColors.green),
              title: Text(rec.tradeName, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('GSTIN ${Gstin.mask(rec.gstin)} · ${rec.constitution} · ${rec.status}'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pickApplicant(),
          icon: const Icon(Icons.folder_copy_outlined),
          label: const Text('Demo: load a specimen applicant (K01–K12)'),
        ),
        const SizedBox(height: 4),
        for (final t in DocType.values)
          _DocSlot(
            type: t,
            doc: _docs[t],
            busy: _busy.contains(t),
            source: _source[t],
            onCamera: () => _scan(t, ImageSource.camera),
            onGallery: () => _scan(t, ImageSource.gallery),
            onSample: () => _pickApplicant(only: t),
            onDigiLocker: (t == DocType.gstCertificate || t == DocType.udyamCertificate) ? () => _digilocker(t) : null,
          ),
        if (_report != null) _ReportView(report: _report!),
      ]),
      bottomNavigationBar: BottomBar(children: [
        if (_report?.verdict == Verdict.approved) ...[
          InfoBanner(context.t('docs_deleted'), icon: Icons.delete_sweep_outlined),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CheckoutScreen())),
            child: Text(context.t('proceed_checkout')),
          ),
        ] else ...[
          if (_report != null && _report!.checks.any((c) => c.id == 'gst_status' && c.severity == Severity.fail))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(onPressed: _continueWithoutGst, child: Text(context.t('continue_without_gst'))),
            ),
          FilledButton(
            onPressed: _docs.isEmpty || _busy.isNotEmpty || _verifying ? null : _verify,
            child: Text(_report == null ? context.t('verify_now') : context.t('fix_and_retry')),
          ),
        ],
      ]),
    );
  }
}

class _DocSlot extends StatelessWidget {
  final DocType type;
  final ExtractedDoc? doc;
  final bool busy;
  final String? source;
  final VoidCallback onCamera, onGallery, onSample;
  final VoidCallback? onDigiLocker;
  const _DocSlot({
    required this.type,
    required this.doc,
    required this.busy,
    required this.source,
    required this.onCamera,
    required this.onGallery,
    required this.onSample,
    this.onDigiLocker,
  });

  static String _maskField(String k, String v) => switch (k) {
        'gstin' => Gstin.mask(Gstin.normalise(v)),
        'number' => Udyam.mask(Udyam.normalise(v)),
        'idNo' || 'consumerNo' => maskTail(v),
        _ => v,
      };

  @override
  Widget build(BuildContext context) {
    final d = doc;
    final ok = d != null && d.readability >= KycValidator.minReadability;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(
                d == null ? Icons.description_outlined : (ok ? Icons.check_circle : Icons.warning_amber_rounded),
                color: d == null ? EkkoColors.inkSoft : (ok ? EkkoColors.green : EkkoColors.amber),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.t('doc_${type.name}'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
            if (source != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 34),
                child: Text(
                  d == null ? source! : '$source · ${context.t('fields_read', {'n': d.fields.length})}'
                      '${d.rotationDegrees.abs() >= 2 ? ' · straightened ${d.rotationDegrees.toStringAsFixed(0)}°' : ''}',
                  style: const TextStyle(color: EkkoColors.inkSoft, fontSize: 12),
                ),
              ),
            if (d != null && d.fields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 34),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final e in d.fields.entries.take(5))
                    Text('${e.key}: ${_maskField(e.key, e.value)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                ]),
              ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _btn(Icons.photo_camera_outlined, context.t('take_photo'), busy ? null : onCamera),
              _btn(Icons.photo_library_outlined, context.t('from_gallery'), busy ? null : onGallery),
              _btn(Icons.science_outlined, context.t('use_sample'), busy ? null : onSample),
              if (onDigiLocker != null) _btn(Icons.cloud_download_outlined, context.t('digilocker'), busy ? null : onDigiLocker),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _btn(IconData i, String label, VoidCallback? onTap) => ActionChip(
        avatar: Icon(i, size: 16, color: EkkoColors.red),
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        onPressed: onTap,
      );
}

class _ReportView extends StatelessWidget {
  final KycReport report;
  const _ReportView({required this.report});

  @override
  Widget build(BuildContext context) {
    final v = report.verdict;
    final (color, bg, icon) = switch (v) {
      Verdict.approved => (EkkoColors.green, EkkoColors.greenSoft, Icons.verified),
      Verdict.actionNeeded => (EkkoColors.amber, EkkoColors.amberSoft, Icons.pending_actions),
      Verdict.rejected => (EkkoColors.redDark, EkkoColors.redSoft, Icons.gpp_bad_outlined),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(context.t('verdict_${v.name}'),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 17)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        for (final c in report.checks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                switch (c.severity) {
                  Severity.pass => Icons.check_circle_outline,
                  Severity.info => Icons.info_outline,
                  Severity.warn => Icons.error_outline,
                  Severity.action => Icons.build_circle_outlined,
                  Severity.fail => Icons.cancel_outlined,
                },
                size: 18,
                color: switch (c.severity) {
                  Severity.pass => EkkoColors.green,
                  Severity.info => EkkoColors.inkSoft,
                  Severity.warn || Severity.action => EkkoColors.amber,
                  Severity.fail => EkkoColors.redDark,
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.message, style: const TextStyle(height: 1.35)),
                  if (c.fix != null && c.severity.index >= Severity.action.index)
                    Text('${context.t('fix')}: ${c.fix}',
                        style: const TextStyle(color: EkkoColors.inkSoft, fontSize: 12.5, height: 1.35)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}
