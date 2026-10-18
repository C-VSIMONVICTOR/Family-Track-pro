-- Run as postgres in a disposable transaction. All fixture data rolls back.
begin;
insert into auth.users(id,email) values
 ('10000000-0000-4000-8000-000000000001','owner@familytrack.test'),
 ('10000000-0000-4000-8000-000000000002','member@familytrack.test'),
 ('10000000-0000-4000-8000-000000000003','outsider@familytrack.test');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
do $$
declare f uuid; token text; failed boolean:=false; result jsonb;
begin
 result:=public.family_command('create_family','{"name":"Test Family","display_name":"Owner"}');
 f:=(result->>'family_id')::uuid;
 perform set_config('test.family',f::text,true);
 token:=public.family_command('create_invite',jsonb_build_object('family_id',f))->>'token';
 perform set_config('test.token',token,true);
 perform public.family_command('add_zone',jsonb_build_object('family_id',f,'name','Home','latitude',6.5,'longitude',3.3,'radius',200));
 perform public.family_command('sharing',jsonb_build_object('family_id',f,'enabled',true));
 perform public.family_command('publish_location',jsonb_build_object('family_id',f,'latitude',6.5,'longitude',3.3,'accuracy',10));
 if (select count(*) from public.locations)<>1 then raise exception 'Owner location missing'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
do $$
declare blocked boolean:=false;
begin
 if exists(select 1 from public.families) or exists(select 1 from public.memberships) or exists(select 1 from public.locations) or exists(select 1 from public.zones) then raise exception 'Outsider can read family data'; end if;
 begin perform public.family_command('sos',jsonb_build_object('family_id',current_setting('test.family'))); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Outsider can send alerts'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
do $$
declare f uuid:=current_setting('test.family')::uuid; blocked boolean:=false;
begin
 perform public.family_command('join_family',jsonb_build_object('token',current_setting('test.token'),'display_name','Member'));
 if (select count(*) from public.memberships)<>2 then raise exception 'Invitation failed'; end if;
 if (select count(*) from public.locations)<>1 then raise exception 'Shared location not visible to family'; end if;
 if exists(select 1 from public.location_history) then raise exception 'Member can read another person history'; end if;
 begin perform public.family_command('create_invite',jsonb_build_object('family_id',f)); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Member can invite'; end if;
 blocked:=false;
 begin perform public.family_command('publish_location',jsonb_build_object('family_id',f,'latitude',0,'longitude',0,'accuracy',10)); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Can publish without consent'; end if;
 blocked:=false;
 begin insert into public.locations(family_id,user_id,latitude,longitude,accuracy) values(f,'10000000-0000-4000-8000-000000000001',0,0,10); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Can spoof location by direct table write'; end if;
 perform public.family_command('sos',jsonb_build_object('family_id',f));
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
do $$
declare blocked boolean:=false;
begin
 begin perform public.family_command('join_family',jsonb_build_object('token',current_setting('test.token'),'display_name','Replay')); exception when others then blocked:=true; end;
 if not blocked then raise exception 'Invitation can be replayed'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select public.family_command('sharing',jsonb_build_object('family_id',current_setting('test.family'),'enabled',false));
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
do $$ begin
 if exists(select 1 from public.locations) then raise exception 'Stopped sharing still visible'; end if;
 if (select count(*) from public.events where kind='sos')<>1 then raise exception 'Family SOS missing'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select public.family_command('remove_member',jsonb_build_object('family_id',current_setting('test.family'),'user_id','10000000-0000-4000-8000-000000000002'));
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
do $$ begin
 if exists(select 1 from public.families) or exists(select 1 from public.events) then raise exception 'Removed member retains access'; end if;
end $$;
reset role;
rollback;
select 'PASS: isolation, consent, invitations, anti-spoofing, SOS, and membership revocation' as result;
