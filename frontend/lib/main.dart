import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthController(ApiClient());
  runApp(
    ChangeNotifierProvider.value(value: auth, child: const ReContentApp()),
  );
  auth.restoreSession();
}
