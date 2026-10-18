-- NOT APPLIED. Requires explicit user approval of retention periods and cleanup.
-- Do not apply this file as part of deployment.
create extension if not exists pg_cron with schema pg_catalog;
-- Physical cleanup runs every five minutes, independently of app activity.
select cron.schedule('familytrack-retention','*/5 * * * *', $job$
 delete from public.location_history where recorded_at < now()-interval '24 hours';
 delete from public.locations where updated_at < now()-interval '5 minutes';
 delete from private.invitations where expires_at < now() or used_at is not null;
 delete from public.events where created_at < now()-interval '30 days';
$job$);
