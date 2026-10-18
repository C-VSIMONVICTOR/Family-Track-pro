# FamilyTrack Pro: Android testing, Google Play and growth

Prepared 19 October 2026. This is a release plan, not confirmation of Play approval.

## What this version does

- Private family groups, personal accounts, single-use invitations and optional location sharing.
- Native Android foreground location permission and location readings using Capacitor Geolocation.
- Private text chat, last 100 messages, updates every four seconds while Chat is open, deletion, reporting and hiding a member's chat messages.
- In-app check-ins, requests for help, safe-place events and personal location history.
- No ads SDK, contacts access, camera, microphone or background location permission.

This version does not deliver push notifications or guarantee background location updates. A help alert does not call emergency services. It does not provide end-to-end encryption. Do not advertise those features.

## Install the test APK

Download the APK on an Android phone, open it, and allow installation from that source if Android asks. Android 7/API 24 or later is required by this build. Test with two consenting adults on different phones. A test APK is signed with a development key; do not use it as the final store release or advertise it as production certified.

Confirmation emails open in the browser. After confirming, return to the Android app and sign in. Invitation links can be copied and pasted into Join a family inside the app. The current web origin is owner-private, so it is not yet a public invitation landing page.

## Build again

Install Node 22+, Android SDK Platform 36, Build Tools 36, and JDK 21, or open the Android project in a compatible Android Studio. Use the pinned dependencies in package-lock.json.

```sh
npm ci
npm test
npm run build
npx cap sync android
cd android
./gradlew assembleDebug
```

The output is `android/app/build/outputs/apk/debug/app-debug.apk`. The provisional application ID is `com.familytrackpro.app`. Check brand/application-ID availability before creating the Play listing. After publication the application ID cannot simply be renamed as an app update.

For Google Play, generate a signed release Android App Bundle (AAB), not the test APK. Create and back up an owner-controlled upload key outside this repository, enable Play App Signing, and store signing passwords securely. Never commit keys/passwords or reuse the debug key for the production release.

## Finish before accepting customers

1. Configure custom SMTP and the final public Auth redirect origin in Supabase. Keep email confirmation enabled. Verify registration, confirmation, login and reset from actual phones.
2. Choose a public domain and support contact. Publish public Privacy, Terms and account-deletion pages. There is already an in-app deletion path; add a working public deletion request route for people who have uninstalled the app.
3. Review every collected category for the Data safety form: account email/name/IDs, precise or approximate location, chat text, family membership, reports and diagnostics. Assess each SDK/provider's actual behavior rather than copying a template declaration.
4. Set up moderation operations. In-app reports are stored in `public.chat_reports`. An authorized operator must review the queue, investigate and take action. Family owners can delete messages and remove members. Hiding only filters a person's chat messages for the reporting user; it does not turn off location sharing.
5. Enable compromised-password protection where supported by the selected plan. The current Auth advisor reports that it is disabled. Apply production rate limits/CAPTCHA where needed and review session protection.
6. Approve and implement a clear retention policy. The earlier scheduled cleanup proposal remains unapplied. Chat messages currently remain until deleted, their family is deleted, or their author deletes their account. Reports remain until the associated account or family is deleted or an authorized operator removes them.
7. Complete physical-device tests: Android permission denied, approximate location only, lost internet, app minimized/closed, battery saver, account deletion, family removal, invitation replay, message spoofing, report/hide/unhide and reconnect. App-closed notifications are not implemented.
8. Run load and recovery tests. Do not collect real family location data for stress tests.

## Google Play preparation

