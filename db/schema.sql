-- FamilyTrack Pro baseline. Apply once to a dedicated Supabase project.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table public.families (
 id uuid primary key default gen_random_uuid(), name text not null check (length(trim(name)) between 2 and 60),
 owner_id uuid not null references auth.users(id) on delete cascade, created_at timestamptz not null default now()
);
create index families_owner_idx on public.families(owner_id);
create table public.memberships (
 family_id uuid not null references public.families(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 display_name text not null check(length(trim(display_name)) between 1 and 60),
 sharing boolean not null default false, joined_at timestamptz not null default now(), primary key(family_id,user_id)
);
create index memberships_user_idx on public.memberships(user_id);
create table private.invitations (
 id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
 token_hash text not null unique, expires_at timestamptz not null default now()+interval '24 hours', used_at timestamptz
);
create index invitations_family_idx on private.invitations(family_id);
create table public.locations (
 family_id uuid not null, user_id uuid not null,
 latitude double precision not null check(latitude between -90 and 90), longitude double precision not null check(longitude between -180 and 180),
 accuracy double precision not null check(accuracy >= 0 and accuracy < 1000000), battery smallint check(battery between 0 and 100),
 updated_at timestamptz not null default now(), primary key(family_id,user_id),
 foreign key(family_id,user_id) references public.memberships(family_id,user_id) on delete cascade
);
create index locations_user_idx on public.locations(user_id);
create table public.location_history (
 id uuid primary key default gen_random_uuid(), family_id uuid not null, user_id uuid not null,
 latitude double precision not null, longitude double precision not null, recorded_at timestamptz not null default now(),
 foreign key(family_id,user_id) references public.memberships(family_id,user_id) on delete cascade
);
create index history_user_time_idx on public.location_history(user_id,recorded_at desc);
create index history_family_user_idx on public.location_history(family_id,user_id);
create table public.zones (
 id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
 name text not null check(length(trim(name)) between 1 and 60), latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180), radius integer not null check(radius between 100 and 5000),
 created_at timestamptz not null default now()
);
create index zones_family_idx on public.zones(family_id);
create table public.events (
 id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
 actor_id uuid references auth.users(id) on delete set null, kind text not null check(kind in ('sos','zone_enter','zone_exit','joined','left','checkin')),
 message text not null, created_at timestamptz not null default now()
);
create index events_family_time_idx on public.events(family_id,created_at desc);
create index events_actor_idx on public.events(actor_id);
create table public.acknowledgements (
 event_id uuid not null references public.events(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade, created_at timestamptz not null default now(), primary key(event_id,user_id)
);
create index acknowledgements_user_idx on public.acknowledgements(user_id);
create table private.zone_states (
 zone_id uuid not null references public.zones(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade,
 inside boolean not null, primary key(zone_id,user_id)
);

-- Only membership helpers bypass RLS to avoid recursive membership policies.
create function private.is_member(f uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists(select 1 from public.memberships where family_id=f and user_id=auth.uid());
$$;
create function private.is_owner(f uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists(select 1 from public.families where id=f and owner_id=auth.uid());
$$;
create function private.can_see_location(f uuid,u uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and (u=auth.uid() or (private.is_member(f) and exists(select 1 from public.memberships where family_id=f and user_id=u and sharing)));
$$;

alter table public.families enable row level security;
alter table public.memberships enable row level security;
alter table public.locations enable row level security;
alter table public.location_history enable row level security;
alter table public.zones enable row level security;
alter table public.events enable row level security;
alter table public.acknowledgements enable row level security;
alter table private.invitations enable row level security;
alter table private.zone_states enable row level security;
create policy family_read on public.families for select to authenticated using(private.is_member(id));
create policy members_read on public.memberships for select to authenticated using(private.is_member(family_id));
create policy locations_read on public.locations for select to authenticated using(private.can_see_location(family_id,user_id) and updated_at>now()-interval '5 minutes');
create policy history_read on public.location_history for select to authenticated using(user_id=(select auth.uid()) and recorded_at>now()-interval '24 hours');
create policy zones_read on public.zones for select to authenticated using(private.is_member(family_id));
create policy events_read on public.events for select to authenticated using(private.is_member(family_id));
create policy acknowledgements_read on public.acknowledgements for select to authenticated using(exists(select 1 from public.events e where e.id=event_id and private.is_member(e.family_id)));
revoke all on public.families,public.memberships,public.locations,public.location_history,public.zones,public.events,public.acknowledgements from anon,authenticated;
grant select on public.families,public.memberships,public.locations,public.location_history,public.zones,public.events,public.acknowledgements to authenticated;

-- One checked command endpoint. Writes are transactional; no direct client table writes.
create function private.family_command(action text, payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
 actor uuid:=auth.uid(); f uuid; target uuid; label text; token text; invitation private.invitations%rowtype;
 z public.zones%rowtype; was_inside boolean; is_inside boolean; distance_m double precision;
 lat double precision; lon double precision; acc double precision; eid uuid; new_id uuid;
begin
 if actor is null then raise exception 'Sign in required'; end if;
 f:=nullif(payload->>'family_id','')::uuid;
 label:=trim(payload->>'name');
 if action='create_family' then
  if (select count(*) from public.memberships where user_id=actor)>=5 then raise exception 'Maximum of five family groups reached'; end if;
  insert into public.families(name,owner_id) values(label,actor) returning id into f;
  insert into public.memberships(family_id,user_id,display_name) values(f,actor,trim(payload->>'display_name'));
  return jsonb_build_object('family_id',f);
 elsif action='join_family' then
  select * into invitation from private.invitations where token_hash=encode(extensions.digest(payload->>'token','sha256'),'hex') and used_at is null and expires_at>now() for update;
  if not found then raise exception 'Invitation expired or already used'; end if;
  f:=invitation.family_id;
  if private.is_member(f) then raise exception 'You already belong to this family'; end if;
  if (select count(*) from public.memberships where family_id=f)>=20 then raise exception 'Family group is full'; end if;
  if (select count(*) from public.memberships where user_id=actor)>=5 then raise exception 'Maximum of five family groups reached'; end if;
  insert into public.memberships(family_id,user_id,display_name) values(f,actor,trim(payload->>'display_name'));
  update private.invitations set used_at=now() where id=invitation.id;
  insert into public.events(family_id,actor_id,kind,message) values(f,actor,'joined',trim(payload->>'display_name')||' joined the family');
  return jsonb_build_object('family_id',f);
 elsif action='delete_account' then
  delete from auth.sessions where user_id=actor;
  delete from auth.users where id=actor;
  return '{}'::jsonb;
 end if;
 -- Lock own membership so stop-sharing cannot race an in-flight location write.
 perform 1 from public.memberships where family_id=f and user_id=actor for update;
 if not found then raise exception 'Family access denied'; end if;
 select display_name into label from public.memberships where family_id=f and user_id=actor;
 if action='create_invite' then
  if not private.is_owner(f) then raise exception 'Only the family owner can invite members'; end if;
  delete from private.invitations where family_id=f and (expires_at<now() or used_at is not null);
  if (select count(*) from private.invitations where family_id=f)>=20 then raise exception 'Too many active invitations'; end if;
  token:=encode(extensions.gen_random_bytes(32),'hex');
  insert into private.invitations(family_id,token_hash) values(f,encode(extensions.digest(token,'sha256'),'hex'));
  return jsonb_build_object('token',token,'expires_at',now()+interval '24 hours');
 elsif action='revoke_invites' then
  if not private.is_owner(f) then raise exception 'Owner permission required'; end if;
  delete from private.invitations where family_id=f;
 elsif action='sharing' then
  update public.memberships set sharing=(payload->>'enabled')::boolean where family_id=f and user_id=actor;
  if not (payload->>'enabled')::boolean then
   delete from public.locations where family_id=f and user_id=actor;
   delete from private.zone_states where user_id=actor and zone_id in(select id from public.zones where family_id=f);
  end if;
 elsif action='publish_location' then
  if not exists(select 1 from public.memberships where family_id=f and user_id=actor and sharing) then raise exception 'Location sharing is off'; end if;
  if exists(select 1 from public.locations where family_id=f and user_id=actor and updated_at>now()-interval '5 seconds') then return jsonb_build_object('throttled',true); end if;
  lat:=(payload->>'latitude')::double precision; lon:=(payload->>'longitude')::double precision; acc:=(payload->>'accuracy')::double precision;
  if lat is null or lon is null or acc is null or lat not between -90 and 90 or lon not between -180 and 180 or acc not between 0 and 999999 then raise exception 'Invalid coordinates'; end if;
  insert into public.locations(family_id,user_id,latitude,longitude,accuracy,battery) values(f,actor,lat,lon,acc,(payload->>'battery')::smallint)
   on conflict(family_id,user_id) do update set latitude=excluded.latitude,longitude=excluded.longitude,accuracy=excluded.accuracy,battery=excluded.battery,updated_at=now();
  insert into public.location_history(family_id,user_id,latitude,longitude) values(f,actor,lat,lon);
  delete from public.location_history where user_id=actor and (recorded_at<now()-interval '24 hours' or id in(select id from public.location_history where user_id=actor order by recorded_at desc offset 200));
  for z in select * from public.zones where family_id=f loop
   distance_m:=6371000*2*asin(least(1.0,sqrt(power(sin(radians(lat-z.latitude)/2),2)+cos(radians(z.latitude))*cos(radians(lat))*power(sin(radians(lon-z.longitude)/2),2))));
   -- Ignore uncertain fixes and use a 25m hysteresis to reduce boundary jitter.
   if acc>z.radius then continue; end if;
   select inside into was_inside from private.zone_states where zone_id=z.id and user_id=actor;
   is_inside:=case when was_inside is true then distance_m<=z.radius+25 when was_inside is false then distance_m<z.radius-25 else distance_m<=z.radius end;
   if was_inside is not null and was_inside<>is_inside then
    insert into public.events(family_id,actor_id,kind,message) values(f,actor,case when is_inside then 'zone_enter' else 'zone_exit' end,label||case when is_inside then ' entered ' else ' left ' end||z.name);
   end if;
   insert into private.zone_states(zone_id,user_id,inside) values(z.id,actor,is_inside) on conflict(zone_id,user_id) do update set inside=excluded.inside;
  end loop;
 elsif action='sos' or action='checkin' then
  if exists(select 1 from public.events where actor_id=actor and family_id=f and kind=action and created_at>now()-interval '30 seconds') then raise exception 'Please wait 30 seconds before sending again'; end if;
  insert into public.events(family_id,actor_id,kind,message) values(f,actor,action,label||case when action='sos' then ' needs help. Please contact them now.' else ' checked in: I am safe.' end) returning id into eid;
  return jsonb_build_object('event_id',eid);
 elsif action='acknowledge' then
  eid:=(payload->>'event_id')::uuid;
  if not exists(select 1 from public.events where id=eid and family_id=f and kind='sos') then raise exception 'Alert not found'; end if;
  insert into public.acknowledgements(event_id,user_id) values(eid,actor) on conflict do nothing;
 elsif action='add_zone' then
  if not private.is_owner(f) then raise exception 'Only the family owner can manage safe zones'; end if;
  if (select count(*) from public.zones where family_id=f)>=20 then raise exception 'Maximum of 20 safe zones reached'; end if;
  insert into public.zones(family_id,name,latitude,longitude,radius) values(f,trim(payload->>'name'),(payload->>'latitude')::double precision,(payload->>'longitude')::double precision,(payload->>'radius')::integer) returning id into new_id;
  return jsonb_build_object('zone_id',new_id);
 elsif action='delete_zone' then
  if not private.is_owner(f) then raise exception 'Owner permission required'; end if;
  delete from public.zones where id=(payload->>'zone_id')::uuid and family_id=f;
 elsif action='clear_history' then
  delete from public.location_history where family_id=f and user_id=actor;
 elsif action='remove_member' then
  target:=(payload->>'user_id')::uuid;
  if not private.is_owner(f) and target<>actor then raise exception 'Owner permission required'; end if;
  if exists(select 1 from public.families where id=f and owner_id=target) then raise exception 'The owner must delete the family group instead'; end if;
  delete from private.zone_states where user_id=target and zone_id in(select id from public.zones where family_id=f);
  delete from public.memberships where family_id=f and user_id=target;
  insert into public.events(family_id,actor_id,kind,message) values(f,actor,'left','A member left the family group');
 elsif action='delete_family' then
  if not private.is_owner(f) then raise exception 'Owner permission required'; end if;
  delete from public.families where id=f;
 else raise exception 'Unknown action';
 end if;
 return '{}'::jsonb;
end;
$$;
revoke all on all functions in schema private from public,anon;
grant execute on function private.is_member(uuid),private.is_owner(uuid),private.can_see_location(uuid,uuid),private.family_command(text,jsonb) to authenticated;
create function public.family_command(action text,payload jsonb default '{}'::jsonb) returns jsonb language sql security invoker set search_path = '' as $$ select private.family_command(action,payload); $$;
revoke all on function public.family_command(text,jsonb) from public,anon;
grant execute on function public.family_command(text,jsonb) to authenticated;
-- Only events are pushed. Location snapshots are fetched with RLS every 10s, avoiding
-- irreversible coordinate broadcasts and immediately respecting revoked membership.
alter publication supabase_realtime add table public.events;
