import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/state/session.dart';

http.Response json(Object? body, {int status = 200, Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
  });

  test('sends the stored token as a bearer', () async {
    Session.instance.setToken('abc');
    String? authorization;
    Api.instance.httpClient = MockClient((request) async {
      authorization = request.headers['authorization'];
      return json([]);
    });
    await Api.instance.months();
    expect(authorization, 'Bearer abc');
  });

  test('stores the token from set-auth-token', () async {
    Api.instance.httpClient = MockClient((request) async => json({'token': 'xyz'}, headers: {'set-auth-token': 'xyz'}));
    await Api.instance.request('POST', '/auth/sign-in/email', body: {'email': 'a@b.c', 'password': 'p'});
    expect(Session.instance.token, 'xyz');
    await Future<void>.delayed(Duration.zero);
    expect(await const FlutterSecureStorage().read(key: 'session_token'), 'xyz');
  });

  test('a 401 from a data route ends the session as expired', () async {
    Session.instance.setToken('abc');
    Api.instance.httpClient = MockClient((request) async => json({'error': 'Unauthorized'}, status: 401));
    await expectLater(
      Api.instance.months(),
      throwsA(isA<ApiException>().having((error) => error.message, 'message', 'Sua sessão expirou. Entre de novo.')),
    );
    expect(Session.instance.token, isNull);
    expect(Session.instance.expired, isTrue);
  });

  test('a 401 from an auth route keeps the session', () async {
    Session.instance.setToken('abc');
    Api.instance.httpClient =
        MockClient((request) async => json({'message': 'Invalid email or password', 'code': 'INVALID_EMAIL_OR_PASSWORD'}, status: 401));
    await expectLater(Api.instance.request('POST', '/auth/sign-in/email', body: {}), throwsA(isA<ApiException>()));
    expect(Session.instance.token, 'abc');
  });

  test('a late 401 from an earlier session keeps the new one', () async {
    Session.instance.setToken('old');
    Api.instance.httpClient = MockClient((request) async {
      Session.instance.setToken('new');
      return json({'error': 'Unauthorized'}, status: 401);
    });
    await expectLater(Api.instance.months(), throwsA(isA<ApiException>()));
    expect(Session.instance.token, 'new');
  });

  test('a late set-auth-token from an earlier session keeps the new one', () async {
    Session.instance.setToken('old');
    Api.instance.httpClient = MockClient((request) async {
      Session.instance.setToken('new');
      return json([], headers: {'set-auth-token': 'renewed-old'});
    });
    await Api.instance.months();
    expect(Session.instance.token, 'new');
  });

  test("reads Better Auth's message and code", () async {
    Api.instance.httpClient =
        MockClient((request) async => json({'message': 'Invalid email or password', 'code': 'INVALID_EMAIL_OR_PASSWORD'}, status: 401));
    final error = await Api.instance.request('POST', '/auth/sign-in/email', body: {}).then<Object?>((_) => null, onError: (Object e) => e);
    expect(error, isA<ApiException>());
    error as ApiException;
    expect(error.message, 'Invalid email or password');
    expect(error.code, 'INVALID_EMAIL_OR_PASSWORD');
    expect(error.status, 401);
  });

  test("reads the app's own { error }", () async {
    Api.instance.httpClient = MockClient((request) async => json({'error': 'Unauthorized'}, status: 401));
    final error = await Api.instance.months().then<Object?>((_) => null, onError: (Object e) => e);
    expect(error, isA<ApiException>());
    expect((error as ApiException).message, 'Unauthorized');
  });
}
