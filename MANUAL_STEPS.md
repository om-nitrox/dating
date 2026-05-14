# Manual Steps to Launch Reverse Match

This is the runbook for everything the codebase can't do for you — account creation, payments, app store registration, DNS, and key generation. Work top-to-bottom; each phase unblocks the next. For every step, the canonical reference is the matching section in [`DEPLOYMENT_ROADMAP.md`](./DEPLOYMENT_ROADMAP.md).

**Estimated time:** ~12-16 hours of hands-on work spread over a week (most calendar time is waiting for verifications: domain DNS, SendGrid DNS, Apple enrollment, App Store review).
**Estimated cost:** ~$130 first-month, ~$135/mo recurring after. Breakdown:
- $99/yr Apple Developer
- $25 one-time Google Play
- ~$12/yr domain (Namecheap / Google Domains)
- ~$57/mo MongoDB Atlas M10 (no cheaper tier is production-safe)
- ~$5/mo Redis Cloud 100MB
- ~$0 first month on Firebase / Sentry / Cloudinary / SendGrid / UptimeRobot free tiers
- ~$5-20/mo Railway (depending on traffic)
- Stripe: pay-per-transaction, no monthly fee

---

## Phase 1 — External Services (DO FIRST — blocks both backend and Flutter)

### 1.1 Firebase project
Reference: `DEPLOYMENT_ROADMAP.md` §1.1.

