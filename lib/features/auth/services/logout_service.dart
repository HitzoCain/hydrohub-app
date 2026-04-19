import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aqua_in_laba_app/features/customer/customer_session.dart';
import 'package:aqua_in_laba_app/features/driver/driver_session.dart';
import 'package:aqua_in_laba_app/features/auth/screens/login_screen.dart';

Future<void> logoutAndRedirectToLogin(BuildContext context) async {
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (error) {
    debugPrint('Logout signOut error: $error');
  } finally {
    await CustomerSession.clear();
    await DriverSession.clear();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}