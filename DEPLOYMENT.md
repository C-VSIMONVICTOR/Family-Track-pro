# Public launch configuration

## Required before public sign-up

1. Configure a custom SMTP provider at https://supabase.com/dashboard/project/wjiyyqhqulsthwvcxkkl/auth/smtp . Supabase default email delivery only supports project team addresses. Keep email confirmation enabled. Enter credentials in the provider dashboard, never in the repository.
2. In Auth URL Configuration, set Site URL to the final public domain and allow that exact origin as a redirect destination: https://supabase.com/dashboard/project/wjiyyqhqulsthwvcxkkl/auth/url-configuration . The review Site origin is `https://familytrack-pro.coolbrush513.chatgpt.site`. It is owner-private and cannot support family acceptance tests until access is made public or a public deployment is configured.
3. Set a minimum password length of 12 server-side, enable compromised-password protection if supported by the plan, and configure production Auth rate limits/CAPTCHA when accepting public sign-ups. Frontend length validation is not a server setting.
4. Test email confirmation and reset links in the same browser that initiated them (PKCE), including failure/expired-link cases.
5. Complete the two-device acceptance test below before inviting customers.

## Hosting

Vite produces `dist/`. Static hosting must use HTTPS. The repo includes `vercel.json` with explicit build/output settings and security headers. Sites configuration is in `.openai/hosting.json`. Neither deployment process applies database SQL automatically.

For a public service, use an owner-approved public domain. The current Sites deployment is private by default. Database row-level security is required even when the frontend is private.

## Two-device acceptance test

Use disposable test accounts, not real family coordinates.

1. Confirm two different emails; log in on separate devices. Create a family on device A and send its invitation link to B.
2. Confirm B joins once; replay the invite with a third account and verify rejection. The third account must not access any private table, even with guessed UUIDs.
3. Sharing starts off. Grant location permission on A, start sharing, and confirm B sees a recent marker within roughly 10 seconds. Deny permission and verify no sharing starts.
4. Stop sharing and verify B's marker disappears after its next refresh. Remove B and verify it loses the family entirely. Closing a browser must result in stale/hidden markers, not a permanent live badge.
5. Use controlled coordinates in a test environment to exercise zone enter/exit with adequate accuracy. First fix must not manufacture an arrival event.
6. Trigger an SOS on A. Verify B can see and acknowledge the event. Disconnect A and verify failed send is reported. Do not assume SMS, email or push delivery.
7. Clear history, leave a group, and delete a disposable account; verify the intended data is removed. Deleting an owner account also deletes groups they own; the UI explicitly warns about this.
8. Check small-screen navigation, keyboard focus, map attribution, password reset and sign-out.

## Remaining service operations

- Choose a support contact and review privacy/terms for the actual service operator and audience before public launch.
- Approve a retention policy before enabling `db/proposed-retention.sql`. Until then no scheduled purge runs.
- Set up production monitoring, backups appropriate to the chosen Supabase plan, and test restoring a nonproduction copy.
- Perform load tests for the expected number of families. This version polls family snapshots every ten seconds; plan capacity accordingly.
- For reliable closed-app notifications, integrate and verify web/mobile push. For dependable background location, ship native Android/iOS apps with platform permission flows.
