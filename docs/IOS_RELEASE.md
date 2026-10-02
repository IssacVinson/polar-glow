# iOS release (no Mac required)

Bundle ID: `com.polarglowak.app` (same as Android; already registered in Firebase as the iOS app).
Build path: GitHub Actions workflow **iOS TestFlight** (`.github/workflows/ios-testflight.yml`) on a `macos-26` runner
(Xcode 26, required by App Store Connect since 2026-04-28). Free for this public repo.

## One-time Apple setup (needs the Apple ID / Account Holder sign-in)
1. developer.apple.com -> Certificates, Identifiers & Profiles -> Identifiers -> **+ App IDs -> App**,
   Description `Polar Glow Detailing`, Explicit Bundle ID `com.polarglowak.app`. No extra capabilities needed.
2. Note the **Team ID** (Membership details).
3. App Store Connect -> Apps -> **+ New App**: iOS, name `Polar Glow Detailing`, primary language English (U.S.),
   bundle ID `com.polarglowak.app`, SKU `polarglowak-ios`.
4. App Store Connect -> Users and Access -> Integrations -> **App Store Connect API** -> Team Keys -> **+**:
   name `GitHub Actions`, access **Admin** (needed so Xcode can create the cloud-managed distribution certificate).
   Download the `.p8` once. Note the **Key ID** and **Issuer ID**.

## Repo secrets (Settings -> Secrets and variables -> Actions)
| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | 10-character Team ID |
| `ASC_KEY_ID` | API key ID |
| `ASC_ISSUER_ID` | Issuer ID (UUID) |
| `ASC_KEY_P8` | full text of the `.p8` file, including BEGIN/END lines |
| `STRIPE_PUBLISHABLE_KEY` | `pk_live_...` (the workflow writes it into the bundled `.env.example`) |

## Build and upload
Actions -> **iOS TestFlight** -> Run workflow. The build appears in App Store Connect -> TestFlight after processing
(~10-30 min). Build number defaults to `run number + 100`; version name comes from `pubspec.yaml`.

## App Store Connect listing items (see STORE_LISTING.md for copy)
- Privacy Policy URL and account-deletion info (in-app deletion is Settings -> Delete account)
- App Privacy ("nutrition label") answers per STORE_LISTING.md
- Screenshots: iPhone 6.9"/6.7" (1290x2796 or 1320x2868) required; 6.5" (1242x2688 / 1284x2778) if no 6.9"/6.7" set; iPad 13" (2064x2752) required because the app declares iPad support
- Age rating, category (Lifestyle or Business), support URL, contact info, **App Review demo account** (customer login; the app is login-gated)
- Export compliance is preset (`ITSAppUsesNonExemptEncryption = false`)
