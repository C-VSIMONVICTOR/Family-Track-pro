# Release status — 18 October 2026

The web app is public at https://familytrack-pro.coolbrush513.chatgpt.site. Public access to the sign-in page does not grant access to private family data.

## Shipped
- Private family circles, opt-in foreground location, saved places, check-ins and in-app help alerts.
- Private family chat, own/owner message deletion, reporting and per-user message hiding.
- Operator moderation of reported messages; report evidence survives message removal. Operator access is a private database assignment, not editable account metadata. Audit records track decisions.
- Private support requests, operator replies and request rate limiting.
- Public privacy, terms, support and web account-deletion instructions. `/?action=delete-account` opens Settings after sign-in.
- Content security policy and native location-watch cleanup after sharing cancellation.
- Android version 1.1 / versionCode 2, target API 36; release signing comes from environment variables, never source control.

## Launch blockers
1. Supabase Auth dashboard: replace localhost Site URL with the public origin; allow that origin as an email redirect. Configure a verified SMTP sender. Keep email confirmation enabled. Test registration, confirmation and reset with an external email account. The dashboard currently requires owner sign-in.
2. Supply a public business support contact and identify the service operator in the final privacy policy/terms. The current private in-app support route requires sign-in.
3. Test the signed Android release on real phones: permission denial, permission revocation, switching groups, stopping sharing during a pending position/watch, network interruption, two-user chat/report/hide, password reset and complete account deletion.
4. Review database backup/recovery and capacity before paid launch. The service currently uses a free Supabase project. No uptime commitment, push notifications or background tracking is provided.
5. Complete Play Console verification, app signing enrollment, store listing assets, Data safety, account-deletion URL and any required closed testing. No Play submission has been made.
6. Automatic retention is NOT enabled. `db/proposed-retention.sql` remains a proposal; approval for its specific deletion periods is outstanding. Old history is hidden after 24 hours and pruned on a later publish; this is not a scheduled purge.

## Operator workflow
Sign in with the designated operator account, open Settings → Service moderation. Review reports, remove the reported message or dismiss the report; review and reply to support requests. Only reported message evidence is exposed to the operator queue, not unrestricted family chat. Queue views show the oldest 100 open items; process these to reveal later items.

## Rebuild a signed Android release
Keep the owner signing recovery package private and backed up. Its certificate must be retained for updates to directly installed APKs. If Play manages app signing, use this key as the upload key, subject to the Console setup selected by the owner.
Set `FAMILYTRACK_KEYSTORE` to the absolute PKCS12 path, `FAMILYTRACK_KEY_ALIAS` to `familytrack-release`, and `FAMILYTRACK_STORE_PASSWORD` / `FAMILYTRACK_KEY_PASSWORD` from the private recovery file. Do not commit these values. With JDK 21 and Android SDK installed, run `npm ci`, `npm test`, then `npm run android:release`. The release APK and AAB are in `android/app/build/outputs`. Without signing variables, Gradle creates unsigned release output; verify signatures before distribution.

## Verification
11 unit tests pass; production dependency audit reports zero vulnerabilities. `db/service-security-test.sql` validates operator authorization, ticket isolation, reply and rate limiting in a rolled-back fixture. `db/moderation-security-test.sql` validates report evidence and operator message removal. Existing family and chat isolation tests remain in `db/`. Public pages were checked over anonymous HTTP. Automated checks do not replace real-device or independent security testing.

Growth steps and Play preparation: see `ANDROID-AND-LAUNCH.md`. Start with a small adult pilot, resolve signup friction and support issues, then use a short demo and consent-based referrals before paying for acquisition.
