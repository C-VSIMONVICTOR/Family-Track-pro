# FamilyTrack Pro

Family circles with individual accounts, opt-in foreground location sharing, a live map, safe-zone events, check-ins and in-app SOS acknowledgements. This replaces the original browser-only demonstration.

## Current release status

The connected Supabase backend is provisioned and the family access model has passed transactional security tests. The application builds successfully. **Public launch is pending email delivery, Auth URL configuration and two-device browser acceptance testing.** It is not an emergency response service.

Review deployment: https://familytrack-pro.coolbrush513.chatgpt.site (owner-private).
Supabase project: `wjiyyqhqulsthwvcxkkl`, EU West.

## Run

Requires Node 22.12+.

```sh
npm ci
npm run dev
npm test
npm run build
```

The publishable key in `src/config.js` is intentionally public. Do not place a service-role key or SMTP password in client code. Apply `db/schema.sql` only to a new project, or use the already provisioned project. Do not reapply the baseline to the connected project.

## Implemented

- Email/password sign-up, confirmation, login, password reset and password change through Supabase Auth.
- Create up to five family groups per user; up to 20 members per family.
- Owner-created, random 256-bit, single-use invitations expiring after 24 hours. Tokens are stored as hashes.
- All family members use individual accounts. Every member controls their own sharing.
- Leaflet/OpenStreetMap map. Foreground location writes are throttled to one per ten seconds per browser; backend enforces a five-second minimum.
- Family location snapshots poll every ten seconds with current database authorization. Markers hide after two minutes without a fresh reading.
- Stopping sharing deletes the latest shared location. Leaving/removal deletes membership-linked location data.
- Owner-managed safe zones. Server computes distance and creates crossing events, with accuracy checks and a 25m boundary hysteresis. First fix establishes a baseline.
- Persistent in-app SOS, check-ins, family event updates via Realtime and polling, and explicit SOS acknowledgements.
- Private personal history, clear-history controls, family deletion and account deletion.
- Responsive desktop/mobile interface and installable web app manifest. No sensitive API caching or offline queue.

## Important behavior

This web app cannot promise background tracking: mobile operating systems may suspend browsers. Location sharing needs HTTPS, explicit browser permission, connectivity and the app open. Multiple tabs/devices on the same account should be avoided; sharing is controlled per user/family, not per device.

SOS means a database event visible to signed-in current family members. It does not send SMS, email, background push or contact emergency services. An acknowledgement is an explicit member action, not a delivery receipt. If a send fails, the UI reports an error and does not claim success.

The app does not claim end-to-end encryption. HTTPS protects transport; the database provider and authorized operators can access stored data. OpenStreetMap receives IP addresses and tile requests; Google Fonts is used for typography. Review `DEPLOYMENT.md` before allowing customers to sign up.

## Retention

History reads are limited to the last 24 hours; at most 200 records per user are retained during location publishing. Old records are physically pruned on the next location write. Latest locations are unreadable through the API after five minutes and hidden on the map after two minutes. User-initiated deletion works immediately.

`db/proposed-retention.sql` is **not applied**. Automatic review rejected the proposed periodic deletion without specific user approval. It proposes five-minute cleanup of history older than 24 hours, locations older than five minutes, expired/used invitations, and events older than 30 days. No periodic cleanup currently runs.

## Verification

- `npm test`: XSS escaping, coordinate validation, invitation parsing and stale-location behavior.
- `db/security-test.sql`: rollback-only backend checks for cross-family isolation, invite single-use, owner permissions, consent, location spoofing prevention, private history, SOS persistence and revoked membership.
- `node tests/api-smoke.js`: live unauthenticated API denial and Auth reachability; needs network access.
- Supabase security advisors: no findings at implementation time.
- Full interactive browser and two-device tests still need to be completed. No browser QA capability was available in the build environment.

License: MIT.

## Family chat and Android

Family chat is available from the Chat tab on web and Android. The latest 100 messages are fetched with current family authorization every four seconds while the chat is open. Messages support deletion, reporting and per-person hiding. Reports require an operator to review the backend queue. Chat is not end-to-end encrypted and no chat push delivery is configured.

Android sources are in `android/`; `capacitor.config.json` uses bundled web assets, rather than loading the private hosted Site. Only foreground location permissions are requested. See [Android, Google Play and client acquisition plan](docs/ANDROID-AND-LAUNCH.md) for build commands, release requirements, limitations and a four-week growth pilot.
