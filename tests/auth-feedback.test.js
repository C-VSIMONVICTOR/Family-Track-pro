import test from 'node:test';
import assert from 'node:assert/strict';
import {authErrorMessage,validationMessage} from '../src/auth-feedback.js';
test('registration rate limit points existing users to original email and sign-in',()=>{const message=authErrorMessage({code:'over_email_send_rate_limit'});assert.match(message,/sending limit/);assert.match(message,/original confirmation email/);assert.match(message,/sign in/);});
test('unconfirmed email explains confirmation and broken redirect recovery',()=>{const message=authErrorMessage({code:'email_not_confirmed'});assert.match(message,/localhost/);assert.match(message,/return here/);});
test('password and terms validation give a visible reason instead of silent submit',()=>{assert.match(validationMessage({name:'terms',checked:false}),/accept the terms/);assert.match(validationMessage({name:'password',validity:{tooShort:true},minLength:12}),/12 characters/);assert.match(validationMessage({name:'email',validity:{typeMismatch:true}}),/valid email/);});
test('unrecognized provider errors retain their useful message',()=>assert.equal(authErrorMessage({message:'Invalid login credentials'}),'Invalid login credentials'));
