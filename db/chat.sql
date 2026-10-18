create table public.chat_messages (
 id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 body text not null check(length(trim(body)) between 1 and 2000), created_at timestamptz not null default now()
);
create index chat_family_time_idx on public.chat_messages(family_id,created_at desc);
create index chat_sender_time_idx on public.chat_messages(sender_id,created_at desc);
create table public.chat_blocks (
 family_id uuid not null, blocker_id uuid not null, blocked_id uuid not null,
 primary key(family_id,blocker_id,blocked_id), check(blocker_id<>blocked_id),
 foreign key(family_id,blocker_id) references public.memberships(family_id,user_id) on delete cascade,
 foreign key(family_id,blocked_id) references public.memberships(family_id,user_id) on delete cascade
);
create index chat_blocks_blocked_idx on public.chat_blocks(family_id,blocked_id);
create table public.chat_reports (
 id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
 reporter_id uuid not null references auth.users(id) on delete cascade,
 message_id uuid references public.chat_messages(id) on delete set null,
 reason text not null check(reason in ('spam','harassment','threat','other')), created_at timestamptz not null default now()
);
create index chat_reports_family_idx on public.chat_reports(family_id);
create index chat_reports_reporter_idx on public.chat_reports(reporter_id);
create index chat_reports_message_idx on public.chat_reports(message_id);
alter table public.chat_messages enable row level security;
alter table public.chat_blocks enable row level security;
alter table public.chat_reports enable row level security;
create policy blocks_read on public.chat_blocks for select to authenticated using(blocker_id=(select auth.uid()));
create policy blocks_create on public.chat_blocks for insert to authenticated with check(blocker_id=(select auth.uid()) and private.is_member(family_id));
create policy blocks_remove on public.chat_blocks for delete to authenticated using(blocker_id=(select auth.uid()));
create policy chat_read on public.chat_messages for select to authenticated using(private.is_member(family_id) and not exists(select 1 from public.chat_blocks b where b.family_id=chat_messages.family_id and b.blocker_id=(select auth.uid()) and b.blocked_id=chat_messages.sender_id));
create policy chat_send on public.chat_messages for insert to authenticated with check(sender_id=(select auth.uid()) and private.is_member(family_id));
create policy chat_remove on public.chat_messages for delete to authenticated using(private.is_member(family_id) and (sender_id=(select auth.uid()) or private.is_owner(family_id)));
create policy reports_read on public.chat_reports for select to authenticated using(reporter_id=(select auth.uid()));
create policy reports_create on public.chat_reports for insert to authenticated with check(reporter_id=(select auth.uid()) and private.is_member(family_id) and exists(select 1 from public.chat_messages m where m.id=message_id and m.family_id=chat_reports.family_id));
revoke all on public.chat_messages,public.chat_blocks,public.chat_reports from anon,authenticated;
grant select,delete on public.chat_messages to authenticated;
grant insert(family_id,sender_id,body) on public.chat_messages to authenticated;
grant select,delete on public.chat_blocks to authenticated;
grant insert(family_id,blocker_id,blocked_id) on public.chat_blocks to authenticated;
grant select on public.chat_reports to authenticated;
grant insert(family_id,reporter_id,message_id,reason) on public.chat_reports to authenticated;
create function private.chat_rate_limit() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,1));
 if exists(select 1 from public.chat_messages where sender_id=auth.uid() and created_at>now()-interval '2 seconds') then raise exception 'Please wait two seconds before sending another message'; end if;
 return new;
end; $$;
revoke all on function private.chat_rate_limit() from public,anon,authenticated;
create trigger chat_rate_limit before insert on public.chat_messages for each row execute function private.chat_rate_limit();
-- Poll chat snapshots with fresh RLS. No message bodies are broadcast or cached offline.