- Create and verify your Play Console developer account. Google currently quotes a one-time US$25 registration fee; choose the account type that matches the actual publisher.
- Prepare a signed AAB targeting the current required API. This scaffold targets API 36 (Android 16).
- Prepare the app name, short/full descriptions, app icon, screenshots, feature graphic, support email, privacy URL, country availability and content rating.
- Complete App access, Data safety, target audience and permission declarations accurately. Give reviewers test access to the account-gated features.
- New personal developer accounts created after 13 November 2023 generally need at least 12 testers continuously opted into a closed test for 14 days before applying for production access. Follow the requirements shown in your own Console.
- Start with a genuine adult-family pilot. If children are part of the intended audience, implement the required age/parental experience and review the Families/social interaction policies before marketing to them. Do not declare adult-only merely to avoid rules.
- New chat functionality means ongoing UGC moderation duties: accepted terms, prohibited behavior, reporting, blocking and actual follow-up. The controls alone do not make the app approved.
- When the release meets requirements, submit a small staged rollout and monitor crashes, sign-in failures, support and retention before expanding.

## A realistic way to attract clients

These are proposed experiments and targets, not guaranteed results or measured market statistics.

### Positioning

Use: **“A simple way for adult family members to share locations, chat and check in—by choice.”**

Begin with adults in families who commute, travel or live in different places. Avoid presenting it as secret tracking, emergency dispatch, school surveillance or an employer-monitoring product. Schools and businesses need a different access/consent model and should not be the first customers.

### Four-week pilot

| Week | Work | Proposed checkpoint |
| --- | --- | --- |
| 1 | Personally onboard 5–10 willing families. Watch them create a group, join, send a chat message and share location. Fix the top three obstacles. | Most can complete setup without coaching. |
| 2 | Recruit 12–20 adult testers for the applicable closed test. Publish three short product demonstrations using consenting test accounts and simulated locations. | Track completed family setups, not just downloads. |
| 3 | Let pilot families refer one other family. Publish simple explanations of permissions, privacy and how to stop sharing. Ask for honest feedback, without buying or incentivizing positive ratings. | More groups have two or more active members. |
| 4 | Interview returning and inactive families. Fix reliability issues. Test willingness to pay only after core use is repeatable. | Measure retention and support workload before paying for traffic. |

### Acquisition channels to test

- Opt-in WhatsApp communities and adult family/community groups: ask administrators before posting. Offer a short demo and hands-on onboarding.
- Instagram, TikTok and YouTube Shorts: show one real task per video, such as inviting a partner, checking in after travel, or stopping sharing.
- Referrals: encourage the first user to invite their own family. Avoid rewards that encourage unsolicited invites.
- App-store discovery: use clear screenshots labelled “Create a family,” “Choose when to share,” and “Chat together.” Explain foreground limits honestly.
- Small search/content experiments around voluntary adult family check-ins. Measure sign-up-to-family activation before purchasing larger ad campaigns.

### Pricing to validate later

Keep the pilot free. Test a family subscription only after measuring hosting costs and demand. Possible later paid features include verified push notifications, longer agreed retention and larger groups—only after they exist and have been tested. Do not place essential privacy/deletion controls behind payment. If selling digital subscriptions inside the Android app, check the Play billing rules and applicable exceptions before implementing checkout.

### Measure the right things

Define **family activation** as at least two verified members in one group plus a successful message or agreed location-sharing session. Track invitations accepted, setup time, day-7 returning families, message-send failures, fresh-location availability and support requests. Suggested beta decision rule: postpone advertising if users cannot reliably sign up or invite a second family member. Counts and retention targets should be set from pilot evidence rather than invented benchmarks.

## Primary sources checked

- Play account setup and fee: https://support.google.com/googleplay/android-developer/answer/6112435?hl=en-NG
- New personal-account testing: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB
- Target API requirement: https://developer.android.com/google/play/requirements/target-sdk
- Signing: https://developer.android.com/studio/publish/app-signing
- Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- User-generated content: https://support.google.com/googleplay/android-developer/answer/9876937
- Families policy: https://support.google.com/googleplay/android-developer/answer/9893335?hl=en
- Background location: https://support.google.com/googleplay/android-developer/answer/9799150?hl=en
- Capacitor environment: https://capacitorjs.com/docs/getting-started/environment-setup
