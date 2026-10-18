# Security

Report vulnerabilities privately to the repository owner using GitHub private vulnerability reporting when available. Do not post location data, access tokens, invite links or account passwords in public issues.

Authorization is enforced in Postgres, not by hiding UI. All public tables have RLS and only authenticated SELECT grants. Checked transactional commands perform writes. Private privileged functions set an empty search path, check `auth.uid()`, and are not directly exposed through the REST schema. Anonymous execution is revoked.

Location history is private to its author. Shared location access checks current membership, consent and recency. No location coordinates are broadcast over Realtime; clients fetch snapshots with fresh authorization. Events use Realtime with RLS and periodic refresh as fallback.

The public publishable key is not a secret. Never commit service-role keys, SMTP passwords or personal access tokens.

The original shared password, weak hash, simulated members, fake alerts and unsupported encryption claims have been removed.

Before launch, configure production Auth settings, SMTP, redirect origins and appropriate monitoring. Review `DEPLOYMENT.md`. Security tests are in `db/security-test.sql` and `tests/`.
