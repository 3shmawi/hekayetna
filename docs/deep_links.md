# Deep links

Routing uses go_router; every route in `lib/core/router/app_routes.dart` is
also a deep link.

| Path | Screen |
|---|---|
| `/` | Home |
| `/settings` | Settings |
| `/sign-in` | Sign in / create account (`?from=<path inside the app>`) |
| `/account` | Account — signed-in only |
| `/new-password` | Set a new password after a reset link — signed-in only |
| `/welcome` | First-launch welcome (shown once instead of `/`) |

## Custom scheme (works now)
`familystories://settings` — test with:
```bash
adb shell am start -a android.intent.action.VIEW -d "familystories://settings"
xcrun simctl openurl booted "familystories://settings"
```

## https links (App Links / Universal Links)
Host: `example.com`. Needs, once:
1. The website served from that domain (root), including
   `website/.well-known/assetlinks.json` and
   `website/.well-known/apple-app-site-association`.
2. `assetlinks.json`: replace the SHA-256 with Play Console → Setup →
   App signing → "App signing key certificate" fingerprint.
3. `apple-app-site-association`: check the Team ID (`TEAMID`).
4. Apple Developer → Identifiers → `com.mohager.hekayetna` → enable
   **Associated Domains** (then CI regenerates the profile).

If no domain was chosen at creation, add later: intent filter in
`AndroidManifest.xml` (`android:autoVerify="true"`, scheme https) and
`ios/Runner/Runner.entitlements` with `applinks:<domain>`.
