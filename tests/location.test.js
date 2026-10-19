import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createNativeLocationProvider,temporaryLocationError,locationError} from '../src/location-provider.js';
const fix={coords:{latitude:6,longitude:7,accuracy:20}};
test('GPS switch off does not prevent Android position/settings resolution',async()=>{
 let requested=false;const client=createNativeLocationProvider({checkPermissions:async()=>{throw {code:'OS-PLUG-GLOC-0007'};},getCurrentPosition:async()=>{requested=true;return fix;}});
 assert.equal(await client.position(),fix);assert.equal(requested,true);
});
test('approximate permission is accepted without a second fine-permission request',async()=>{
 let options;const client=createNativeLocationProvider({checkPermissions:async()=>({location:'denied',coarseLocation:'granted'}),getCurrentPosition:async o=>{options=o;return fix;}});
 await client.position();assert.equal(options.enableHighAccuracy,false);
});
test('slow high accuracy fix retries once using balanced accuracy',async()=>{
 const calls=[];const client=createNativeLocationProvider({checkPermissions:async()=>({location:'granted'}),getCurrentPosition:async o=>{calls.push(o);if(calls.length===1)throw {code:'OS-PLUG-GLOC-0010'};return fix;}});
 assert.equal(await client.position(),fix);assert.deepEqual(calls.map(c=>c.enableHighAccuracy),[true,false]);
});
test('permission denial is actionable and is never retried',async()=>{
 let calls=0;const client=createNativeLocationProvider({checkPermissions:async()=>({location:'denied'}),getCurrentPosition:async()=>{calls++;throw {code:'OS-PLUG-GLOC-0003'};}});
 await assert.rejects(client.position(),/Permissions → Location/);assert.equal(calls,1);
});
test('foreground updates retry transient failures and stop after cancellation',async()=>{
 const jobs=[],errors=[],positions=[];let calls=0;
 const client=createNativeLocationProvider({checkPermissions:async()=>({location:'granted'}),getCurrentPosition:async()=>{if(++calls===1)throw {code:'OS-PLUG-GLOC-0010'};return fix;}},{setTimeout:fn=>{jobs.push(fn);return jobs.length;},clearTimeout:()=>{}});
 const id=await client.watch(p=>positions.push(p),e=>errors.push(e));
 await jobs.shift()();assert.equal(temporaryLocationError(errors[0]),true);assert.equal(jobs.length,1);
 await jobs.shift()();assert.deepEqual(positions,[fix]);client.clear(id);await jobs.shift()();assert.equal(calls,2);
 assert.equal(temporaryLocationError(locationError({code:'OS-PLUG-GLOC-0003'})),false);
});
test('revoked permission ends foreground polling instead of prompting repeatedly',async()=>{
 const jobs=[];const client=createNativeLocationProvider({checkPermissions:async()=>({location:'granted'}),getCurrentPosition:async()=>{throw {code:'OS-PLUG-GLOC-0003'};}},{setTimeout:fn=>{jobs.push(fn);return 1;},clearTimeout:()=>{}});
 await client.watch(()=>{},()=>{});await jobs.shift()();assert.equal(jobs.length,0);
});