- [ ] Sign in to [Firebase Console](https://console.firebase.google.com), **Create a project** named `reverse-match-prod`.
- [ ] Enable **Cloud Messaging (FCM)** under Project Settings → Cloud Messaging.
- [ ] Add **Android app**, package name `com.reversematch.reverse_match`, download `google-services.json`.
- [ ] Add **iOS app**, bundle ID `com.reversematch.reverse_match`, download `GoogleService-Info.plist`.
- [ ] Upload **APNs `.p8` Auth Key** (Project Settings → Cloud Messaging → iOS section).
- [ ] Generate a **service account JSON** (Project Settings → Service Accounts → Generate new private key).
- [ ] Add the SHA-1 fingerprint from step 1.6 to the Android app once you have it.

**Gotcha:** APNs key requires an active Apple Developer membership (Phase 5.1). You can do everything else in 1.1 first and circle back for the APNs upload after Phase 5.1 finishes.

**Outputs to save:**
- `google-services.json` → `reverse_match/android/app/google-services.json`
- `GoogleService-Info.plist` → `reverse_match/ios/Runner/GoogleService-Info.plist`
- Service account JSON → either set `FIREBASE_SERVICE_ACCOUNT_JSON` in `backend/.env.production` (escape to single-line) **or** save the file as `backend/serviceAccountKey.json` (already gitignored)

**Cost:** Free (Spark plan covers all current needs; FCM has no charge).

---

### 1.2 Sentry
Reference: `DEPLOYMENT_ROADMAP.md` §1.2.

- [ ] Sign up at [sentry.io](https://sentry.io).
- [ ] Create project `reverse-match-backend` (platform: Node.js). Copy DSN.
- [ ] Create project `reverse-match-flutter` (platform: Flutter). Copy DSN.
- [ ] Set in `backend/.env.production`:
  ```
  SENTRY_DSN=https://xxx@o0.ingest.sentry.io/<backend-project-id>
  ```
- [ ] Set in `reverse_match/.env`, `reverse_match/.env.staging`, `reverse_match/.env.production`:
  ```
  SENTRY_DSN=https://xxx@o0.ingest.sentry.io/<flutter-project-id>
  ```

**Cost:** Free Developer plan covers 5k events/mo. Upgrade to Team ($26/mo) only when you exceed that.

---

### 1.3 Cloudinary
Reference: `DEPLOYMENT_ROADMAP.md` §1.3.

- [ ] Create account at [cloudinary.com](https://cloudinary.com).
- [ ] From Dashboard, copy cloud name, API key, API secret.
- [ ] Set in `backend/.env.production`:
  ```
  CLOUDINARY_CLOUD_NAME=your-cloud-name
  CLOUDINARY_API_KEY=your-api-key
  CLOUDINARY_API_SECRET=your-api-secret
  CLOUDINARY_MODERATION=aws_rek
  ```
- [ ] **Enable AI moderation add-on** (Dashboard → Add-ons → Amazon Rekognition AI Moderation, or WebPurify). This is non-negotiable for a dating app.
- [ ] Create an upload preset named `profile_photos` (folder `profile_photos/`, max 1200px width, quality auto, moderation enabled).

**Gotcha:** Rekognition has a free tier (~500 moderations/mo). Beyond that it's pay-as-you-go.

**Cost:** Free tier until you hit 25 monthly credits of storage/transformations. Moderation add-on has its own small free tier then per-request pricing.

---

### 1.4 SendGrid / SMTP
Reference: `DEPLOYMENT_ROADMAP.md` §1.4.

- [ ] Create account at [sendgrid.com](https://sendgrid.com) (free: 100 emails/day).
- [ ] **Verify your sending domain** — add CNAME records SendGrid generates to your domain registrar (Cloudflare from §2.1). Allow 24-48h for DNS propagation.
- [ ] Create API key with "Mail Send" permission.
- [ ] Set in `backend/.env.production`:
  ```
  SMTP_HOST=smtp.sendgrid.net
  SMTP_PORT=587
  SMTP_USER=apikey
  SMTP_PASS=SG.your-sendgrid-api-key
  EMAIL_FROM=noreply@yourdomain.com
  ```

**Gotcha — SendGrid sandbox/single-sender limit:** Until your domain is verified, SendGrid will only send to addresses on the verified-sender list. Don't ship OTP emails until DNS verification completes.

**Cost:** Free up to 100/day. Essentials plan is $19.95/mo for 50k/mo when you outgrow free.

---

### 1.5 Google OAuth (Web + Android + iOS Client IDs)
Reference: `DEPLOYMENT_ROADMAP.md` §1.5.

- [ ] In [Google Cloud Console](https://console.cloud.google.com), select the GCP project Firebase created.
- [ ] APIs & Services → Credentials → Create OAuth client ID → **Web application** (authorized origin: `https://api.yourdomain.com`).
- [ ] Create **Android** OAuth client ID with package `com.reversematch.reverse_match` and SHA-1 from §1.6.
- [ ] Create **iOS** OAuth client ID with bundle ID `com.reversematch.reverse_match`.
- [ ] Set in `backend/.env.production` and `reverse_match/.env.production`:
  ```
  GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
  ```

**Gotcha:** The Android client ID requires the SHA-1 of your release keystore — finish §1.6 first or do this step after.

**Cost:** Free.

---

### 1.6 Android signing keystore
Reference: `DEPLOYMENT_ROADMAP.md` §1.6.

Run this in PowerShell on Windows (uses `keytool.exe` from your JDK — confirm with `where.exe keytool`):

```
keytool -genkeypair -v ^
  -keystore reverse-match-release.jks ^
  -alias reverse-match ^
  -keyalg RSA -keysize 2048 -validity 10000
```

- [ ] Generate the keystore. **Back it up somewhere safe** (1Password, encrypted USB) — losing it means you can never push another update to the same Play Store listing.
- [ ] Move `reverse-match-release.jks` to a location outside the repo, e.g. `C:\Users\agraw\keystores\reverse-match-release.jks`.
- [ ] Create `reverse_match/android/key.properties` (already in `.gitignore`):
  ```
  storePassword=<password you set>
  keyPassword=<password you set>
  keyAlias=reverse-match
  storeFile=C:/Users/agraw/keystores/reverse-match-release.jks
  ```
- [ ] Extract the SHA-1 fingerprint:
  ```
  keytool -list -v -keystore reverse-match-release.jks -alias reverse-match
  ```
- [ ] Add the SHA-1 to **Firebase Console** (Project Settings → Android app → Add fingerprint).
- [ ] Add the SHA-1 to **Google Cloud Console** Android OAuth client (§1.5).

**Gotcha:** Forward slashes in `storeFile` even on Windows — backslashes break Gradle's properties parser.

**Cost:** Free.

---

### 1.7 Stripe live keys + webhook
Reference: `DEPLOYMENT_ROADMAP.md` §1.7.

- [ ] In Stripe Dashboard, toggle to **Live mode** (top of dashboard).
- [ ] Copy live publishable + secret keys.
- [ ] Developers → Webhooks → Add endpoint → URL `https://api.yourdomain.com/api/v1/boost/webhook`, events `checkout.session.completed` and `payment_intent.payment_failed`.
- [ ] Copy the webhook signing secret.
- [ ] Set in `backend/.env.production`:
  ```
  STRIPE_SECRET_KEY=sk_live_xxx
  STRIPE_PUBLISHABLE_KEY=pk_live_xxx
  STRIPE_WEBHOOK_SECRET=whsec_xxx
  ```

**Gotcha:** Stripe requires identity / business verification before activating live mode — collect tax ID, bank info beforehand. This can take 1-3 business days.

**Cost:** No fixed fee; standard 2.9% + $0.30 per successful charge.

---

## Phase 2 — Infrastructure

### 2.1 Domain
Reference: `DEPLOYMENT_ROADMAP.md` §2.1.

- [ ] Purchase `reversematch.app` (or `.co`, `.io`) from Namecheap or Google Domains.
- [ ] Create a free [Cloudflare](https://cloudflare.com) account, add the domain.
- [ ] Transfer nameservers from the registrar to Cloudflare's.
- [ ] After §2.4 deploy, add A or CNAME records:
  - `api.yourdomain.com` → backend host
  - `yourdomain.com` → (optional) landing page or Cloudflare Pages for privacy/terms
- [ ] Verify DNS propagation: `nslookup api.yourdomain.com 1.1.1.1`

**Gotcha:** Nameserver transfer can take 24-48h to fully propagate. Don't start SendGrid DNS verification (§1.4) until nameservers are on Cloudflare.

**Cost:** ~$12/yr for `.app`/`.io`.

---

### 2.2 MongoDB Atlas M10
Reference: `DEPLOYMENT_ROADMAP.md` §2.2.

- [ ] Sign in to [cloud.mongodb.com](https://cloud.mongodb.com), create project `reverse-match-prod`.
- [ ] Create cluster: **M10 Dedicated** (~$57/mo). M0/M2/M5 are NOT production-safe (shared CPU, no backup SLA).
- [ ] Create DB user `reverse-match-api` with `readWriteAnyDatabase` role, strong password.
- [ ] Network Access: temporarily allow `0.0.0.0/0` during initial testing. Lock down in §2.5.
- [ ] Enable continuous backups.
- [ ] Build connection string template:
  ```
  MONGO_URI=mongodb+srv://reverse-match-api:<password>@cluster0.xxxxx.mongodb.net/reverse_match?retryWrites=true&w=majority
  ```
- [ ] Set `MONGO_URI` in `backend/.env.production`.

**Gotcha:** Atlas M10 has a 60-day commitment — you can scale up freely but downgrading back to M0 requires snapshot + new cluster.

**Cost:** ~$57/mo.

---

### 2.3 Redis Cloud
Reference: `DEPLOYMENT_ROADMAP.md` §2.3 (Option A).

- [ ] Sign up at [redis.com/try-free](https://redis.com/try-free).
- [ ] Create free 30MB DB, then upgrade to 100MB paid plan (~$5/mo).
- [ ] Copy connection URL.
- [ ] Set in `backend/.env.production`:
  ```
  REDIS_URL=redis://:your-password@host:16379
  ```

**Gotcha:** Free tier has no SLA and can be wiped without notice. Use a paid plan once you have real users.

**Cost:** ~$5/mo for 100MB.

---

### 2.4 Compute (Railway recommended)
Reference: `DEPLOYMENT_ROADMAP.md` §2.4.

`backend/Dockerfile` already exists, so any container host works. Railway is the lowest friction.

- [ ] Sign in to [railway.app](https://railway.app), create project, deploy from GitHub repo.
- [ ] Set root directory to `backend/`.
- [ ] Build command `npm ci`, start command `npm run start:prod`.
- [ ] Paste all variables from `backend/.env.production` into Railway's env var UI.
- [ ] Add custom domain `api.yourdomain.com` (Railway issues a Let's Encrypt cert automatically).
- [ ] Note the outbound static IP (Railway Pro plan) for §2.5.

**Gotcha:** Railway's free plan has no static outbound IP, which blocks §2.5. Either commit to Pro ($20/mo + usage) or use Render/Fly with a dedicated IP.

**Cost:** $5/mo Hobby + usage, or $20/mo Pro + usage.

---

### 2.5 Lock Atlas IP allowlist

- [ ] In Atlas → Network Access, remove the `0.0.0.0/0` entry.
- [ ] Add only the static IP(s) of your Railway/compute deployment.
- [ ] Smoke-test the API after locking — if `/health` is still 200, you're good.

---

## Phase 3 — CI/CD secrets to set in GitHub Actions

After Phase 1 + 2, in GitHub → repo Settings → Secrets and variables → Actions, set the following.

**For backend CD (`.github/workflows/deploy-backend.yml`):**
- [ ] `RAILWAY_TOKEN`

**For Flutter Android CD:**
- [ ] `KEYSTORE_BASE64` — base64 of the `.jks` file. On Windows:
  ```
  certutil -encode reverse-match-release.jks ks.b64
  type ks.b64
  ```
  Strip the `BEGIN/END CERTIFICATE` lines before pasting. On mac/linux: `base64 -i reverse-match-release.jks`.
- [ ] `KEYSTORE_PASSWORD`
- [ ] `KEY_PASSWORD`
- [ ] `KEY_ALIAS` (e.g. `reverse-match`)
- [ ] `GOOGLE_PLAY_SERVICE_ACCOUNT` — JSON downloaded from Play Console service account (§5.2)
- [ ] `API_BASE_URL` (e.g. `https://api.reversematch.app`)
- [ ] `SENTRY_DSN_FLUTTER`
- [ ] `GOOGLE_CLIENT_ID`

**For Flutter iOS CD:**
- [ ] `IOS_DISTRIBUTION_CERT_P12` (base64-encoded `.p12` from Keychain)
- [ ] `IOS_DISTRIBUTION_CERT_PASSWORD`
- [ ] `APPSTORE_ISSUER_ID`
- [ ] `APPSTORE_API_KEY_ID`
- [ ] `APPSTORE_API_PRIVATE_KEY` (the contents of the `.p8` file)

**GitHub Environments:**
- [ ] Create `staging` environment — no approvers required.
- [ ] Create `production` environment — require 1 reviewer before deploy.

**Gotcha:** `certutil -encode` on Windows wraps the base64 with `-----BEGIN CERTIFICATE-----` headers. Delete those lines (and the trailing footer) before pasting into the GitHub Secret, or the workflow's `base64 -d` will fail.

---

## Phase 4 — Legal

### 4.1 Privacy Policy

- [ ] Draft a privacy policy covering: data collected (name, phone, DOB, photos, location, device ID), third parties (Cloudinary, Firebase, Stripe, Sentry, SendGrid), location handling, deletion process, privacy contact email, effective date.
- [ ] Host at `https://yourdomain.com/privacy` — easiest path is a single-page HTML file on **Cloudflare Pages** (free) connected to a `legal/` GitHub repo.
- [ ] Add `PRIVACY_POLICY_URL=https://yourdomain.com/privacy` to `backend/.env.production`.

### 4.2 Terms of Service

- [ ] Draft Terms covering: 18+ age requirement, acceptable use, moderation policy, Boost / paid features refund policy, account termination.
- [ ] Host at `https://yourdomain.com/terms`.
- [ ] Add `TERMS_URL=https://yourdomain.com/terms` to `backend/.env.production`.

**Gotcha:** Apple's App Review will reject if these URLs return anything other than 200 with substantive content, or if they're behind authentication.

### 4.3 Age verification (informational only)

Both backend and Flutter **already enforce 18+** — no code change needed:
- Backend: `backend/src/modules/auth/auth.service.js` → `validateAge` rejects DOB < 18.
- Flutter: `reverse_match/lib/.../dob_screen.dart` blocks underage signups in the UI.

- [ ] Confirm your Privacy Policy and Terms both explicitly state the 18+ requirement (required for App Store / Play approval).

---

## Phase 5 — App Stores

### 5.1 Apple Developer ($99/yr)
Reference: `DEPLOYMENT_ROADMAP.md` §5.1.

- [ ] Enroll at [developer.apple.com](https://developer.apple.com) ($99/yr). **Individual enrollment is faster; Organization requires a D-U-N-S number and can take 2-4 weeks.**
- [ ] Register App ID `com.reversematch.reverse_match`, enable Push Notifications capability.
- [ ] Create **Distribution Certificate** in Keychain Access (requires a Mac, or use a Mac-in-the-cloud service like MacStadium / GitHub macOS runner).
- [ ] Create **App Store Provisioning Profile** linked to your App ID + Distribution cert.
- [ ] Export `.p12` from Keychain (right-click cert → Export). Encode to base64 and store as GitHub Secret `IOS_DISTRIBUTION_CERT_P12`.
- [ ] App Store Connect → Users & Access → Keys → Generate API key. Save the `.p8` content, issuer ID, key ID.
- [ ] Upload APNs `.p8` key to Firebase (back-fills §1.1).

**Gotcha:** Distribution cert generation strongly prefers a real Mac. On Windows you'd need to bootstrap the cert via App Store Connect API or use the macOS runner in CI. Plan for either Mac access or a service like Codemagic.

**Cost:** $99/yr.

### 5.2 Google Play Console ($25 one-time)
Reference: `DEPLOYMENT_ROADMAP.md` §5.2.

- [ ] Create account at [play.google.com/console](https://play.google.com/console) ($25 one-time).
- [ ] Create app "Reverse Match", default language English.
- [ ] Complete **Data Safety form** — declare every data type the app collects (location, photos, phone-based contact info, financial via Stripe).
- [ ] Complete **Content Rating questionnaire** — expect PEGI 18 / ESRB Adults Only.
- [ ] Setup → API access → Link to Google Cloud project → create Service Account → grant "Release manager" → download JSON.
- [ ] Store the JSON as GitHub Secret `GOOGLE_PLAY_SERVICE_ACCOUNT`.

**Cost:** $25 one-time.

### 5.3 TestFlight beta

- [ ] Trigger first iOS CD run (push a `v0.x.x` tag) or upload manually via Xcode.
- [ ] Invite up to 100 internal testers in App Store Connect → TestFlight.
- [ ] Test for 1-2 weeks, watch Sentry for crashes.
- [ ] Submit for App Store Review only after TestFlight is stable.

### 5.4 Play Store internal testing

- [ ] Trigger first Android CD run; AAB lands on the Internal Testing track automatically.
- [ ] Add internal testers by email in Play Console.
- [ ] Test on at least one Samsung and one Pixel.
- [ ] Promote internal → closed beta → open beta → production gradually.

### 5.5 Listing assets checklist

**Android:**
- [ ] App icon 512×512 PNG (no transparency).
- [ ] Feature graphic 1024×500 PNG.
- [ ] At least 4 phone screenshots per density bucket.
- [ ] Short description ≤80 chars.
- [ ] Full description ≤4000 chars.

**iOS:**
- [ ] Screenshots at 6.5" iPhone (1284×2778) and 5.5" iPhone (1242×2208).
- [ ] (Optional) App preview video — strongly recommended for dating apps.
- [ ] App description and keywords (≤100 chars total for keywords).
- [ ] Support URL `https://yourdomain.com/support`.
- [ ] Privacy URL `https://yourdomain.com/privacy`.

---

## Phase 6 — Monitoring

### 6.1 UptimeRobot (free)

- [ ] Sign up at [uptimerobot.com](https://uptimerobot.com) (free tier).
- [ ] Add HTTP(S) monitor → `https://api.yourdomain.com/health`, check every 5 minutes.
- [ ] Set alert contact: `omswork26@gmail.com` for status != 200.

### 6.2 Verify Sentry error capture end-to-end

- [ ] In backend, hit a test endpoint that throws (or temporarily `throw new Error('sentry test')` in a route). Confirm the event appears in `reverse-match-backend`.
- [ ] In Flutter staging build, trigger a manual exception (`Sentry.captureException(...)`). Confirm the event appears in `reverse-match-flutter`.
- [ ] Remove the test throws.

---

## Final Pre-Launch Checklist

- [ ] All Phase 1 env vars set in `backend/.env.production` and `reverse_match/.env.production`
- [ ] Domain DNS propagated (`nslookup api.yourdomain.com`)
- [ ] Atlas IP allowlist locked to compute IPs only
- [ ] CI lint + test green on `main`
- [ ] First production deploy succeeded (Sentry shows real release telemetry)
- [ ] TestFlight build passed Apple internal review
- [ ] Play Store internal track build published
- [ ] Privacy + Terms URLs return 200 with substantive content
- [ ] UptimeRobot monitor green for 24+ hours
- [ ] Stripe live webhook receives `checkout.session.completed` (test with a $1 charge then refund)
