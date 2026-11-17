import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maimoni/api/auth.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/screens/forgot_password_screen.dart';
import 'package:maimoni/screens/login_screen.dart';
import 'package:maimoni/state/session.dart';
import 'package:maimoni/theme.dart';
import 'package:maimoni/widgets/common.dart';

http.Response json(Object? body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Widget _app(Widget home) => MaterialApp(theme: buildTheme(Brightness.light), home: home);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
  });

  group('requestPasswordReset', () {
    test('posts the email and accepts a 204', () async {
      String? path;
      Map<String, dynamic>? sent;
      Api.instance.httpClient = MockClient((request) async {
        path = request.url.path;
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('', 204);
      });
      expect(await requestPasswordReset('ana@example.com'), isNull);
      expect(path, '/api/password-reset');
      expect(sent, {'email': 'ana@example.com'});
    });

    test('maps a validation error', () async {
      Api.instance.httpClient = MockClient((request) async => json({'error': 'Invalid email'}, status: 400));
      expect(await requestPasswordReset('ana@example'), 'Informe um e-mail válido');
    });

    test('maps a server error', () async {
      Api.instance.httpClient = MockClient((request) async => json({'error': 'boom'}, status: 500));
      expect(await requestPasswordReset('ana@example.com'), 'Não foi possível enviar o link.');
    });

    test('reports a missing connection', () async {
      Api.instance.httpClient = MockClient((request) async => throw http.ClientException('offline'));
      expect(await requestPasswordReset('ana@example.com'), 'Sem conexão com o servidor');
    });
  });

  testWidgets('the login screen opens the reset screen with the typed email', (tester) async {
    Api.instance.httpClient = MockClient((request) async => json(const []));
    await tester.pumpWidget(_app(const LoginScreen()));
    await tester.enterText(find.byType(TextField).first, ' ana@example.com ');
    await tester.tap(find.text('Esqueceu a senha?'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('Redefinir senha'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'ana@example.com'), findsOneWidget);
  });

  testWidgets('a sent request shows the confirmation', (tester) async {
    Api.instance.httpClient = MockClient((request) async => http.Response('', 204));
    await tester.pumpWidget(_app(const ForgotPasswordScreen(email: 'ana@example.com')));
    await tester.tap(find.text('Enviar link'));
    await tester.pumpAndSettle();
    expect(find.text('Confira seu e-mail'), findsOneWidget);
    expect(
      find.text('Se existir uma conta para ana@example.com, enviamos um link para redefinir a senha. Ele vale por 1 hora.'),
      findsOneWidget,
    );
    expect(find.text('Voltar para o login'), findsOneWidget);
    expect(find.text('Enviar link'), findsNothing);
  });

  testWidgets('a malformed email is rejected without a request', (tester) async {
    var calls = 0;
    Api.instance.httpClient = MockClient((request) async {
      calls++;
      return http.Response('', 204);
    });
    await tester.pumpWidget(_app(const ForgotPasswordScreen()));
    await tester.enterText(find.byType(TextField), 'ana@example');
    await tester.tap(find.text('Enviar link'));
    await tester.pump();
    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('a failed request shows a callout and keeps the form', (tester) async {
    Api.instance.httpClient = MockClient((request) async => json({'error': 'boom'}, status: 500));
    await tester.pumpWidget(_app(const ForgotPasswordScreen(email: 'ana@example.com')));
    await tester.tap(find.text('Enviar link'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Callout, 'Não foi possível enviar o link.'), findsOneWidget);
    expect(find.text('Enviar link'), findsOneWidget);
    expect(find.text('Confira seu e-mail'), findsNothing);
  });
}
