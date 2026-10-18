import {escapeHTML as e,age} from './utils.js';
export function chatMarkup(messages,members,uid,owner){
 if(!messages.length)return '<div class="empty"><strong>Say hello to your family.</strong>Messages sent here are visible only to current members of this family.</div>';
 return messages.map(m=>{const own=m.sender_id===uid,member=members.find(x=>x.user_id===m.sender_id);return `<article class="chat-message ${own?'mine':''}"><div class="chat-bubble"><strong>${own?'You':e(member?.display_name||'Former member')}</strong><p>${e(m.body)}</p><time datetime="${e(m.created_at)}">${e(age(m.created_at))}</time></div><div class="chat-tools">${own||owner?`<button type="button" class="text-button" data-chat-delete="${m.id}">Delete</button>`:''}${!own?`<button type="button" class="text-button" data-chat-report="${m.id}">Report</button><button type="button" class="text-button" data-chat-block="${m.sender_id}">Hide this person’s messages</button>`:''}</div></article>`;}).join('');
}
export function validateMessage(value){const body=String(value||'').trim();if(!body)throw Error('Type a message first.');if(body.length>2000)throw Error('Keep your message under 2,000 characters.');return body;}
