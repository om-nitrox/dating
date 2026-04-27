# Deployment Roadmap — Reverse Match

**Scope:** External services setup, infrastructure provisioning, CI/CD pipelines, legal, app store submission.  
**This agent does NOT touch backend/ or reverse_match/ code** except where explicitly noted (e.g., CI YAML files).

---

## Execution order (strict — each phase unblocks the next)

```
Phase 1: External Services Setup        ← unblocks Flutter + Backend agents
Phase 2: Production Infrastructure     ← unblocks Phase 3
Phase 3: Fix CI + Build CD Pipelines   ← unblocks Phase 4
Phase 4: Legal & Compliance            ← unblocks Phase 5
Phase 5: App Store Submission Prep     ← final gate before launch
```

---

## Phase 1 — External Services Setup (P0, do first — other agents are blocked on this)

### 1.1 Firebase project `[UNBLOCKS: Flutter FCM, Backend Firebase, Google OAuth]`

1. Go to [Firebase Console](https://console.firebase.google.com) → **Create a project** → name it `reverse-match-prod`.
2. **Enable Firebase Cloud Messaging (FCM):**
   - Project Settings → Cloud Messaging → Confirm FCM API v1 is enabled.
3. **Android app:**
   - Add app → Android → package name: `com.reversematch.reverse_match`
   - Download `google-services.json` → hand it to Flutter agent to place at `reverse_match/android/app/google-services.json`
4. **iOS app:**
   - Add app → iOS → bundle ID: `com.reversematch.reverse_match`
   - Download `GoogleService-Info.plist` → hand it to Flutter agent to place at `reverse_match/ios/Runner/GoogleService-Info.plist`
   - Upload APNs key: Project Settings → Cloud Messaging → iOS → upload `.p8` APNs Auth Key (requires Apple Developer account — coordinate with Phase 5)
5. **Backend service account:**
   - Project Settings → Service Accounts → Generate new private key → download JSON
   - In backend `.env`, set:
     ```
     FIREBASE_SERVICE_ACCOUNT_JSON=<paste entire JSON as a single-line escaped string>
     ```
   - OR store the file as `backend/serviceAccountKey.json` (add to `.gitignore`) and reference via path.

**Output to share:** `google-services.json`, `GoogleService-Info.plist`, service account JSON path/env var.

---

### 1.2 Sentry project `[UNBLOCKS: Backend Sentry DSN, Flutter Sentry DSN]`

1. Sign up / log in at [sentry.io](https://sentry.io).
2. Create two projects:
   - **`reverse-match-backend`** (platform: Node.js)
   - **`reverse-match-flutter`** (platform: Flutter)
3. Copy DSN for each project.
4. Backend: set in `backend/.env`:
   ```
   SENTRY_DSN=https://xxx@o0.ingest.sentry.io/backend-project-id
   ```
5. Flutter: add to `reverse_match/.env`, `.env.staging`, `.env.production`:
   ```
   SENTRY_DSN=https://xxx@o0.ingest.sentry.io/flutter-project-id
   ```

---

### 1.3 Cloudinary production account `[UNBLOCKS: Photo upload in production]`

1. Create account at [cloudinary.com](https://cloudinary.com) (Starter plan is free up to quota).
2. From Dashboard, copy: `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`.
3. Set in `backend/.env.production`:
   ```
   CLOUDINARY_CLOUD_NAME=your-cloud-name
   CLOUDINARY_API_KEY=your-api-key
   CLOUDINARY_API_SECRET=your-api-secret
   CLOUDINARY_MODERATION=aws_rek   # or 'webpurify' — paid add-on
   ```
4. **Enable AI moderation add-on** (required for a dating app):
   - Dashboard → Add-ons → Rekognition AI Moderation (Amazon) or WebPurify
   - This flags NSFW content automatically on upload
5. Create an upload preset named `profile_photos` with:
   - Folder: `profile_photos/`
   - Transformations: max 1200px width, quality auto
   - Moderation: enabled (set to the add-on chosen above)

---

### 1.4 SendGrid / SMTP `[UNBLOCKS: Real OTP emails in backend]`

Currently backend uses `nodemailer` with console-logged OTPs in dev.

1. Create account at [sendgrid.com](https://sendgrid.com) (free tier: 100 emails/day).
2. Verify your sending domain (DNS setup — add CNAME records to your domain registrar).
3. Create an API key with "Mail Send" permission.
4. Set in `backend/.env.production`:
   ```
   SMTP_HOST=smtp.sendgrid.net
   SMTP_PORT=587
   SMTP_USER=apikey
   SMTP_PASS=SG.your-sendgrid-api-key
   EMAIL_FROM=noreply@yourdomain.com
   ```

---

### 1.5 Google OAuth 2.0 `[UNBLOCKS: Flutter Google Sign-In]`

1. Go to [Google Cloud Console](https://console.cloud.google.com) → select your Firebase project (they share the same GCP project).
2. APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client ID.
3. Create **3 client IDs**:
   - **Web application** (used by backend to verify tokens): Authorized origins = `https://api.yourdomain.com`
   - **Android**: package name = `com.reversematch.reverse_match`, SHA-1 of release keystore (coordinate with Android signing step 1.6)
   - **iOS**: bundle ID = `com.reversematch.reverse_match`
4. Set in `backend/.env.production`:
   ```
   GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   ```
5. Set in `reverse_match/.env.production`:
   ```
   GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   ```
6. Add the Android and iOS client IDs to the Flutter `google-services.json` and `GoogleService-Info.plist` — these are usually auto-populated if you added them through Firebase Console.

---

### 1.6 Android signing keystore `[UNBLOCKS: Flutter Android release build]`

Run this on your local machine (keep the keystore file SECURE — back it up):
```bash
keytool -genkey -v \
  -keystore ~/reverse-match-release.jks \
  -alias reverse-match \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

Create `reverse_match/android/key.properties` (add to `.gitignore`):
```
storePassword=<password you set>
keyPassword=<password you set>
keyAlias=reverse-match
storeFile=/absolute/path/to/reverse-match-release.jks
```

Copy the SHA-1 fingerprint of this keystore and add it to:
- Firebase Console → Android app → Add fingerprint
- Google Cloud Console → Android OAuth client ID → SHA-1

Hand the `key.properties` content and `.jks` file path to the Flutter agent (Phase 5.1 in Flutter roadmap).

---

### 1.7 Stripe production setup `[UNBLOCKS: Real payments]`

1. In Stripe Dashboard: switch to **Live mode** (toggle at top of dashboard).
2. Copy live keys:
   ```
   STRIPE_SECRET_KEY=sk_live_xxx
   STRIPE_PUBLISHABLE_KEY=pk_live_xxx
   ```
3. Create a webhook endpoint:
   - Stripe Dashboard → Developers → Webhooks → Add endpoint
   - URL: `https://api.yourdomain.com/api/v1/boost/webhook`
   - Events to listen for: `checkout.session.completed`, `payment_intent.payment_failed`
4. Copy the webhook signing secret:
   ```
   STRIPE_WEBHOOK_SECRET=whsec_xxx
   ```
5. Set all three in `backend/.env.production`.

---

## Phase 2 — Production Infrastructure

### 2.1 Domain name

Purchase `reversematch.app` (or `reversematch.co`, `reversematch.io`) from Namecheap / Google Domains (~$12/yr).

Configure DNS on Cloudflare (free):
- Transfer nameservers to Cloudflare
- Add A records pointing to your API server IP (set after provisioning compute)
- `api.yourdomain.com` → backend API
- `yourdomain.com` → (optional) landing page

---

### 2.2 MongoDB Atlas production cluster

1. [atlas.mongodb.com](https://cloud.mongodb.com) → Create project `reverse-match-prod`.
2. Create cluster: **M10 Dedicated** ($57/mo) — do NOT use M0 free tier for production.
3. Database access: Create user `reverse-match-api` with `readWriteAnyDatabase` role. Generate strong password.
4. Network access (IP allowlist):
   - During setup, temporarily allow `0.0.0.0/0` to test connection.
   - After provisioning compute (2.4), lock to VPC/private IPs only.
5. Enable automated backups: Cluster → Backup → Enable continuous backup.
6. Connection string (replace `<password>`):
   ```
   MONGO_URI=mongodb+srv://reverse-match-api:<password>@cluster0.xxxxx.mongodb.net/reverse_match?retryWrites=true&w=majority
   ```
7. Set in `backend/.env.production`.

---

### 2.3 Redis production

Option A — **Redis Cloud** (simplest, ~$5/mo for 100MB):
1. [redis.com/try-free](https://redis.com/try-free) → Create free database → upgrade to 100MB paid.
2. Get connection URL: `redis://:password@host:port`
3. Set in `backend/.env.production`:
   ```
   REDIS_URL=redis://:your-password@host:16379
   ```

Option B — **AWS ElastiCache** (if using AWS):
1. Create Redis cluster (cache.t3.micro, ~$15/mo).
2. Enable auth token (`requirepass` equivalent).
3. Ensure it's in the same VPC as your compute.

---

### 2.4 Compute — backend API server

**Recommended for a solo/small team: Railway or Render** (much simpler than ECS).

**Railway setup:**
1. [railway.app](https://railway.app) → New Project → Deploy from GitHub repo.
2. Select `backend/` as the root directory.
3. Set build command: `npm ci`
4. Set start command: `npm run start:prod`
5. Add all env vars from `backend/.env.production`.
6. Set custom domain: `api.yourdomain.com`
7. Railway provides automatic HTTPS via Let's Encrypt.

**Alternative — AWS ECS Fargate** (if you need more control):
1. Create ECR repository: `reverse-match-backend`
2. Create ECS cluster (Fargate)
3. Create task definition: 0.5 vCPU, 1GB RAM, image from ECR
4. Create ALB with HTTPS listener (ACM certificate)
5. Configure ALB to forward WebSocket upgrade headers for Socket.IO
6. Set environment variables via AWS Secrets Manager, not hardcoded

---

### 2.5 Lock MongoDB Atlas IP allowlist

After compute is provisioned and you have static IPs (or a NAT gateway IP):
1. Atlas → Network Access → Remove `0.0.0.0/0`
2. Add only the static IP(s) of your API server(s)

---

## Phase 3 — CI/CD Pipelines

### 3.1 Fix backend CI

**File:** `.github/workflows/ci.yml`

The current `lint` and `test` steps are no-op `echo` commands. Update them (these will work once the backend agent completes Phase 1):

```yaml
- name: Install dependencies
  run: npm ci
  working-directory: backend

- name: Run linter
  run: npm run lint
  working-directory: backend

- name: Run tests
  run: npm test -- --coverage
  working-directory: backend
  env:
    NODE_ENV: test
    # Use in-memory MongoDB via mongodb-memory-server — no env vars needed for MONGO_URI
    REDIS_URL: redis://localhost:6379
    JWT_SECRET: test-secret-do-not-use-in-prod
    JWT_REFRESH_SECRET: test-refresh-secret
```

Also add a coverage enforcement step:
```yaml
- name: Check coverage threshold
  run: npx jest --coverage --coverageThreshold='{"global":{"lines":70}}'
  working-directory: backend
```

---

### 3.2 Backend CD pipeline

Create `.github/workflows/deploy-backend.yml`:

```yaml
name: Deploy Backend

on:
  push:
    branches: [main]
    paths: [backend/**]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t reverse-match-backend:${{ github.sha }} ./backend

      - name: Push to GHCR
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
          docker tag reverse-match-backend:${{ github.sha }} ghcr.io/${{ github.repository }}/backend:${{ github.sha }}
          docker push ghcr.io/${{ github.repository }}/backend:${{ github.sha }}
          docker tag reverse-match-backend:${{ github.sha }} ghcr.io/${{ github.repository }}/backend:latest
          docker push ghcr.io/${{ github.repository }}/backend:latest

  deploy-staging:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Deploy to staging
        # Use Railway/Render CLI or SSH deploy script
        run: railway up --service backend
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production  # requires manual approval in GitHub repo settings
    steps:
      - name: Deploy to production
        run: railway up --service backend --environment production
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

**GitHub Secrets to set** (Settings → Secrets → Actions):
- `RAILWAY_TOKEN` — Railway API token
- All production env vars (or use Railway's env var management)

**GitHub Environments to create** (Settings → Environments):
- `staging` — no approval required
- `production` — require review from 1 reviewer before deploy

---

### 3.3 Flutter CI pipeline

Create `.github/workflows/flutter-ci.yml`:

```yaml
name: Flutter CI

on:
  push:
    branches: [main, develop]
    paths: [reverse_match/**]
  pull_request:
    paths: [reverse_match/**]

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: stable

      - name: Install dependencies
        run: flutter pub get
        working-directory: reverse_match

      - name: Create .env file
        run: |
          echo "API_BASE_URL=https://staging.api.yourdomain.com" > .env
          echo "SENTRY_DSN=" >> .env
          echo "GOOGLE_CLIENT_ID=${{ secrets.GOOGLE_CLIENT_ID }}" >> .env
        working-directory: reverse_match

      - name: Run analyzer
        run: flutter analyze
        working-directory: reverse_match

      - name: Run tests
        run: flutter test
        working-directory: reverse_match
```

---

### 3.4 Flutter CD pipeline — Android

Create `.github/workflows/flutter-deploy-android.yml`:

```yaml
name: Flutter Deploy Android

on:
  push:
    tags: ['v*']

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Create .env.production
        run: |
          echo "API_BASE_URL=https://api.yourdomain.com" > .env.production
          echo "SENTRY_DSN=${{ secrets.SENTRY_DSN_FLUTTER }}" >> .env.production
          echo "GOOGLE_CLIENT_ID=${{ secrets.GOOGLE_CLIENT_ID }}" >> .env.production
        working-directory: reverse_match

      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > reverse-match.jks
          echo "storePassword=${{ secrets.KEYSTORE_PASSWORD }}" > key.properties
          echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> key.properties
          echo "keyAlias=${{ secrets.KEY_ALIAS }}" >> key.properties
          echo "storeFile=$(pwd)/reverse-match.jks" >> key.properties
        working-directory: reverse_match/android

      - name: Build release AAB
        run: flutter build appbundle --release --dart-define=ENV=production
        working-directory: reverse_match

      - name: Upload to Play Store (internal track)
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.reversematch.reverse_match
          releaseFiles: reverse_match/build/app/outputs/bundle/release/*.aab
          track: internal
```

**GitHub Secrets needed for Android CD:**
- `KEYSTORE_BASE64` — base64-encoded `.jks` file (`base64 -i reverse-match.jks`)
- `KEYSTORE_PASSWORD` — keystore password
- `KEY_PASSWORD` — key password
- `KEY_ALIAS` — key alias (e.g., `reverse-match`)
- `GOOGLE_PLAY_SERVICE_ACCOUNT` — Google Play service account JSON (from Google Play Console)

---

### 3.5 Flutter CD pipeline — iOS

Create `.github/workflows/flutter-deploy-ios.yml`:

```yaml
name: Flutter Deploy iOS

on:
  push:
    tags: ['v*']

jobs:
  build-ios:
    runs-on: macos-latest  # iOS builds require macOS runner
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Install Apple certificates and profiles
        uses: apple-actions/import-codesign-certs@v3
        with:
          p12-file-base64: ${{ secrets.IOS_DISTRIBUTION_CERT_P12 }}
          p12-password: ${{ secrets.IOS_DISTRIBUTION_CERT_PASSWORD }}

      - name: Install provisioning profile
        uses: apple-actions/download-provisioning-profiles@v3
        with:
          bundle-id: com.reversematch.reverse_match
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}

      - name: Build iOS release
        run: flutter build ios --release --no-codesign --dart-define=ENV=production
        working-directory: reverse_match

      - name: Archive and upload to TestFlight
        run: |
          xcodebuild -workspace ios/Runner.xcworkspace \
            -scheme Runner \
            -configuration Release \
            -archivePath build/Runner.xcarchive \
            archive
          xcodebuild -exportArchive \
            -archivePath build/Runner.xcarchive \
            -exportPath build/Runner.ipa \
            -exportOptionsPlist ios/ExportOptions.plist
        working-directory: reverse_match

      - name: Upload to TestFlight
        uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: reverse_match/build/Runner.ipa/reverse_match.ipa
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}
```

**GitHub Secrets needed for iOS CD:**
- `IOS_DISTRIBUTION_CERT_P12` — Distribution certificate as base64 P12
- `IOS_DISTRIBUTION_CERT_PASSWORD` — P12 password
- `APPSTORE_ISSUER_ID` — App Store Connect API issuer ID
- `APPSTORE_API_KEY_ID` — App Store Connect API key ID
- `APPSTORE_API_PRIVATE_KEY` — App Store Connect API private key (`.p8` content)

---

## Phase 4 — Legal & Compliance (P0 — app stores reject without these)

### 4.1 Privacy Policy

**Must be hosted at a public URL** before app store submission. Write and host at `https://yourdomain.com/privacy`.

Required sections:
- What data is collected: name, phone, date of birth, photos, location, device ID
- Third-party services: Cloudinary (photo storage), Firebase (push notifications + auth), Stripe (payments), Sentry (error tracking)
- Location data: used for nearby matching, not stored beyond session
- Right to deletion: how to delete account and all data
- Contact email for privacy requests
- Effective date

**Quick hosting option:** Use a simple static page on Cloudflare Pages or a GitHub Pages site until you have a proper landing page.

---

### 4.2 Terms of Service

Host at `https://yourdomain.com/terms`. Key clauses:
- Age requirement: 18+ only
- Acceptable use (no harassment, no fake profiles)
- Content moderation policy
- Paid features (Boost) — no refunds policy or refund conditions
- Account termination conditions

---

### 4.3 Age verification enforcement

**Backend:** Confirm backend agent has completed Phase 2, task 2.3 (rejects `dateOfBirth` < 18).  
**Flutter:** Confirm Flutter agent has completed Phase 2, task 2.1 (UI blocks underage users).

Backend `.env`:
```
PRIVACY_POLICY_URL=https://yourdomain.com/privacy
TERMS_URL=https://yourdomain.com/terms
```

These URLs should be returned by the `GET /api/v1/health` or a dedicated `/api/v1/legal` endpoint so the app can display them without hardcoding.

---

## Phase 5 — App Store Submission

### 5.1 Apple Developer account

1. Enroll at [developer.apple.com](https://developer.apple.com) ($99/yr).
2. Register App ID: `com.reversematch.reverse_match` with capabilities: Push Notifications, Sign In with Apple (optional).
3. Create **Distribution Certificate** (for App Store builds).
4. Create **App Store Provisioning Profile** linked to your App ID + Distribution cert.
5. Export `.p12` from Keychain → encode to base64 → store as GitHub Secret `IOS_DISTRIBUTION_CERT_P12`.
6. Create App Store Connect API key (for CI use): App Store Connect → Users & Access → Keys → Generate.

---

### 5.2 Google Play Console

1. Create account at [play.google.com/console](https://play.google.com/console) ($25 one-time).
2. Create app: name "Reverse Match", default language English.
3. Complete **Data safety form**: declare all data types collected (location, photos, contacts via phone number, financial info via Stripe).
4. Set content rating: complete the rating questionnaire (expect PEGI 18 / AO for dating apps).
5. Create Service Account for CI:
   - Play Console → Setup → API access → Link to Google Cloud project → Create service account
   - Grant "Release manager" role
   - Download JSON key → store as GitHub Secret `GOOGLE_PLAY_SERVICE_ACCOUNT`

---

### 5.3 TestFlight beta (iOS)

Before submitting to App Store:
1. Upload first build via CI pipeline or Xcode.
2. Invite internal testers (your team, up to 100) for 1–2 weeks testing.
3. Fix any crash reports from Sentry + TestFlight feedback.
4. Then submit for App Store Review.

---

### 5.4 Play Store internal testing (Android)

Before publishing to production:
1. Upload AAB to Internal Testing track via CI pipeline.
2. Add internal testers by email.
3. Test on physical devices (Samsung + Pixel recommended).
4. Promote to Closed Beta, then Open Beta, then Production.

---

### 5.5 App Store listing assets (prepare before submission)

**Android — required:**
- App icon: 512×512 PNG (no transparency)
- Feature graphic: 1024×500 PNG
- Screenshots: at least 4 for each screen size (phone + tablet if supported)
- Short description: ≤80 characters
- Full description: ≤4000 characters

**iOS — required:**
- Screenshots: 6.5" iPhone (1284×2778) and 5.5" iPhone (1242×2208)
- App preview video: optional but recommended for dating apps
- App description and keywords (100 chars for keywords)
- Support URL: `https://yourdomain.com/support`
- Privacy Policy URL: `https://yourdomain.com/privacy`

---

## Phase 6 — Monitoring

### 6.1 Uptime monitoring (free)

1. Sign up at [uptimerobot.com](https://uptimerobot.com) (free tier).
2. Add monitor: HTTP(S) → `https://api.yourdomain.com/health` → check every 5 minutes.
3. Set alert: email `omswork26@gmail.com` if status != 200.

---

### 6.2 Error tracking verification

After deploying:
1. Confirm backend Sentry DSN is active: trigger a test error, verify it appears in Sentry dashboard.
2. Confirm Flutter Sentry DSN is active: build a debug/staging build, throw a test exception, verify it appears.

---

## Summary — Cross-agent dependency graph

```
Deployment Phase 1.1 (Firebase)
    → Flutter can wire FCM (Flutter Phase 1.1)
    → Flutter can wire Google Sign-In (Flutter Phase 1.2)
    → Backend validates Google tokens (Backend Phase 4)

Deployment Phase 1.2 (Sentry)
    → Flutter can initialize Sentry (Flutter Phase 1.6)
    → Backend Sentry DSN is real (Backend already configured, just needs real DSN)

Deployment Phase 1.4 (SMTP)
    → Backend can send real OTP emails (Backend Phase 3.7)

Deployment Phase 1.6 (Android keystore)
    → Flutter agent can configure release signing (Flutter Phase 5.1)

Backend Phase 2.3 (Age API)
    → Flutter can enforce age gate (Flutter Phase 2.1)

Backend Phase 1 complete (tests passing)
    → Deployment Phase 3.1 (CI fix) makes sense to deploy
```

---

## Deliverables checklist

**Phase 1 — External Services**
- [ ] Firebase project created, `google-services.json` + `GoogleService-Info.plist` + service account JSON ready
- [ ] Sentry backend DSN + Flutter DSN set in env files
- [ ] Cloudinary production account + AI moderation enabled
- [ ] SendGrid account verified, API key in backend `.env.production`
- [ ] Google OAuth client IDs created (Web + Android + iOS)
- [ ] Android release keystore generated, `key.properties` created
- [ ] Stripe live keys + webhook secret in backend `.env.production`

**Phase 2 — Infrastructure**
- [ ] Domain registered, DNS on Cloudflare
- [ ] MongoDB Atlas M10+ cluster provisioned, connection string in `.env.production`
- [ ] Redis production instance provisioned with password
- [ ] Compute provisioned (Railway / ECS), HTTPS configured
- [ ] MongoDB Atlas IP allowlist locked to server IPs only

**Phase 3 — CI/CD**
- [ ] Backend CI `lint` and `test` steps are real (not echo)
- [ ] Backend CD: Docker build → GHCR push → staging → manual gate → prod
- [ ] Flutter CI: `flutter analyze` + `flutter test` on every PR
- [ ] Flutter CD Android: AAB built and uploaded to Play Store internal track on tag
- [ ] Flutter CD iOS: IPA built and uploaded to TestFlight on tag
- [ ] All secrets stored in GitHub Actions Secrets (never hardcoded)

**Phase 4 — Legal**
- [ ] Privacy Policy live at public URL
- [ ] Terms of Service live at public URL
- [ ] Age 18+ enforced in both backend and Flutter

**Phase 5 — App Stores**
- [ ] Apple Developer account enrolled ($99)
- [ ] App ID registered, Push Notifications enabled
- [ ] Distribution certificate + provisioning profile created
- [ ] Google Play Console account created ($25)
- [ ] Data safety form completed
- [ ] Content rating completed (PEGI 18 / AO)
- [ ] TestFlight internal beta tested (iOS)
- [ ] Play Store internal testing completed (Android)
- [ ] All listing assets prepared (icons, screenshots, descriptions)
