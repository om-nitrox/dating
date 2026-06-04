import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_result.dart';
import '../../data/filter_repository.dart';
import '../../domain/discovery_filters.dart';

/// Holds the girl's active discovery filters. Loads the saved set from the
/// backend on creation; `apply` persists a new set and updates local state.
final discoveryFiltersProvider =
    StateNotifierProvider<DiscoveryFiltersNotifier, DiscoveryFilters>((ref) {
  return DiscoveryFiltersNotifier(ref.read(filterRepositoryProvider));
});

class DiscoveryFiltersNotifier extends StateNotifier<DiscoveryFilters> {
  final FilterRepository _repo;

  DiscoveryFiltersNotifier(this._repo) : super(const DiscoveryFilters()) {
    _load();
  }

  Future<void> _load() async {
    final res = await _repo.load();
    if (res is Success<DiscoveryFilters>) state = res.data;
  }

  /// Persist [filters]. Returns null on success, or an error message.
  Future<String?> apply(DiscoveryFilters filters) async {
    final res = await _repo.save(filters);
    if (res is Success<void>) {
      state = filters;
      return null;
    }
    return (res as Failure<void>).exception.message;
  }
}
