// Phase 1.8 — repository unification. Consumes ReverseMatchApiClient.
//
// The legacy boost screen kept a hand-rolled `BoostPlan` class (string-typed
// tier, integer price-in-cents). We preserve that public shape so the
// existing widget doesn't need a rewrite — just swap its data source.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reverse_match_api/reverse_match_api.dart' as api;

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';

final boostRepositoryProvider = Provider<BoostRepository>((ref) {
  return BoostRepository(ref.read(apiClientProvider).boost);
});

class BoostRepository {
  final api.BoostApi _boost;

  BoostRepository(this._boost);

  Future<ApiResult<List<BoostPlan>>> getPlans() async {
    try {
      final response = await _boost.listBoostPlans();
      return Success(response.plans.map(BoostPlan._fromApi).toList());
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to load boost plans'),
      );
    }
  }

  Future<ApiResult<BoostStatus>> getStatus() async {
    try {
      final response = await _boost.getBoostStatus();
      return Success(
        BoostStatus(
          active: response.active,
          tier: response.tier?.wire,
          expiresAt: response.expiresAt,
        ),
      );
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Failed to load boost status'),
      );
    }
  }

  /// `tier` is the wire-value string (`bronze` | `silver` | `gold`).
  Future<ApiResult<String>> purchase(String tier) async {
    try {
      final boostTier =
          api.BoostTier.fromJson(tier) ?? api.BoostTier.bronze;
      final response =
          await _boost.purchaseBoost(api.BoostPurchaseRequest(tier: boostTier));
      return Success(response.url);
    } on DioException catch (e) {
      return Failure(
        ServerException(_extractMessage(e) ?? 'Purchase failed'),
      );
    }
  }

  String? _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        final msg = err['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    }
    return null;
  }
}

/// Legacy-style boost plan card. The boost screen reads `tier`, `price`,
/// `duration`, `label`, `priceFormatted`, and `color` — preserved from the
/// pre-Phase-1.8 hand-rolled class.
class BoostPlan {
  final String tier;
  final int price; // in cents
  final int duration; // in minutes
  final String label;

  BoostPlan({
    required this.tier,
    required this.price,
    required this.duration,
    required this.label,
  });

  factory BoostPlan._fromApi(api.BoostPlanModel m) => BoostPlan(
        tier: m.tier.wire,
        price: m.priceCents,
        duration: m.durationMinutes,
        label: m.label,
      );

  String get priceFormatted => '\$${(price / 100).toStringAsFixed(2)}';

  Color get color {
    switch (tier) {
      case 'gold':
        return AppColors.gold;
      case 'silver':
        return AppColors.silver;
      case 'bronze':
        return AppColors.bronze;
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

class BoostStatus {
  final bool active;
  final String? tier;
  final DateTime? expiresAt;

  const BoostStatus({required this.active, this.tier, this.expiresAt});
}
