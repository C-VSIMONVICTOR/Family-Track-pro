export function authErrorMessage(error) {
  if(error?.code==='over_email_send_rate_limit') return 'The email service has reached its sending limit. If you already registered, open your original confirmation email, then sign in. Repeated registration attempts will not fix this. Please try again later if you need another email.';
  if(error?.code==='email_not_confirmed') return 'Your email needs confirmation. Open the confirmation email, then return here and sign in. If the email opens a localhost page, confirmation may still have succeeded; return here and try signing in.';
  if(error?.code==='email_address_not_authorized') return 'Registration email delivery is not configured for this address. The service owner must configure the email provider.';
  if(error?.code==='user_already_exists') return 'An account already exists for this email. Sign in instead, or reset your password.';
  if(error?.name==='AbortError'||error?.name==='TimeoutError') return 'The request timed out. Check your connection and try again. If you registered, check your email before submitting again.';
  return error?.message || 'Something went wrong. Please try again.';
}
export function validationMessage(input) {
  if(input.name==='chat_terms'&&!input.checked)return 'Please agree to the chat rules before sending a message.';
  if(input.name==='body'&&input.validity?.valueMissing)return 'Type a message first.';
  if(input.name==='terms'&&!input.checked)return 'Please accept the terms to create your account.';
  if(input.validity?.tooShort)return `Please use at least ${input.minLength} characters for ${input.name==='password'?'your password':'this field'}.`;
  if(input.validity?.typeMismatch)return 'Please enter a valid email address.';
  if(input.validity?.valueMissing)return `Please enter ${input.name==='name'?'your name':input.name==='email'?'your email address':'your password'}.`;
  return input.validationMessage || 'Please check the highlighted field.';
}
