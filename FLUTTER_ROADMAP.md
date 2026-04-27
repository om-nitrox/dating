# Flutter Roadmap — Reverse Match

**Stack:** Flutter 3 / Dart / Riverpod / GoRouter / Dio  
**Root:** `reverse_match/`  
**Agent scope:** Everything inside `reverse_match/`. Do NOT touch `backend/`.

---

## Cross-dependency gates (wait for these before starting tagged tasks)

| Tag | What you need first | Provided by |
|-----|---------------------|-------------|
| `[NEEDS-FIREBASE]` | `google-services.json` (Android) + `GoogleService-Info.plist` (iOS) dropped into the correct paths | Deployment agent — Firebase project setup |
| `[NEEDS-SENTRY-DSN]` | Sentry DSN string | Deployment agent — Sentry project setup |
| `[NEEDS-AGE-API]` | Backend age verification on signup endpoint deployed | Backend agent — Phase 2, task 2.3 |
| `[NEEDS-GOOGLE-CLIENT-ID]` | OAuth 2.0 Web client ID + Android client ID from Google Cloud Console | Deployment agent — Google OAuth setup |
| `[NEEDS-KEYSTORE]` | `key.properties` file and keystore `.jks` file | Deployment agent — Android signing setup |

For all other tasks: start immediately, no external blockers.

---

## Phase 1 — Integrations (P0, do first)

### 1.1 Firebase push notifications `[NEEDS-FIREBASE]`

**Files to modify:**
- `pubspec.yaml`
- `lib/main.dart`
- `lib/core/services/firebase_messaging_service.dart`
- `android/app/build.gradle.kts` (apply google-services plugin)
- `android/build.gradle.kts` (add google-services classpath)

**Step 1 — Add packages to `pubspec.yaml`:**
```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
```

**Step 2 — Wire Android build files:**

In `android/build.gradle.kts` (project-level), add to `plugins` block or `buildscript.dependencies`:
```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```

In `android/app/build.gradle.kts`, add to `plugins` block:
```kotlin
id("com.google.gms.google-services")
```

Place `google-services.json` at `android/app/google-services.json`.

**Step 3 — Wire iOS:**  
Place `GoogleService-Info.plist` at `ios/Runner/GoogleService-Info.plist`.  
In Xcode (or via `ios/Runner/Info.plist`), add push notification capability — but since this is code-only, note it in a comment for manual Xcode step.

**Step 4 — Update `lib/main.dart`:**

Replace the commented-out Firebase block with real initialization:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/services/firebase_messaging_service.dart';

// In main() async, after WidgetsFlutterBinding.ensureInitialized():
await Firebase.initializeApp();
await FirebaseMessagingService.initialize();
```

**Step 5 — Implement `lib/core/services/firebase_messaging_service.dart`:**

The file already exists. Implement these three cases:
```dart
class FirebaseMessagingService {
  static Future<void> initialize() async {
    // Request permission (iOS)
    await FirebaseMessaging.instance.requestPermission();

    // Get FCM token and send to backend
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _sendTokenToBackend(token);

    // Token refresh
    FirebaseMessaging.instance.onTokenRefresh
        .listen((newToken) => _sendTokenToBackend(newToken));

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background messages (app in background, notification tapped)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Terminated state (app was closed, user tapped notification)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleMessageOpenedApp(initialMessage);
  }

  static Future<void> _sendTokenToBackend(String token) async {
    // Call PATCH /api/v1/profile with { fcmToken: token, deviceId: deviceId }
    // Use SecureStorageService to get auth token for the request
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    // Show local notification using flutter_local_notifications (add package)
    // OR show an in-app snackbar/banner
  }

  static void _handleMessageOpenedApp(RemoteMessage message) {
    // Navigate based on message.data['type']:
    // 'new_match' → /matches
    // 'new_message' → /chat/:matchId
    // 'queue_update' → /queue (boy home)
  }
}
```

---

### 1.2 Google Sign-In wiring `[NEEDS-GOOGLE-CLIENT-ID]`

**Files:** `lib/features/auth/presentation/screens/login_screen.dart`, `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/presentation/providers/auth_provider.dart`

`google_sign_in: ^6.2.2` is already in `pubspec.yaml`.

**Implementation:**
```dart
// In auth_repository.dart, add:
Future<String?> getGoogleIdToken() async {
  final googleSignIn = GoogleSignIn(
    clientId: dotenv.env['GOOGLE_CLIENT_ID'], // web client ID for iOS
    scopes: ['email', 'profile'],
  );
  final account = await googleSignIn.signIn();
  if (account == null) return null;
  final auth = await account.authentication;
  return auth.idToken;
}

