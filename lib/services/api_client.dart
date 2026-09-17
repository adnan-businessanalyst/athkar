import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_hosts.dart';
import 'token_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({TokenStore? tokens, http.Client? httpClient, this.baseUrl = AppHosts.apiUrl})
    : tokens = tokens ?? SecureTokenStore(),
      _http = httpClient ?? http.Client();

  final TokenStore tokens;
  final http.Client _http;
  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final access = await tokens.readAccess();
      if (access != null && access.isNotEmpty) {
        headers['Authorization'] = 'Bearer $access';
      }
    }
    return headers;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = false,
  }) {
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    return _headers(auth: auth).then((headers) {
      switch (method) {
        case 'GET':
          return _http.get(uri, headers: headers);
        case 'POST':
          return _http.post(uri, headers: headers, body: encoded);
        case 'DELETE':
          return _http.delete(uri, headers: headers);
        default:
          throw ApiException('Unsupported method');
      }
    });
  }

  Future<bool> refreshTokens() async {
    final refresh = await tokens.readRefresh();
    final email = await tokens.readEmail();
    if (refresh == null || refresh.isEmpty) return false;
    final response = await _send(
      'POST',
      '/auth/refresh',
      body: {'refresh_token': refresh},
    );
    if (response.statusCode != 200) return false;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await tokens.save(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
      email: email ?? (data['user'] as Map<String, dynamic>?)?['email'] as String? ?? '',
    );
    return true;
  }

  Future<http.Response> _authed(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    var response = await _send(
      method,
      path,
      body: body,
      query: query,
      auth: true,
    );
    if (response.statusCode == 401 && await refreshTokens()) {
      response = await _send(
        method,
        path,
        body: body,
        query: query,
        auth: true,
      );
    }
    return response;
  }

  Map<String, dynamic> _map(http.Response response) {
    if (response.statusCode == 204 || response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException('Unexpected response', status: response.statusCode);
  }

  String _detail(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
    } catch (_) {}
    return 'تعذر الاتصال بالخادم.';
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final response = auth
        ? await _authed('POST', path, body: body)
        : await _send('POST', path, body: body);
    if (response.statusCode >= 400) {
      throw ApiException(_detail(response), status: response.statusCode);
    }
    return _map(response);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final response = await _authed('GET', path, query: query);
    if (response.statusCode >= 400) {
      throw ApiException(_detail(response), status: response.statusCode);
    }
    return _map(response);
  }

  Future<void> delete(String path, {bool auth = true}) async {
    final response = await _authed('DELETE', path);
    if (response.statusCode >= 400) {
      throw ApiException(_detail(response), status: response.statusCode);
    }
  }
}
