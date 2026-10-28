# Native API adaptation — approved and staged, not applied

The Flutter app calls ASP.NET directly. No Next.js API route or BFF cookie is used.
Henry approved this exact scope on 2026-10-22. Existing API and web repositories have not been changed: the session cannot write outside the mobile workspace. The implementation is available in [native-api.patch](native-api.patch); see [backend-validation.md](backend-validation.md).

## Native contracts

All URLs are relative to the ASP.NET origin. Native routes must never accept authentication cookies as an alternative to their Bearer/body credentials. Mobile routes are public HTTP endpoints, not proof that a request came from an official app. Retain all server validation, roles, ownership, CAPTCHA, auditing and rate limits. Keep all existing browser routes and CSRF checks intact.

| Method and route | Authorization/input | Success |
| --- | --- | --- |
| POST /api/mobile/auth/signin | Anonymous; existing SigninRequest | NativeAuthResponse |
| POST /api/mobile/auth/refresh | Anonymous; `{refreshToken}` | NativeAuthResponse, with both tokens rotated |
| POST /api/mobile/auth/signout | Anonymous; `{refreshToken}` | 204; idempotent revocation |
| POST /api/mobile/auth/signout-all | Bearer | 204 |
| DELETE /api/mobile/auth/sessions/{sessionId} | Bearer; validate 32-character N-format GUID | `{revokedCurrentSession}` |
| POST /api/mobile/account/change-password | Bearer; existing ChangePasswordRequest | 204; all sessions revoked |
| DELETE /api/mobile/account | Bearer; existing DeleteAccountRequest | 204; permanent deletion |
| PATCH /api/mobile/admin/users/{id}/role | Admin Bearer; ChangeUserRoleRequest | 204 |
| PATCH /api/mobile/admin/users/{id}/status | Admin Bearer; ChangeUserStatusRequest | 204 |
| POST /api/mobile/admin/users/{id}/unlock | Admin Bearer | 204 |

NativeAuthResponse:

```json
{
  "accessToken": "<JWT>",
  "accessTokenExpiresAt": "<UTC ISO 8601>",
  "refreshToken": "<opaque token>",
  "refreshTokenExpiresAt": "<UTC ISO 8601>",
  "sessionId": "<stable session ID>"
}
```

Set `Cache-Control: no-store` on native token responses. Do not issue refresh cookies on native routes. Preserve browser AuthResponse `{token, expiresAt}` and browser cookie behavior.

Use existing shared endpoints for signup, email verification/resend, forgot/reset password, whoami, session listing, profile operations, export, user listing and audit queries. The backend already authenticates these protected reads/profile operations with Bearer and does not require CSRF on them.

Reuse AuthService for token generation, hashing, rotation, reuse detection and session revocation. Reuse AccountService/AdminUserService for mutations. Match existing signin failure statuses and Problem Details extensions exactly. Native refresh 401 must be terminal. Do not use X-Client-Type or another client-supplied flag to skip CSRF on browser endpoints.

## Exact proposed backend files

Paths are relative to ../user-management-api.

| File | Change |
| --- | --- |
| src/UserManagement.Core/DTOs/NativeAuthResponse.cs | Add dedicated native token response |
| src/UserManagement.Core/DTOs/NativeRefreshTokenRequest.cs | Add required, length-bounded raw refresh token request |
| src/UserManagement.Core/DTOs/AuthSession.cs | Add SessionId to internal service result |
| src/UserManagement.Application/Services/AuthService.cs | Populate SessionId from the same value used for stored session and JWT |
| src/UserManagement.Web/Controllers/MobileAuthController.cs | Add native signin/refresh/signout/all/session-revocation routes, delegating to AuthService |
| src/UserManagement.Web/Controllers/MobileAccountController.cs | Add native change-password/deletion routes; reuse account service |
| src/UserManagement.Web/Controllers/MobileAdminUsersController.cs | Add native admin mutations; reuse admin service and existing conflict mapping |
| src/UserManagement.Application/Services/AccountService.cs | Reject deletion by the last active Admin before storage/token cleanup; retain existing deletion behavior for other users |
| src/UserManagement.Application/Interfaces/IAccountService.cs | Return a focused account-deletion result so conflict differs from invalid password |
| src/UserManagement.Core/DTOs/DeleteAccountResult.cs | Add Success/InvalidPassword/LastActiveAdmin outcome |
| src/UserManagement.Web/Controllers/AccountController.cs | Map last-admin deletion conflict for web as well, preserving CSRF |
| UserManagement.UnitTests/Controllers/MobileAuthControllerTests.cs | Native JSON transport, no cookies, error mapping, auth and session ownership |
| UserManagement.UnitTests/Controllers/MobileAccountControllerTests.cs | Authentication, mutation results and account-deletion conflict |
| UserManagement.UnitTests/Controllers/MobileAdminUsersControllerTests.cs | Admin authorization and mutation conflict mapping |
| UserManagement.UnitTests/Services/AuthServiceTests.cs | Session ID and existing rotation/reuse contract regression |
| UserManagement.UnitTests/Services/AccountServiceTests.cs | Last-admin deletion protection before cleanup |
| UserManagement.UnitTests/Controllers/AccountControllerTests.cs | Update deletion-result mocks and verify browser conflict/CSRF behavior |

The existing CountActiveAdminsAsync can support the deletion guard, but a count-then-delete check is not concurrency-safe against simultaneous admin changes. A transaction/serialized invariant needs a separate reviewed repository design before claiming strict concurrent last-admin protection. The existing role/status checks use count-then-mutate too.

No refresh lifetime change is proposed: retain the current sliding lifetime initially. Review a bounded absolute session lifetime separately.

No Next.js changes are proposed in this batch.

## Deployment work requiring actual domain/app identity

- Serve a Turnstile challenge page at an approved HTTPS origin (can be static hosting or ASP.NET; does not need Next.js).
- Accept only `signin` and `forgot_password` action query values. Render Turnstile with that action and the public site key. On success call `Captcha.postMessage(token)`. Never send credentials or JWTs to the WebView.
- Allowlist its hostname in backend CAPTCHA settings. Keep server-side action/hostname validation.
- Publish apple-app-site-association and assetlinks.json on the email-link domain with the real bundle/package ID, Apple team ID and Android signing fingerprint. Configure mobile platform associations; retain existing web reset/verification pages as fallback.
- Email generation currently uses FrontendBaseUrl plus /verify-email or /reset-password. The same existing HTTPS URLs can open the installed app through verified domain associations; do not accept arbitrary return URLs from requests.
- Review the shared five-per-minute/IP auth limiter for refresh traffic and shared mobile networks before release.

## Backend verification after approval

Build the solution and run affected controller/service tests. Add HTTP-level checks for actual middleware authorization, cookie/CSRF isolation, disabled users, owner boundaries, revoked sessions and role changes; controller unit tests alone do not execute ASP.NET authorization attributes. Exercise both browser-cookie and native-token flows together. Never print tokens or credentials.
