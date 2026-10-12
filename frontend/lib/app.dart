import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/auth_controller.dart';
import 'features/auth/auth_page.dart';
import 'features/dashboard/app_shell.dart';

class ReContentApp extends StatelessWidget {
  const ReContentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReContent AI',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Consumer<AuthController>(
        builder: (context, auth, _) {
          if (auth.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return auth.signedIn ? const AppShell() : const AuthPage();
        },
      ),
    );
  }
}
