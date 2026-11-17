import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../state/session.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code});

  final String message;
  final int? status;

  /// Better Auth's error code (e.g. `INVALID_EMAIL_OR_PASSWORD`); the app's own routes send none.
  final String? code;

  bool get notFound => status == 404;

  @override
  String toString() => message;
}

/// Message to show for any failure; the server's `{ error }` or `{ message }` when there is one.
String errorMessage(Object error) => error is ApiException ? error.message : 'Erro inesperado';

/// HTTP client for the maimoni server. Every path is resolved against [serverUrl].
class Api {
  Api._();

  static final instance = Api._();

  http.Client _http = http.Client();

  @visibleForTesting
  set httpClient(http.Client client) => _http = client;

  /// Sends a request and decodes the JSON answer. Adds the session's bearer token, stores the token
  /// a sign in or session refresh hands back, and ends the session when a data route answers 401.
  Future<({dynamic data, http.Response response})> request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    var uri = Uri.parse('$serverUrl/api$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final session = Session.instance;
    final token = session.token;
    final request = http.Request(method, uri);
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (headers != null) request.headers.addAll(headers);
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(const Duration(seconds: 30)));
    } on TimeoutException {
      throw ApiException('O servidor demorou demais para responder');
    } catch (error) {
      throw ApiException('Sem conexão com o servidor');
    }
    // Better Auth's bearer plugin sends the token on sign in and when it renews the session. Ignored
    // when the session changed while the request was in flight.
    final issued = response.headers['set-auth-token'];
    if (issued != null && issued.isNotEmpty && session.token == token) session.setToken(issued);
    Object? data;
    try {
      // Decoded as UTF-8 explicitly: without a charset in the content type, `body` falls back to Latin-1.
      final text = utf8.decode(response.bodyBytes);
      data = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      // Not JSON, e.g. a reverse proxy's HTML error page: errors fall back to their status.
      if (response.statusCode < 400) throw ApiException('Resposta inválida do servidor', status: response.statusCode);
    }
    if (response.statusCode >= 400) {
      // Better Auth's own routes answer 401 for wrong credentials, which says nothing about the session.
      // Nor does a 401 for a token the session has already left behind.
      if (response.statusCode == 401 && token != null && session.token == token && !path.startsWith('/auth/')) {
        session.clear(ifToken: token, expired: true);
        // Callers show this next to their own "couldn't save" title, in place of the server's "Unauthorized".
        throw ApiException('Sua sessão expirou. Entre de novo.', status: 401);
      }
      // The app's routes answer `{ error }`, Better Auth's `{ message, code }`.
      final message = data is Map
          ? (data['error'] is String ? data['error'] as String : (data['message'] is String ? data['message'] as String : null))
          : null;
      throw ApiException(
        message ?? 'HTTP ${response.statusCode}',
        status: response.statusCode,
        code: data is Map && data['code'] is String ? data['code'] as String : null,
      );
    }
    return (data: data, response: response);
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async =>
      (await request(method, path, body: body, query: query)).data;

  String _month(int year, int month) => '/months/$year/$month';

  /* --------------------------------- Months -------------------------------- */

  Future<List<MonthListEntry>> months() async =>
      [for (final row in await _send('GET', '/months') as List) MonthListEntry.fromJson(row as Json)];

  Future<MonthDetail> month(int year, int month) async =>
      MonthDetail.fromJson(await _send('GET', _month(year, month)) as Json);

  /// [source] is `template` or `previous`.
  Future<void> createMonth(int year, int month, String source) =>
      _send('POST', '/months', body: {'year': year, 'month': month, 'source': source});

  Future<MonthDetail> updateMonth(int year, int month, Json patch) async =>
      MonthDetail.fromJson(await _send('PATCH', _month(year, month), body: patch) as Json);

  Future<void> deleteMonth(int year, int month) => _send('DELETE', _month(year, month));

  /* ------------------------------- Month items ----------------------------- */

  Future<MonthItem> addItem(int year, int month, Json body) async =>
      MonthItem.fromJson(await _send('POST', '${_month(year, month)}/items', body: body) as Json);

  Future<MonthItem> updateItem(int year, int month, String id, Json patch) async =>
      MonthItem.fromJson(await _send('PATCH', '${_month(year, month)}/items/$id', body: patch) as Json);

  Future<void> deleteItem(int year, int month, String id) => _send('DELETE', '${_month(year, month)}/items/$id');

  Future<TemplateItem> promoteItem(int year, int month, String id) async =>
      TemplateItem.fromJson(await _send('POST', '${_month(year, month)}/items/$id/promote') as Json);

  /* ------------------------------- Daily spends ---------------------------- */

  Future<DailySpend> addSpend(int year, int month, Json body) async =>
      DailySpend.fromJson(await _send('POST', '${_month(year, month)}/spends', body: body) as Json);

  Future<DailySpend> updateSpend(int year, int month, String id, Json patch) async =>
      DailySpend.fromJson(await _send('PATCH', '${_month(year, month)}/spends/$id', body: patch) as Json);

  Future<void> deleteSpend(int year, int month, String id) => _send('DELETE', '${_month(year, month)}/spends/$id');

  /* -------------------------------- Conversions ---------------------------- */

  Future<Conversion> addConversion(int year, int month, Json body) async =>
      Conversion.fromJson(await _send('POST', '${_month(year, month)}/conversions', body: body) as Json);

  Future<Conversion> updateConversion(int year, int month, String id, Json patch) async =>
      Conversion.fromJson(await _send('PATCH', '${_month(year, month)}/conversions/$id', body: patch) as Json);

  Future<void> deleteConversion(int year, int month, String id) =>
      _send('DELETE', '${_month(year, month)}/conversions/$id');

  /* ---------------------------------- Rates -------------------------------- */

  Future<LiveRate> liveRate() async => LiveRate.fromJson(await _send('GET', '/rates/live') as Json);

  /// Pass exactly one of [sendAmount] (BRL) or [recipientGetsAmount] (EUR).
  Future<WiseQuote> quote({double? sendAmount, double? recipientGetsAmount}) async => WiseQuote.fromJson(
        await _send('GET', '/wise/quote', query: {
          if (sendAmount != null) 'sendAmount': '$sendAmount',
          if (recipientGetsAmount != null) 'recipientGetsAmount': '$recipientGetsAmount',
        }) as Json,
      );

  /* --------------------------------- Template ------------------------------ */

  Future<TemplateDetail> template() async => TemplateDetail.fromJson(await _send('GET', '/template') as Json);

  Future<TemplateItem> addTemplateItem(Json body) async =>
      TemplateItem.fromJson(await _send('POST', '/template/items', body: body) as Json);

  Future<TemplateItem> updateTemplateItem(String id, Json patch) async =>
      TemplateItem.fromJson(await _send('PATCH', '/template/items/$id', body: patch) as Json);

  Future<void> deleteTemplateItem(String id) => _send('DELETE', '/template/items/$id');

  Future<List<TemplateItem>> reorderTemplate(List<String> ids) async => [
        for (final row in await _send('PUT', '/template/items/order', body: {'ids': ids}) as List)
          TemplateItem.fromJson(row as Json),
      ];

  /* --------------------------------- Settings ------------------------------ */

  Future<Settings> updateSettings(Json patch) async =>
      Settings.fromJson(await _send('PATCH', '/settings', body: patch) as Json);

  Future<void> clearData() => _send('DELETE', '/data');

  /* ------------------------------- App updates ----------------------------- */

  /// Newest Android release on [channel] (`stable` or `beta`), or `null` when there's none.
  Future<AppRelease?> latestAndroidRelease(String channel) async {
    try {
      return AppRelease.fromJson(await _send('GET', '/app/android/latest', query: {'channel': channel}) as Json);
    } on ApiException catch (err) {
      if (err.notFound) return null;
      rethrow;
    }
  }

  /// Absolute URL for a path the server returned (e.g. an APK download).
  Uri resolve(String path) => Uri.parse(serverUrl).resolve(path);
}
