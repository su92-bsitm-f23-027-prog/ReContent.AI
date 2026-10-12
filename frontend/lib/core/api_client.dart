import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _configuredUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );
  static const _tokenKey = 'recontent_access_token';
  final http.Client _client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;

  String get baseUrl => _configuredUrl.replaceAll(RegExp(r'/$'), '');
  bool get hasToken => _token?.isNotEmpty ?? false;

  Future<String?> readToken() async {
    _token = await _storage.read(key: _tokenKey);
    return _token;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  Map<String, String> _headers({bool json = true}) => {
    if (json) 'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (hasToken) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> get(String path) async {
    final response = await _client.get(
      _uri(path),
      headers: _headers(json: false),
    );
    return _decode(response);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decode(response);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final response = await _client.patch(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _client.delete(
      _uri(path),
      headers: _headers(json: false),
    );
    return _decode(response);
  }

  Future<dynamic> upload(
    String path, {
    required Map<String, String> fields,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll({
        'Accept': 'application/json',
        if (hasToken) 'Authorization': 'Bearer $_token',
      })
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
    final response = await http.Response.fromStream(await request.send());
    return _decode(response);
  }

  Uri _uri(String path) =>
      Uri.parse('$baseUrl/${path.replaceFirst(RegExp(r'^/'), '')}');

  dynamic _decode(http.Response response) {
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = response.body;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_message(data), statusCode: response.statusCode);
    }
    return data;
  }

  String _message(dynamic data) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      final first = data.values.firstOrNull;
      if (first is List && first.isNotEmpty) return first.first.toString();
      if (first is String) return first;
    }
    return 'The request could not be completed. Please try again.';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
