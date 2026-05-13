// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Boost-related schemas.

import '_helpers.dart';
import 'enums.dart';

/// `BoostPlanModel` — purchasable plan card. Every field is required per spec.
class BoostPlanModel {
  BoostPlanModel({
    required this.id,
    required this.name,
    required this.tier,
    required this.durationMinutes,
    required this.priceCents,
    required this.currency,
    required this.price,
    required this.duration,
    required this.label,
  });

  final String id;
  final String name;
  final BoostTier tier;
  final int durationMinutes;
  final int priceCents;
  /// ISO 4217 (e.g. `USD`).
  final String currency;
  /// Pre-formatted price (e.g. `"$0.99"`).
  final String price;
  /// Pre-formatted duration (e.g. `"30 min"`).
  final String duration;
  /// Marketing label (e.g. `"Try it out"`).
  final String label;

  factory BoostPlanModel.fromJson(Map<String, dynamic> json) => BoostPlanModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        tier: BoostTier.fromJson(json['tier']) ?? BoostTier.bronze,
        durationMinutes: coerceInt(json['durationMinutes']) ?? 0,
        priceCents: coerceInt(json['priceCents']) ?? 0,
        currency: json['currency'] as String? ?? '',
        price: json['price'] as String? ?? '',
        duration: json['duration'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tier': tier.toJson(),
        'durationMinutes': durationMinutes,
        'priceCents': priceCents,
        'currency': currency,
        'price': price,
        'duration': duration,
        'label': label,
      };
}

/// `BoostStatusModel` — current user's active boost.
/// `tier` and `expiresAt` are `oneOf: [..., null]` — both nullable in Dart.
class BoostStatusModel {
  BoostStatusModel({
    required this.active,
    this.tier,
    this.expiresAt,
  });

  final bool active;
  final BoostTier? tier;
  final DateTime? expiresAt;

  factory BoostStatusModel.fromJson(Map<String, dynamic> json) =>
      BoostStatusModel(
        active: json['active'] as bool? ?? false,
        tier: BoostTier.fromJson(json['tier']),
        expiresAt: parseIsoDate(json['expiresAt']),
      );

  Map<String, dynamic> toJson() => {
        'active': active,
        'tier': tier?.toJson(),
        'expiresAt': encodeIsoDate(expiresAt),
      };
}

/// `BoostPurchaseRequest` — `POST /boost/purchase` body.
class BoostPurchaseRequest {
  BoostPurchaseRequest({required this.tier});

  final BoostTier tier;

  Map<String, dynamic> toJson() => {'tier': tier.toJson()};

  factory BoostPurchaseRequest.fromJson(Map<String, dynamic> json) =>
      BoostPurchaseRequest(
        tier: BoostTier.fromJson(json['tier']) ?? BoostTier.bronze,
      );
}

/// `BoostPurchaseResponse` — `{ url: string }`. Empty string disables redirect.
class BoostPurchaseResponse {
  BoostPurchaseResponse({required this.url});

  final String url;

  factory BoostPurchaseResponse.fromJson(Map<String, dynamic> json) =>
      BoostPurchaseResponse(url: json['url'] as String? ?? '');

  Map<String, dynamic> toJson() => {'url': url};
}

/// `BoostPlansResponse` — `{ plans: BoostPlanModel[] }` wrapper.
class BoostPlansResponse {
  BoostPlansResponse({required this.plans});

  final List<BoostPlanModel> plans;

  factory BoostPlansResponse.fromJson(Map<String, dynamic> json) =>
      BoostPlansResponse(
        plans: coerceList(json['plans'], BoostPlanModel.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'plans': plans.map((p) => p.toJson()).toList(),
      };
}
