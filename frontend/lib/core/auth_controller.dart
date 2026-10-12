import 'package:flutter/foundation.dart';

import 'api_client.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.api);
  final ApiClient api;

  Map<String, dynamic>? user;
  bool loading = true;
  bool get signedIn => user != null && api.hasToken;

  Future<void> restoreSession() async {
    try {
      final token = await api.readToken();
      if (token != null && token.isNotEmpty) {
        user = Map<String, dynamic>.from(await api.get('auth/me/'));
      }
    } catch (_) {
      await api.clearToken();
      user = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final result = Map<String, dynamic>.from(
      await api.post('auth/login/', {
        'email': email.trim(),
        'password': password,
      }),
    );
    await api.saveToken(result['token'] as String);
    user = Map<String, dynamic>.from(result['user'] as Map);
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final result = Map<String, dynamic>.from(
      await api.post('auth/register/', {
        'email': email.trim(),
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
      }),
    );
    await api.saveToken(result['token'] as String);
    user = Map<String, dynamic>.from(result['user'] as Map);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    user = Map<String, dynamic>.from(await api.get('auth/me/'));
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('auth/logout/');
    } catch (_) {
      // Clear the local session even if the API is unavailable or the token expired.
    } finally {
      await api.clearToken();
      user = null;
      notifyListeners();
    }
  }
}
