import 'eligibility.dart';
import 'profile.dart';

/// How an item got into the bundle, so the UI can explain it honestly.
enum Origin { core, need, dependency, substitute, user }

class LineItem {
  final String productId;
  int qty;
  final Origin origin;
  final Need? need;

  /// For substitutes: the product this replaces.
  final String? replaces;

  /// Optional items can be toggled off in the quote.
  final bool optional;
  bool enabled;

  LineItem(
    this.productId,
    this.qty, {
    required this.origin,
    this.need,
    this.replaces,
    this.optional = true,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'qty': qty,
        'origin': origin.name,
        'need': need?.name,
        'replaces': replaces,
        'optional': optional,
        'enabled': enabled,
      };

  factory LineItem.fromJson(Map<String, dynamic> j) => LineItem(
        j['productId'],
        j['qty'],
        origin: Origin.values.byName(j['origin']),
        need: j['need'] == null ? null : Need.values.byName(j['need']),
        replaces: j['replaces'],
        optional: j['optional'] ?? true,
        enabled: j['enabled'] ?? true,
      );
}

enum NoticeKind { blocked, substituted, autoAdded, upgradePath, trimmed }

class Notice {
  final NoticeKind kind;
  final String productId;
  final Block? block;
  final List<String> alternatives;
  const Notice(this.kind, this.productId, {this.block, this.alternatives = const []});

  Map<String, dynamic> toJson() =>
      {'kind': kind.name, 'productId': productId, 'block': block?.name, 'alternatives': alternatives};

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        NoticeKind.values.byName(j['kind']),
        j['productId'],
        block: j['block'] == null ? null : Block.values.byName(j['block']),
        alternatives: List<String>.from(j['alternatives'] ?? const []),
      );
}

class Bundle {
  final List<LineItem> items;
  final List<Notice> notices;
  Bundle(this.items, this.notices);

  Iterable<LineItem> get active => items.where((i) => i.enabled && i.qty > 0);
  Set<String> get activeIds => active.map((i) => i.productId).toSet();
  bool contains(String id) => items.any((i) => i.productId == id);
  LineItem? item(String id) {
    for (final i in items) {
      if (i.productId == id) return i;
    }
    return null;
  }

  Map<String, dynamic> toJson() =>
      {'items': items.map((i) => i.toJson()).toList(), 'notices': notices.map((n) => n.toJson()).toList()};

  factory Bundle.fromJson(Map<String, dynamic> j) => Bundle(
        (j['items'] as List).map((e) => LineItem.fromJson(e)).toList(),
        (j['notices'] as List).map((e) => Notice.fromJson(e)).toList(),
      );
}