// In auth_provider.dart:
Future<void> loginWithGoogle() async {
  final idToken = await _authRepository.getGoogleIdToken();
  if (idToken == null) return; // user cancelled
  final result = await _authRepository.googleLogin(idToken);
  // handle result (same as OTP login result)
}
```

**`.env` file** — add:
```
GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

**Android:** The SHA-1 fingerprint of your debug keystore must be added to Firebase console AND Google Cloud Console for Android OAuth to work. Note this as a manual step for the developer.

---

### 1.3 Deep link handling — Android

**File:** `android/app/src/main/AndroidManifest.xml`

Add inside the `<activity>` tag (below the existing LAUNCHER intent-filter):
```xml
<!-- Deep links for Stripe return -->
<intent-filter android:autoVerify="false">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="reversematch" />
</intent-filter>
```

Also add `INTERNET` permission if not present:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

---

### 1.4 Deep link handling — iOS

**File:** `ios/Runner/Info.plist`

Add inside the root `<dict>`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>reversematch</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.reversematch.app</string>
    </dict>
</array>
```

---

### 1.5 Stripe deep-link return handling

**File:** `lib/features/boost/presentation/screens/boost_screen.dart`, `lib/core/router/app_router.dart`

After the Android + iOS deep link config is in place, handle the return URL in the router:

In `app_router.dart`, add a route for the deep link:
```dart
GoRoute(
  path: '/boost/success',
  builder: (context, state) => const BoostSuccessScreen(),
),
GoRoute(
  path: '/boost/cancel',
  builder: (context, state) => const BoostCancelScreen(),
),
```

In `main.dart`, add a URI link listener (use `app_links` package or `uni_links`):
```yaml
# pubspec.yaml
dependencies:
  app_links: ^6.1.1
```

```dart
// In main.dart or a dedicated deep_link_service.dart:
AppLinks().uriLinkStream.listen((uri) {
  if (uri.scheme == 'reversematch' && uri.host == 'boost') {
    if (uri.path == '/success') {
      // Navigate to success screen and invalidate boost provider
    } else if (uri.path == '/cancel') {
      // Navigate back to boost screen with error message
    }
  }
});
```

---

### 1.6 Sentry crash tracking `[NEEDS-SENTRY-DSN]`

**Files:** `pubspec.yaml`, `lib/main.dart`

**Step 1 — Add package:**
```yaml
dependencies:
  sentry_flutter: ^8.10.1
```

**Step 2 — Update `main.dart`:**

Remove the commented-out Sentry block and replace with real implementation:
```dart
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... dotenv + Firebase init ...

  await SentryFlutter.init(
    (options) {
      options.dsn = dotenv.env['SENTRY_DSN'] ?? '';
      options.tracesSampleRate = 0.1; // 10% of transactions
      options.environment = const String.fromEnvironment('ENV', defaultValue: 'development');
    },
    appRunner: () => _runApp(),
  );
}

void _runApp() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  runZonedGuarded(
    () { runApp(const ProviderScope(child: ReverseMatchApp())); },
    (error, stackTrace) { Sentry.captureException(error, stackTrace: stackTrace); },
  );
}
```

**Step 3 — Add to `.env`:**
```
SENTRY_DSN=https://your-dsn@o0.ingest.sentry.io/0
```

---

### 1.7 Location permissions runtime request

**Files:** `lib/features/onboarding/presentation/screens/location_screen.dart` (or wherever location is requested)

`geolocator` and `permission_handler` are already in `pubspec.yaml`.

Required `Info.plist` entries (add to `ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Reverse Match uses your location to show you people nearby.</string>
```

Required `AndroidManifest.xml` permissions:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Runtime request pattern:
```dart
final permission = await Geolocator.requestPermission();
if (permission == LocationPermission.denied ||
    permission == LocationPermission.deniedForever) {
  // Show graceful degradation: allow user to enter city manually
  // Do NOT block the onboarding flow
  return;
}
final position = await Geolocator.getCurrentPosition();
// Send to backend as { lat: position.latitude, lng: position.longitude }
```

---

## Phase 2 — Age Gate UI `[NEEDS-AGE-API]`

### 2.1 Enforce 18+ in onboarding

**File:** `lib/features/onboarding/presentation/screens/dob_screen.dart`

When the user selects their date of birth:
1. Calculate age: `DateTime.now().difference(dob).inDays / 365.25`
2. If age < 18, show an error and disable the "Continue" button:
   ```
   "You must be 18 or older to use Reverse Match."
   ```
3. Do NOT allow navigation past this screen if underage.
4. The DOB value must be sent to the backend during signup (it is validated server-side too).

---

## Phase 3 — UI/UX Polish (P1)

### 3.1 Empty states

**File:** `lib/shared/widgets/empty_state_widget.dart` (already exists — wire it up)

Add empty state widgets to these screens:

**`girl_home_screen.dart`** (swipe feed):
```dart
if (profiles.isEmpty)
  EmptyStateWidget(
    icon: Icons.search_off_rounded,
    title: 'No one nearby',
    subtitle: 'Expand your distance or check back later.',
    action: TextButton(onPressed: refresh, child: const Text('Refresh')),
  )
