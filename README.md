# user-management-mobile

Flutter Android/iOS client for the sibling ASP.NET `user-management-api`. Next.js remains the web client/BFF; mobile API requests go directly to ASP.NET.

## Current status

Initial client source and generated Android/iOS projects are present. Includes authentication forms, conditional CAPTCHA WebView, secure refresh-token storage, biometric session unlock, profile/image operations, sessions, account security/export/deletion, admin controls and audit filters.

**Not yet verified on a device.** Dependencies have been installed locally. After fixing 33 analyzer findings, `dart analyze --fatal-infos` reports no issues. Henry reported all 14 Flutter tests passing before that lint cleanup. A post-cleanup test run in this session cannot start because its localhost socket is blocked by the sandbox; rerun `flutter test` locally. No platform build or device run has been verified. Native backend routes have been implemented and built in a temporary source copy, with an approved [apply-ready patch](docs/native-api.patch). They do not exist in the original API repository yet because the session cannot write to that sibling workspace. See [backend validation](docs/backend-validation.md). API and Next.js repositories remain unchanged.

## Run

Install a compatible Flutter SDK and platform toolchains, then from this repository:

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://YOUR_ASPNET_API_HOST \
  --dart-define=CAPTCHA_PAGE_URL=https://YOUR_APPROVED_CHALLENGE_HOST/mobile-captcha
```

Use the ASP.NET origin only, with no `/api` suffix. Do not set a Next.js origin. No API credentials, server secrets or signing keys belong in Dart defines. Release requests require HTTPS; no TLS verification bypass is implemented. Local image URLs resolve against the API origin. Local development HTTP additionally requires platform-specific debug configuration; HTTPS is preferred.

The installed SDK discovered during work is `/Users/henry/development/flutter-3.47.4-source`, not on PATH. A temporary copy was used for generation because the original SDK's cache is outside the session's writable directories. Do not depend on that temporary SDK path for normal development. SDK-referencing local.properties/xcconfig files are generated, ignored machine configuration.

## Structure

- `lib/app`: routing, startup, lifecycle locking and role-aware navigation.
- `lib/core`: API client, Problem Details, configuration and Riverpod dependency wiring.
- `lib/features/auth`: forms, CAPTCHA, token models/store and session coordination.
- `lib/features/account`: profile, uploads, export, deletion, password changes and shared account API access.
- `lib/features/sessions`: session listing/revocation.
- `lib/features/admin_users`: paginated users and role/status/unlock actions.
- `lib/features/audit_events`: paginated audit viewing with all backend filters.
- `test`: session concurrency/failure tests, Problem Details parsing and setup-state widget test.

Boundary models are handwritten for now, avoiding generated-code dependencies until contracts stabilize. Collection screens validate their response envelope and use maps for admin/audit/session rows; fully typed row models are a follow-up before release.

## Session behavior

Access tokens remain in memory; only refresh tokens and the biometric preference use secure storage. Signin sends `keepMeSignedIn: true`. Startup restores a session by refreshing; biometric-enabled startup waits for explicit local unlock. Biometric unlock is an application-level gate via local_auth, not server-side passwordless authentication or a biometric-bound encryption-key implementation.

Biometric locking is opt-in, with a 60-second background threshold. When biometrics are unavailable/cancelled, the user may clear the saved local session and sign in with a password. That local fallback does not itself revoke the previous server session; it remains visible in session management until expiry/revocation.

Concurrent refresh calls share one future. A protected 401 triggers one refresh and at most one request replay. A second 401 clears the session; 403 does not trigger refresh. Multipart bodies are rebuilt for replay. Refresh itself never retries automatically. Refresh 429 preserves the stored token; ambiguous network/server failures discard the old token to avoid replaying a potentially rotated token and triggering account-wide reuse revocation. This favors safe sign-in recovery over retaining a session on transient refresh failures.

Current/all-device signout waits for any pending rotation before revoking. A failed remote signout displays an error rather than claiming server revocation. User/account data is not persisted as an offline cache. JSON export uses a temporary file deleted after sharing; a process kill during sharing may leave a file until the next export or OS cache cleanup.

## Backend dependency

See [docs/backend-adaptation.md](docs/backend-adaptation.md) for native route contracts, exact proposed API files and deployment prerequisites. No browser authentication cookies or CSRF tokens are managed by Flutter. Native mutation endpoints are distinct from the existing browser routes.

Current ASP.NET behavior still permits the last active administrator to self-delete; the proposed backend guard must land before enabling production deletion. Native auth/mutation screens cannot complete against the current API until the adaptation is approved and implemented.

## Links, CAPTCHA and release setup

Email-link routes `/verify-email?token=...` and `/reset-password?token=...` are handled in the Flutter router. The app requires a confirmation tap before verifying a link. Platform App Link/Universal Link association is **not activated** because the real domain, application IDs and signing identities have not been supplied. See deployment steps in the backend adaptation document. A Dart route alone does not register OS-level links.

CAPTCHA requires an HTTPS hosted page and backend hostname allowlisting. The WebView sends only the challenge token to Flutter via `Captcha.postMessage(token)`, after which Flutter calls ASP.NET directly. No CAPTCHA hosting page is deployed by this repository.

Android uses FlutterFragmentActivity, biometric/Internet permissions, disabled app backup and an API 24 minimum. iOS includes camera/library/Face ID usage descriptions and the generated iOS 15 deployment target. Camera cancellation/permission failures show safe errors. JPEG/PNG signatures and size are checked before upload; HEIC must currently be exported as JPEG manually.

Before release: replace `com.example.user_management_mobile` with the real application identity, configure production signing (Android release is not signed with a debug key), activate verified links, install and lock compatible dependency versions, inspect dependency advisories, validate storage/keychain behavior and biometric enrollment changes, and run the flows on real Android/iOS devices. Recovery of image-picker results after Android process death is not implemented yet.
