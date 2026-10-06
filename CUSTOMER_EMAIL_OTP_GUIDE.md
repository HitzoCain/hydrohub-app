# Customer Email OTP (Flutter and Dart)

Customer signup opens a six-digit code screen. Supabase sends and verifies the code; the app does not store it. After successful verification, the existing customer auth flow handles the session and profile sync.

## Supabase setup

1. In the Supabase Dashboard, open **Authentication > Sign In / Providers > Email** and enable email confirmations.
2. Open **Authentication > Email Templates > Confirm signup**. Replace the current link-based subject and body (the ones containing text like “follow this link” or `{{ .ConfirmationURL }}`) with a code-based message. For example:

   ```html
  Subject: Your Aqua In Lavada verification code

   <p>Your Aqua In Lavada verification code is: <strong>{{ .Token }}</strong></p>
   ```

  The important part is `{{ .Token }}`. Remove the confirmation-link button/text and `{{ .ConfirmationURL }}` from this template. Save the template. The email should contain a six-digit number, not “follow this link to confirm your user.”
3. Confirm the project's email OTP length is six digits and set an appropriate OTP expiry in the Auth settings. The app's 60-second resend timer is only a user-interface cooldown.
4. Configure delivery before testing with customer addresses. Supabase's built-in email service is for development: it only sends to email addresses authorized for the project team and has a very low rate limit (currently about two messages per hour; limits can change). The dashboard's **Emails** page warns when this built-in service is active. For customers, configure a provider such as Resend under **Authentication > Emails > SMTP Settings** and use a sender address on a domain verified with that provider.
5. Emails already delivered will not change when you update the template. After changing templates or SMTP settings, return to the app and use **Resend code** after the cooldown, or create a fresh test signup. Check spam if the new message does not arrive.
6. Never put SMTP credentials or a Supabase `service_role` key in the Flutter application. Configure mail credentials only in the Supabase Dashboard, and protect customer profile and application data with database RLS policies.

## Dart auth calls

Signup calls `Supabase.instance.client.auth.signUp(...)`. The OTP screen verifies with:

```dart
await Supabase.instance.client.auth.verifyOTP(
  type: OtpType.signup,
  email: email,
  token: sixDigitCode,
);
```

Resending calls `auth.resend(type: OtpType.signup, email: email)` after its local 60-second cooldown. Invalid or expired codes are reported in the UI, and the user can request another code when the cooldown ends.