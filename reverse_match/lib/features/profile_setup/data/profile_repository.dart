// Phase 1.8 — repository unification.
//
// The canonical profile repository now lives in
// `features/profile/data/profile_repository.dart` and goes through the
// generated `ReverseMatchApiClient`. This file is a thin re-export shim
// kept so existing imports
// (`../../../profile_setup/data/profile_repository.dart`) continue to
// compile while we update screens incrementally.
//
// New code should import the canonical path directly:
//   `package:.../features/profile/data/profile_repository.dart`.

export '../../profile/data/profile_repository.dart';
