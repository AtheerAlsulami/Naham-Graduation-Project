# AWS Auth Lambda Quick Fix

Use this when API returns `"Hello from Lambda!"` for auth routes.

## 1) Build zip packages

From repo root:

```powershell
powershell -ExecutionPolicy Bypass -File backend/aws/package_lambdas.ps1
```

Output zips are created in:

- `backend/aws/dist/naham-auth-register.zip`
- `backend/aws/dist/naham-auth-login.zip`
- `backend/aws/dist/naham-auth-google-signin.zip`

## 2) Update Lambda code (Console)

For each function:

- `NahamAuthRegister` -> upload `naham-auth-register.zip`
- `NahamAuthLogin` -> upload `naham-auth-login.zip`
- `NahamAuthGoogleSignin` -> upload `naham-auth-google-signin.zip`

Set handler names:

- `authRegister.handler`
- `authLogin.handler`
- `authGoogleSignin.handler`

Runtime should be Node.js 20.x or newer.

## 3) Environment variables

Set these in each Lambda:

- `USERS_TABLE` = your users table name (for example: `users` or `naham_users`)

Set this in `NahamAuthGoogleSignin`:

- `GOOGLE_CLIENT_ID` = your Google OAuth client ID

Note:
- Current Lambda code supports tables without `email-index` by falling back to `Scan`.
- For better performance in production, still create GSI `email-index` on `email`.

## 4) API Gateway route mapping

Verify routes point to the correct functions:

- `POST /auth/register` -> `NahamAuthRegister`
- `POST /auth/login` -> `NahamAuthLogin`
- `POST /auth/google-signin` -> `NahamAuthGoogleSignin`

Then deploy API stage.

## 5) Smoke test

```powershell
$base = "https://4m3cxo5831.execute-api.eu-north-1.amazonaws.com"

Invoke-WebRequest -Method Post -Uri "$base/auth/register" -ContentType "application/json" -Body '{"name":"t","email":"t@test.com","password":"123456","phone":"","role":"customer"}' -UseBasicParsing
Invoke-WebRequest -Method Post -Uri "$base/auth/login" -ContentType "application/json" -Body '{"email":"t@test.com","password":"123456"}' -UseBasicParsing
```

Expected: JSON response containing `user` and token fields, not `"Hello from Lambda!"`.

## 6) Google Sign-In behavior

`POST /auth/google-signin` now requires an `intent` field:

- Login existing account:
  - `intent: "login"`
  - If email is not found, API returns `404` with a clear message.
- Register new account via Google:
  - `intent: "register"`
  - Requires `role`.
  - If email already exists, API returns `409` with a clear message.
