# Approved native API patch — validation and application

Status: implementation complete in a temporary source-only copy; **not applied to ../user-management-api**. Henry approved the exact 17-file scope on 2026-10-22.

The initial attempt to create NativeAuthResponse.cs in the sibling API repository was rejected by the workspace approval settings because it is outside the writable mobile project. No further writes to that repository were attempted. No Next.js files were changed.

## Deliverable

[native-api.patch](native-api.patch) is a unified patch against a snapshot of the API's current working files, including its existing uncommitted changes. It adds explicit native auth/account/admin routes, raw-token DTOs, stable session-ID exposure, a last-admin deletion guard shared with the browser flow, and regression tests. Browser refresh-token cookies and CSRF checks remain intact. No configuration, secret, dependency or database-schema changes are included.

## Validation

- Restored the staged solution from locally cached NuGet packages with NuGet auditing disabled for this offline restore; package versions were not changed.
- Built the staged `UserManagement.sln`: **0 warnings, 0 errors**.
- Standard `dotnet test` was attempted but could not start because VSTest needs a localhost communication socket, denied by this sandbox. This is a tooling restriction, not a test assertion failure.
- Executed all **124 Fact/InlineData cases**, using the actual xUnit assertions, through a temporary in-process reflection harness: **124 passed, 0 failed**. The harness constructs a new test class for each case and awaits asynchronous methods. It does not reproduce xUnit runner scheduling or discovery infrastructure. Current tests contain no MemberData/ClassData or xUnit fixture lifecycle dependencies.
- Middleware tests use real ASP.NET routing, JWT signature validation, authorization and MVC model validation through an in-memory RequestDelegate. `WebApplication.CreateEmptyBuilder` avoids default configuration file watchers. No TestHost package, listening server, MongoDB or email provider is started.
- Middleware coverage includes cookie-only rejection across all protected native mutation routes, User-vs-Admin authorization, successful Admin Bearer access, current-user session revocation, required JSON refresh input, camelCase token responses with no-store headers, and retained browser CSRF enforcement even with a spoofed mobile header.
- Existing rotation, reuse-detection, disabled-user, cleanup and browser-cookie unit tests are included in the passing cases. Tests verify that session IDs are preserved across refresh and last-admin deletion rejects before storage/token cleanup.
- `git apply --check` succeeds against the original API's current working tree.
- Original API source files were compared with the read-only snapshot and remained unchanged during this work.

## Apply in the API workspace

Open `/Users/henry/Desktop/Github/user-management-api` as a writable workspace. The existing approval covers this patch; no new feature approval is needed. From that repository:

```sh
git apply --check '../user-management-mobile/docs/native-api.patch'
git apply '../user-management-mobile/docs/native-api.patch'
dotnet build UserManagement.sln
dotnet test UserManagement.UnitTests/UserManagement.UnitTests.csproj
```

If files changed after the snapshot and the check fails, inspect the differences before applying; do not force the patch or reset unrelated working changes.

## Limits before production

- The last-active-admin guard uses the existing count-then-mutate approach. It prevents sequential self-deletion but is not transactional against concurrent administrator deletions/demotions/disables. A shared database invariant across these operations remains future work.
- Middleware tests use test JWT settings and mocked application services. They do not execute Program.cs's MongoDB-backed session/token-version validation or exercise live external integrations. Those deployment integration checks remain necessary.
- The existing shared auth rate limiter and sliding refresh lifetime are preserved. Review shared-network refresh traffic and an absolute maximum session lifetime before release.
- Email-link domain associations, production application identity/signing and HTTPS CAPTCHA hosting remain deployment prerequisites.
- Flutter update: dependencies are now installed locally, and analysis passes with no issues after fixing 33 lint findings. Henry reported 14 tests passing before lint cleanup; the sandbox blocks the localhost socket needed for a post-cleanup Flutter test run. Platform builds/device runs remain unverified. API validation does not imply end-to-end verification.
