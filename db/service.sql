-- Service operators are assigned by the database owner, never user metadata.
create table private.service_operators(user_id uuid primary key references auth.users(id) on delete cascade);
alter table private.service_operators enable row level security;
revoke all on private.service_operators from public,anon,authenticated;
create table private.service_audit(id bigint generated always as identity primary key,operator_id uuid,action text not null,target_id uuid,created_at timestamptz not null default now());
alter table private.service_audit enable row level security;
revoke all on private.service_audit from public,anon,authenticated;
create table public.support_requests(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,body text not null check(length(trim(body)) between 10 and 2000),status text not null default 'open' check(status in ('open','closed')),reply text check(length(reply)<=2000),created_at timestamptz not null default now(),reviewed_at timestamptz);
create index support_user_time on public.support_requests(user_id,created_at desc);
alter table public.support_requests enable row level security;
create policy support_read on public.support_requests for select to authenticated using(user_id=(select auth.uid()));
revoke all on public.support_requests from public,anon,authenticated;
grant select on public.support_requests to authenticated;
alter table public.chat_reports add column status text not null default 'open' check(status in ('open','removed','dismissed')),add column reviewed_at timestamptz,add column message_body text;
create function private.capture_report() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or new.reporter_id<>auth.uid() or not private.is_member(new.family_id) then raise exception 'Not allowed'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,12));
 if exists(select 1 from public.chat_reports where reporter_id=auth.uid() and created_at>now()-interval '10 seconds') then raise exception 'Please wait before submitting another report'; end if;
 select m.body into new.message_body from public.chat_messages m where m.id=new.message_id and m.family_id=new.family_id;
 if new.message_body is null then raise exception 'Message unavailable'; end if;
 new.status:='open';new.reviewed_at:=null;return new;
end;$$;
revoke all on function private.capture_report() from public,anon,authenticated;
create trigger capture_report before insert on public.chat_reports for each row execute function private.capture_report();
create function private.service_command(action text,payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();op boolean;target uuid;decision text;body_text text;result jsonb;report public.chat_reports;
begin
 if actor is null then raise exception 'Sign in required'; end if;
 select exists(select 1 from private.service_operators where user_id=actor) into op;
 if action='operator_status' then return jsonb_build_object('operator',op); end if;
 if action='my_tickets' then select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc),'[]'::jsonb) into result from(select id,body,status,reply,created_at from public.support_requests where user_id=actor order by created_at desc limit 30)t;return result;end if;
 if action='create_ticket' then
 body_text:=trim(payload->>'body');if body_text is null or length(body_text) not between 10 and 2000 then raise exception 'Please use 10 to 2,000 characters';end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,13));
 if exists(select 1 from public.support_requests where user_id=actor and created_at>now()-interval '1 minute') then raise exception 'Please wait one minute before sending another request';end if;
 insert into public.support_requests(user_id,body) values(actor,body_text) returning id into target;return jsonb_build_object('id',target);
 end if;
 if not op then raise exception 'Operator access required';end if;
 if action='queue' then return jsonb_build_object('reports',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from(select id,reason,message_body,created_at from public.chat_reports where status='open' order by created_at limit 100)t),'tickets',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from(select id,body,created_at from public.support_requests where status='open' order by created_at limit 100)t));end if;
 target:=(payload->>'id')::uuid;
 if action='review_report' then
 decision:=payload->>'decision';if decision is null or decision not in ('remove','dismiss') then raise exception 'Invalid decision';end if;
 select * into report from public.chat_reports where id=target for update;
 if not found or report.status<>'open' then raise exception 'Report already reviewed or unavailable';end if;
 if decision='remove' then delete from public.chat_messages where id=report.message_id;end if;
 update public.chat_reports set status=case when decision='remove' then 'removed' else 'dismissed' end,reviewed_at=now() where id=target;
 elsif action='reply_ticket' then
 body_text:=trim(payload->>'reply');if body_text is null or length(body_text) not between 1 and 2000 then raise exception 'Reply required';end if;
 update public.support_requests set reply=body_text,status='closed',reviewed_at=now() where id=target and status='open';if not found then raise exception 'Request already closed or unavailable';end if;
 else raise exception 'Unknown service action';end if;
 insert into private.service_audit(operator_id,action,target_id) values(actor,action,target);return '{}'::jsonb;
end;$$;
revoke all on function private.service_command(text,jsonb) from public,anon,authenticated;
grant execute on function private.service_command(text,jsonb) to authenticated;
create function public.service_command(action text,payload jsonb default '{}'::jsonb) returns jsonb language sql security invoker set search_path='' as $$ select private.service_command(action,payload); $$;
revoke all on function public.service_command(text,jsonb) from public,anon;
grant execute on function public.service_command(text,jsonb) to authenticated;