```

**`matches_screen.dart`**:
```dart
if (matches.isEmpty)
  EmptyStateWidget(
    icon: Icons.favorite_border_rounded,
    title: 'No matches yet',
    subtitle: 'Keep swiping — your match is out there.',
  )
```

**`chat_screen.dart`** (message list empty):
```dart
if (messages.isEmpty)
  EmptyStateWidget(
    icon: Icons.chat_bubble_outline_rounded,
    title: 'Start the conversation',
    subtitle: 'Say hello!',
  )
```

---

### 3.2 Error states and retry UI

**Files:** All screens that make network calls via Riverpod providers

Replace "infinite spinner on error" with proper error handling. Pattern:
```dart
// In each AsyncValue.when():
error: (error, stack) => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
    const SizedBox(height: 16),
    Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    ElevatedButton(
      onPressed: () => ref.refresh(yourProvider),
      child: const Text('Try again'),
    ),
  ],
),
```

Screens that need this: swipe feed, matches list, chat messages, queue (boy home), profile edit.

---

### 3.3 Offline mode banner

**File:** `lib/core/network/connectivity_service.dart` (already exists), `lib/shared/widgets/` (create `offline_banner.dart`)

`connectivity_service.dart` exists — wire it to show a banner at the top of the app when offline.

In `ReverseMatchApp` widget (`main.dart`), wrap the `MaterialApp.router` with a `Consumer` that watches a connectivity provider:
```dart
// Create lib/core/providers/connectivity_provider.dart
final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityService().isConnectedStream;
});

// In build():
final isOnline = ref.watch(connectivityProvider).value ?? true;
return Stack(children: [
  MaterialApp.router(...),
  if (!isOnline) const Positioned(top: 0, left: 0, right: 0, child: OfflineBanner()),
]);
```

`OfflineBanner` — yellow bar: `"No internet connection"`.

---

### 3.4 Pull-to-refresh

**Files:** `girl_home_screen.dart`, `matches_screen.dart`, `boy_home_screen.dart`

Wrap scrollable content with `RefreshIndicator`:
```dart
RefreshIndicator(
  onRefresh: () async => ref.refresh(swipeFeedProvider),
  child: ListView.builder(...),
)
```

---

### 3.5 Dark mode verification

**File:** `lib/core/theme/app_theme.dart` — `AppTheme.dark()` is defined.

Manually verify these screens render correctly in dark mode (run the app with `ThemeMode.dark`):
- Login screen
- Onboarding screens (all steps)
- Swipe feed (profile cards)
- Matches list
- Chat screen
- Profile edit screen
- Boost screen

Fix any hardcoded `Colors.white` or `Colors.black` that don't respect the theme. Use `Theme.of(context).colorScheme.surface` and `Theme.of(context).colorScheme.onSurface` instead.

---

### 3.6 Image loading shimmer verification

**File:** `lib/shared/widgets/app_cached_image.dart`

`shimmer: 3.0.0` is in `pubspec.yaml`. Verify `app_cached_image.dart` uses shimmer as `placeholder`. If not:
```dart
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Container(color: Colors.white),
  ),
  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
)
```

Verify this widget is used on profile cards in swipe feed and in the chat avatar.

---

## Phase 4 — App Identity (P0 for release)

### 4.1 App icon

**Files:** `android/app/src/main/res/mipmap-*/`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/app_icon.png"  # 1024x1024 PNG, no transparency for iOS
  adaptive_icon_background: "#E91E8C"  # Brand color background for Android adaptive icon
  adaptive_icon_foreground: "assets/images/app_icon_foreground.png"
```

Place icon files in `assets/images/`. Then run:
```bash
dart run flutter_launcher_icons
```

---

### 4.2 Splash screen

**File:** `lib/features/splash/presentation/screens/splash_screen.dart` (exists)

Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_native_splash: ^2.4.1

flutter_native_splash:
  color: "#E91E8C"
  image: assets/images/splash_logo.png
  android_12:
    color: "#E91E8C"
    icon_background_color: "#E91E8C"
    image: assets/images/splash_logo.png
