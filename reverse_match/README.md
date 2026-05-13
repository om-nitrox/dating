# reverse_match

Flutter mobile client for the Reverse Match dating platform.

## Setup (FVM)

The Flutter SDK version is pinned in `../.fvmrc` at the repo root — install [FVM](https://fvm.app/) and let it manage the SDK so every contributor and CI runner uses the exact same toolchain. Do **not** commit a vendored Flutter SDK.

```bash
# One-time, globally
dart pub global activate fvm

# From the repo root (reads .fvmrc)
fvm install

# Then, in this directory
cd reverse_match
fvm flutter pub get
fvm flutter run --dart-define=ENV=development
```

If you prefer not to use FVM, install Flutter manually at the version recorded in `../.fvmrc` and substitute `flutter` for `fvm flutter` in the commands above.

## Common commands

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter run --dart-define=ENV=development
fvm flutter run --dart-define=ENV=staging
fvm flutter run --dart-define=ENV=production
```

## Resources

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Flutter docs](https://docs.flutter.dev/)
