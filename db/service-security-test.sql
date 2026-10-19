begin;
insert into auth.users(id,email) values('30000000-0000-4000-8000-000000000001','service-test@familytrack.test'),('30000000-0000-4000-8000-000000000002','service-other@familytrack.test');
insert into private.service_operators(user_id) values('30000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
do $$declare blocked boolean:=false;begin
 if (public.service_command('operator_status')->>'operator')::boolean then raise exception 'Nonoperator elevated';end if;
 begin perform public.service_command('queue');exception when others then blocked:=true;end;
 if not blocked then raise exception 'Nonoperator can read queue';end if;
 perform set_config('test.ticket',public.service_command('create_ticket','{"body":"Please help with this test issue"}')->>'id',true);
 if jsonb_array_length(public.service_command('my_tickets'))<>1 then raise exception 'Ticket not visible';end if;
 blocked:=false;begin perform public.service_command('create_ticket','{"body":"Second rapid support request"}');exception when others then blocked:=true;end;
 if not blocked then raise exception 'Support rate limit failed';end if;
end$$;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
do $$begin
 if jsonb_array_length(public.service_command('my_tickets'))<>0 then raise exception 'Cross account ticket leak';end if;
 if not exists(select 1 from jsonb_array_elements(public.service_command('queue')->'tickets')t where t->>'id'=current_setting('test.ticket')) then raise exception 'Operator cannot see queue';end if;
 perform public.service_command('reply_ticket',jsonb_build_object('id',current_setting('test.ticket'),'reply','Resolved test issue'));
end$$;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
do $$begin
 if not exists(select 1 from jsonb_array_elements(public.service_command('my_tickets'))t where t->>'reply'='Resolved test issue' and t->>'status'='closed') then raise exception 'Reply unavailable';end if;
end$$;
reset role;
rollback;
select 'PASS: operator authorization, ticket isolation, support rate limit and reply' as result;
