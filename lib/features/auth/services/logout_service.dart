import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aqua_in_laba_app/features/customer/customer_session.dart';
import 'package:aqua_in_laba_app/features/driver/driver_session.dart';
import 'package:aqua_in_laba_app/features/auth/screens/login_screen.dart';

Future<void> logoutAndRedirectToLogin(BuildContext context) async {
  final navigator = Navigator.of(context);
  var canNavigate = false;

  try {
    await Supabase.instance.client.auth.signOut();
  } catch (error) {
    debugPrint('Logout signOut error: $error');
  } finally {
    await CustomerSession.clear();
    await DriverSession.clear();

    canNavigate = context.mounted;
  }

  if (!canNavigate) {
    return;
  }

  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}