import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/auth_controller.dart';
import 'core/firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseConfigured = false;
  if (kIsWeb && FirebaseConfig.isConfigured) {
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      firebaseConfigured = true;
    } catch (error) {
      debugPrint('Firebase initialization failed: $error');
    }
  }

  final auth = AuthController(
    ApiClient(),
    firebaseConfigured: firebaseConfigured,
  );
  runApp(
    ChangeNotifierProvider.value(value: auth, child: const ReContentApp()),
  );
  auth.restoreSession();
}
