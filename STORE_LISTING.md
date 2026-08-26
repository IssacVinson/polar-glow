# Polar Glow Detailing — Store listing copy

Use this with Google Play Console and App Store Connect. Do not put the DUNS number in the app or in public listing text.

**Version in this PR:** 1.0.3+4  
**Application ID / bundle ID:** `com.polarglowak.app`  
**Privacy Policy:** https://issacvinson.github.io/polar-glow/privacy_policy.html  
**Account deletion help page:** https://issacvinson.github.io/polar-glow/delete-account.html  
**Website:** https://polarglowak.com  
**Support email:** polarglowdetailing@gmail.com  
**Phone:** (907) 406-5088  
**Hours:** Mon–Sat 7am–6pm, Sunday closed  
**Service area:** Eagle River, Anchorage, Palmer, Wasilla, JBER, Alaska

---

## Google Play — short description (80 characters max)

Mobile auto detailing in Eagle River & Anchorage. Book, pay, and we come to you.

(79 characters)

Alternate (78):
Premium mobile detailing in Eagle River, AK. Book online — we come to you.

## Google Play — full description

Polar Glow Detailing is Eagle River and Anchorage’s mobile auto detailer. We come to your home, office, or base with professional-grade products. Every interior detail includes shampoo.

BOOK IN THE APP
• Browse current services and add-ons
• Choose a region: Eagle River, Anchorage, Palmer, Wasilla, or JBER
• Pick a specific detailer or the next available time
• Enter your address with Google Places autocomplete
• Pay securely with a card (Stripe) or choose cash on arrival

YOUR ACCOUNT
• See upcoming and past bookings
• Leave feedback after a completed detail
• Manage your profile, password, and privacy settings
• Delete your account and personal data from Settings at any time

SERVICE AREA
Eagle River, Anchorage, Palmer, Wasilla, and JBER. Hours: Monday–Saturday 7am–6pm. Sunday closed.

Questions? Call (907) 406-5088 or visit polarglowak.com.

Polar Glow Detailing — we come to you.

## App Store — subtitle (30 characters max)

Mobile detailing, Eagle River

(29 characters)

## App Store — promotional text (170 characters max)

Book Polar Glow from your phone. Mobile interior detailing in Eagle River, Anchorage, Palmer, Wasilla, and JBER. We come to you — shampoo included.

(148 characters)

## App Store — description

Polar Glow Detailing brings showroom-quality interior detailing to your driveway in Eagle River, Anchorage, Palmer, Wasilla, and JBER.

Every interior detail includes shampoo and extraction. Extra TLC and extra shampoo are available as add-ons. Exterior maintenance and pop packages are also in the app.

Book a specific detailer or the next available window, pay with a card, and track your appointments. When you are done with Polar Glow, you can delete your account from Settings.

Hours: Monday–Saturday 7am–6pm. Sunday closed.
Call (907) 406-5088 · polarglowak.com

## App Store keywords (100 characters max, comma-separated, no spaces after commas is optional)

auto detailing,car detailing,Eagle River,Anchorage,mobile detail,Alaska,interior clean,car wash

(96 characters)

## Data safety / App Privacy labels (summary)

Collected:
- Name, email, phone, username (account)
- Physical address for the appointment (precise location via Google Places text search; optional device location)
- Vehicle descriptions and booking notes
- Purchase history (Stripe; Polar Glow does not store full card numbers)
- Photos (employee reimbursement receipts only)
- User-generated content (reviews)

Used for: App functionality, customer support, fraud prevention.

Not sold. Not used for tracking ads.

Account deletion: in-app, Settings → Delete account.

---

## Remaining human steps (not done in this repo)

### Android (Google Play)
1. Create an upload keystore if you do not already have one:
   `keytool -genkey -v -keystore ~/polar-glow-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Put `android/key.properties` on the machine that builds the AAB (do not commit it):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/absolute/path/to/polar-glow-upload.jks
   ```
3. From the repo root, with Flutter 3.47+ (compile/target SDK 36):
   `flutter build appbundle --release`
4. In Play Console: create the app, complete store listing, content rating, target audience (18+), Data safety, and privacy policy URL.
5. Upload `build/app/outputs/bundle/release/app-release.aab`.
6. New Play apps from 31 Aug 2026 must target API 36 — this project already sets `compileSdk 36` and `targetSdk 36`.

### iOS (App Store)
1. Enroll in Apple Developer ($99/year). Use an organization account if Polar Glow is an LLC; otherwise Individual. DUNS 145039246 is for Apple’s organization identity check — do not put it in the app.
2. In Xcode 26 (iOS 26 SDK), open `ios/Runner.xcworkspace`, set signing team, and archive.
3. App Store Connect: privacy policy URL, account deletion URL (the GitHub Pages page is a fallback; in-app deletion is implemented), screenshots (iPhone 6.7", 6.5", 5.5" plus iPad if you keep iPad family), 18+ age.
4. Prefer hosting privacy and delete-account pages on polarglowak.com when you can; GitHub Pages URLs already work.

### Backend
1. Deploy Cloud Functions so in-app account deletion uses the Admin SDK:
   `firebase deploy --only functions:deleteOwnAccount`
   Keep `createPaymentIntent` deployed in `us-west1`.
2. Switch Stripe to live keys in Firebase secrets and in the local `.env` (`STRIPE_PUBLISHABLE_KEY`). Do not commit `.env`.
3. Confirm Firestore rules allow employees to read their availability/bookings and admins to manage payroll. The in-app delete flow prefers the Cloud Function so it does not depend on client delete rules for usernames.
4. After pushing `privacy_policy.html` and `delete-account.html`, republish GitHub Pages (and copy to polarglowak.com when ready).

### Store assets
- App icon is generated from `assets/images/logo.png` via `flutter_launcher_icons`.
- Capture screenshots on a small Android phone, a large Android phone, iPhone SE, and a Pro Max after a signed-in walkthrough of Book → Pay → Bookings.
