import test from 'node:test';
import assert from 'node:assert/strict';
import {validateMessage,chatMarkup} from '../src/chat.js';
test('chat rejects blank and oversized messages',()=>{assert.throws(()=>validateMessage('   '));assert.throws(()=>validateMessage('x'.repeat(2001)));assert.equal(validateMessage(' Hello '),'Hello');});
test('chat escapes content and names instead of rendering injected HTML',()=>{const html=chatMarkup([{id:'id',sender_id:'sender',body:'<script>alert(1)</script>',created_at:new Date().toISOString()}],[{user_id:'sender',display_name:'<img src=x>'}],'viewer',false);assert.ok(!html.includes('<script>'));assert.ok(!html.includes('<img src=x>'));assert.match(html,/Report/);assert.match(html,/Hide this person/);assert.ok(!html.includes('data-chat-delete'));});
test('message author and family owner can see delete control',()=>{const msg=[{id:'id',sender_id:'sender',body:'Hi',created_at:new Date().toISOString()}];assert.match(chatMarkup(msg,[],'sender',false),/data-chat-delete/);assert.match(chatMarkup(msg,[],'owner',true),/data-chat-delete/);});
