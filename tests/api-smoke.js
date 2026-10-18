import assert from 'node:assert/strict';
import {SUPABASE_URL,SUPABASE_KEY} from '../src/config.js';
const headers={apikey:SUPABASE_KEY,'Content-Type':'application/json'};
for(const table of ['families','memberships','locations','location_history','zones','events','acknowledgements']){
 const r=await fetch(`${SUPABASE_URL}/rest/v1/${table}?select=*`,{headers});
 assert.ok([401,403].includes(r.status),`Anonymous read unexpectedly allowed for ${table}: ${r.status}`);
}
const rpc=await fetch(`${SUPABASE_URL}/rest/v1/rpc/family_command`,{method:'POST',headers,body:JSON.stringify({action:'create_family',payload:{name:'Blocked'}})});
assert.ok([401,403].includes(rpc.status),'Anonymous commands must be blocked');
const settings=await fetch(`${SUPABASE_URL}/auth/v1/settings`,{headers});
assert.equal(settings.status,200,'Auth endpoint available');
console.log('PASS: live API blocks anonymous access to all seven tables and command endpoint; Auth is reachable.');
