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
| `/join/<code>` | Confirm joining a family (7-character short code or old UUID code); signed-in only |
| `/family/invite` | Invite page: code, QR, share (signed-in only) |

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

## Invite links (spec 06)
`familystories://join/<CODE>` opens the join confirm screen. The code is
parsed by `InviteCode.parse` before any network call: 7 characters from the
safe alphabet (no 0, O, 1, I, L), or an old UUID. Anything else (wrong length,
other characters, `?from=` tricks, absolute URLs) shows "invalid link" and
nothing is sent to the backend. Signed-out users are sent to sign-in first and
come back to the same `/join/<code>` (the return path is checked to stay inside
the app). Joining only happens after the person taps the confirm button, never
from just opening the link. The https form `https://<host>/join/<CODE>` is only
produced when a verified host is configured; until then the app shares the
custom-scheme link and the plain code.

Config read, not device-tested: the Android manifest has a VIEW intent filter
for scheme `familystories` (any host and path) and `Info.plist` has the
`familystories` URL type. Opening a link from the OS on a device or simulator
has not been run yet.