```

Place `splash_logo.png` (300x300 recommended) in `assets/images/`. Then run:
```bash
dart run flutter_native_splash:create
```

---

### 4.3 Lottie animations

**Directory:** `assets/lottie/` (declared in `pubspec.yaml` but may be empty)

Either:
- **Add real files:** Download free Lottie JSON files from LottieFiles for: match celebration, empty state, loading. Place them in `assets/lottie/`.
- **OR remove declaration** from `pubspec.yaml` and remove any `Lottie.asset(...)` calls that reference missing files. `lottie` package is NOT currently in `pubspec.yaml` so no package to remove — just clean up the asset declaration if directory is empty.

---

## Phase 5 — Release Configuration (P0 for store submission)

### 5.1 Android release config

**File:** `android/app/build.gradle.kts` `[NEEDS-KEYSTORE]`

**Step 1 — Bundle ID:** Current is `com.reversematch.reverse_match` — confirm this matches what was registered in Google Play Console. If the Play Console registration used a different ID, change it here and in `pubspec.yaml` (package name).

**Step 2 — Signing config:** Create `android/key.properties` (DO NOT commit this file — add to `.gitignore`):
```
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=<key alias>
storeFile=<absolute path to .jks file>
```

In `android/app/build.gradle.kts`, add signing config:
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
keyProperties.load(FileInputStream(keyPropertiesFile))

android {
    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

**Step 3 — ProGuard rules:** Create `android/app/proguard-rules.pro`:
```
# Riverpod
-keep class dev.rrousselgit.riverpod.** { *; }
# Dio
-keep class io.flutter.** { *; }
# Firebase
-keep class com.google.firebase.** { *; }
# JSON serializable models
-keep class com.reversematch.** { *; }
```

**Step 4 — Verify minSdkVersion:** Firebase requires minSdk ≥ 21. Check `android/local.properties` or `flutter.minSdkVersion` to confirm it's set to at least 21.

---

### 5.2 iOS release config

**Files:** `ios/Runner/Info.plist`, Xcode project settings (manual steps noted)

**Info.plist additions required:**
```xml
<!-- Location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Reverse Match uses your location to show you people nearby.</string>

<!-- Camera (for profile photos) -->
<key>NSCameraUsageDescription</key>
<string>Reverse Match needs camera access to take profile photos.</string>

<!-- Photo library -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Reverse Match needs photo library access to upload profile photos.</string>

<!-- Photo library additions (iOS 14+) -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Reverse Match needs to save photos to your library.</string>
```

**Manual steps (require Xcode or Apple Developer Portal):**
- Register bundle ID `com.reversematch.reverse_match` in Apple Developer Portal
- Enable Push Notifications capability in Xcode → Signing & Capabilities
- Create Distribution certificate and App Store provisioning profile
- Set `PRODUCT_BUNDLE_IDENTIFIER` to `com.reversematch.reverse_match`

---

## Phase 6 — Testing (P0/P1)

### 6.1 Unit tests

Create `reverse_match/test/unit/` directory.

**`test/unit/providers/auth_provider_test.dart`**:
- Test login with OTP: mock `auth_repository.dart`, verify state transitions (loading → authenticated)
- Test logout: verify tokens cleared from secure storage
- Test Google login: mock `getGoogleIdToken`, verify flow

**`test/unit/models/user_model_test.dart`**:
- Test `UserModel.fromJson` with complete and partial data
- Test `UserModel.toJson` round-trip

Use `mocktail` package:
```yaml
dev_dependencies:
  mocktail: ^1.0.4
```

---

### 6.2 Widget tests

Create `reverse_match/test/widget/` directory.

**`test/widget/swipe_card_test.dart`**:
- Renders user name, age, distance
- Shimmer shows during image load
- Empty state widget shows when list is empty

**`test/widget/match_list_test.dart`**:
- Renders match cards with last message
- Empty state shows when no matches

---

## Deliverables checklist

- [ ] Firebase packages added and initialized in `main.dart`
- [ ] `firebase_messaging_service.dart` handles foreground + background + terminated states
- [ ] FCM token sent to backend on login/token refresh
- [ ] Google Sign-In wired to auth provider
- [ ] `reversematch://` scheme registered in AndroidManifest + Info.plist
- [ ] Stripe deep-link return handled in router
- [ ] `app_links` package handles incoming URI stream
- [ ] Sentry initialized with real DSN from `.env`
- [ ] Location permission request with graceful degradation if denied
- [ ] Age gate UI blocks users under 18 in `dob_screen.dart`
- [ ] Empty state widget shown on swipe feed, matches, and chat
- [ ] Error state + retry button on all screens making network calls
- [ ] Offline banner shown app-wide when no connection
- [ ] Pull-to-refresh on swipe feed and matches list
- [ ] All screens verified in dark mode (no hardcoded colors)
- [ ] Shimmer used on profile cards and chat avatars
- [ ] Branded app icon generated for Android + iOS
- [ ] Native splash screen implemented
- [ ] Lottie directory has real files OR asset declaration removed
- [ ] Android bundle ID confirmed, signing config added to `build.gradle.kts`
- [ ] ProGuard rules added
- [ ] iOS Info.plist has all required permission strings
- [ ] `npm run flutter test` passes (unit + widget tests)
