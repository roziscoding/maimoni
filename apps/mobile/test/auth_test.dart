import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maimoni/api/auth.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/state/months_store.dart';
import 'package:maimoni/state/session.dart';

http.Response json(Object? body, {int status = 200, Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

const _user = {'id': 'u1', 'name': 'Ana', 'email': 'ana@example.com'};

const _totals = {'income': 0, 'expenses': 0, 'net': 0, 'paid': 0, 'pending': 0, 'unresolved': 0};

/// A `GET /api/months` row.
const _monthRow = {
  'id': 'm1',
  'year': 2026,
  'month': 10,
  'wiseFee': null,
  'exchangeRate': null,
  'activeDay': null,
  'note': null,
  'createdAt': '2026-10-01T00:00:00.000Z',
  'summary': {
    'brl': _totals,
    'eur': _totals,
    'transfer': {
      'rate': null,
      'rateLocked': false,
      'wiseFee': 0,
      'feeSource': 'fallback',
      'remainingBrl': 0,
      'realized': {'sentBrl': 0, 'convertedBrl': 0, 'feeBrl': 0, 'receivedEur': 0},
      'projected': {'sentBrl': 0, 'feeBrl': 0, 'eur': null},
      'eur': null,
    },
    'allowance': {
      'activeDay': null,
      'days': 31,
      'spentBefore': 0,
      'spentToday': 0,
      'spentTotal': 0,
      'eur': null,
      'remainingEur': null,
      'brl': null,
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Session.instance.clear();
  });

  group('signInEmail', () {
    test('starts the session with the token and the user', () async {
      Map<String, dynamic>? sent;
      Api.instance.httpClient = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return json({'redirect': false, 'token': 'tok', 'user': _user}, headers: {'set-auth-token': 'tok'});
      });
      expect(await signInEmail('ana@example.com', 'secret'), isNull);
      expect(sent, {'email': 'ana@example.com', 'password': 'secret'});
      expect(Session.instance.token, 'tok');
      expect(Session.instance.user?.name, 'Ana');
      expect(Session.instance.user?.email, 'ana@example.com');
    });

    test('takes the token from the body when the header is missing', () async {
      Api.instance.httpClient = MockClient((request) async => json({'redirect': false, 'token': 'raw', 'user': _user}));
      expect(await signInEmail('ana@example.com', 'secret'), isNull);
      expect(Session.instance.token, 'raw');
      expect(Session.instance.user?.email, 'ana@example.com');
    });

    test('fails when the answer carries no token at all', () async {
      Api.instance.httpClient = MockClient((request) async => json({'redirect': false, 'user': _user}));
      expect(await signInEmail('ana@example.com', 'secret'), 'Não foi possível entrar.');
      expect(Session.instance.signedIn, isFalse);
    });

    test('rejects wrong credentials', () async {
      Api.instance.httpClient =
          MockClient((request) async => json({'message': 'Invalid email or password', 'code': 'INVALID_EMAIL_OR_PASSWORD'}, status: 401));
      expect(await signInEmail('ana@example.com', 'wrong'), 'E-mail ou senha incorretos.');
      expect(Session.instance.signedIn, isFalse);
    });

    test('reports rate limiting', () async {
      Api.instance.httpClient = MockClient((request) async => json({'message': 'Too many requests'}, status: 429));
      expect(await signInEmail('ana@example.com', 'secret'), 'Muitas tentativas. Espere um pouco e tente de novo.');
    });

    test('reports a missing connection', () async {
      Api.instance.httpClient = MockClient((request) async => throw http.ClientException('offline'));
      expect(await signInEmail('ana@example.com', 'secret'), 'Sem conexão com o servidor');
    });
  });

  group('checkSession', () {
    test('ends a session the server no longer knows', () async {
      Session.instance.setToken('abc');
      Api.instance.httpClient = MockClient((request) async => json(null));
      await checkSession();
      expect(Session.instance.signedIn, isFalse);
      expect(Session.instance.expired, isTrue);
    });

    test('loads the signed in user', () async {
      Session.instance.setToken('abc');
      Api.instance.httpClient = MockClient((request) async => json({'session': {'token': 'abc'}, 'user': _user}));
      await checkSession();
      expect(Session.instance.token, 'abc');
      expect(Session.instance.user?.name, 'Ana');
      expect(Session.instance.user?.email, 'ana@example.com');
    });

    test('keeps the session when offline', () async {
      Session.instance.setToken('abc');
      Api.instance.httpClient = MockClient((request) async => throw http.ClientException('offline'));
      await checkSession();
      expect(Session.instance.token, 'abc');
    });

    test('ignores an answer that arrives after another session started', () async {
      Session.instance.setToken('abc');
      Api.instance.httpClient = MockClient((request) async {
        Session.instance.clear();
        Session.instance.setToken('other');
        return json({'session': {'token': 'abc'}, 'user': _user});
      });
      await checkSession();
      expect(Session.instance.token, 'other');
      expect(Session.instance.user, isNull);
    });
  });

  test('a months answer that arrives after the session ended is dropped', () async {
    Session.instance.setToken('abc');
    MonthsStore.instance.reset();
    Api.instance.httpClient = MockClient((request) async {
      MonthsStore.instance.reset();
      return json([_monthRow]);
    });
    await MonthsStore.instance.refresh();
    expect(MonthsStore.instance.months, isEmpty);
    expect(MonthsStore.instance.loaded, isFalse);
    expect(MonthsStore.instance.error, isNull);

    // The same answer within a session is kept, so the row above is one the app can read.
    Api.instance.httpClient = MockClient((request) async => json([_monthRow]));
    await MonthsStore.instance.refresh();
    expect(MonthsStore.instance.months, hasLength(1));
    MonthsStore.instance.reset();
  });

  test('signOut clears the session first and sends the old bearer', () async {
    Session.instance.setToken('abc');
    String? path;
    String? authorization;
    bool? signedInWhenSent;
    Api.instance.httpClient = MockClient((request) async {
      path = request.url.path;
      authorization = request.headers['authorization'];
      signedInWhenSent = Session.instance.signedIn;
      return json({'success': true});
    });
    signOut();
    expect(Session.instance.signedIn, isFalse);
    expect(Session.instance.expired, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(path, '/api/auth/sign-out');
    expect(authorization, 'Bearer abc');
    expect(signedInWhenSent, isFalse);
    expect(Session.instance.pendingSignOuts, isEmpty);
  });

  test('a sign out the server never heard of is sent again later', () async {
    await Session.instance.load();
    Session.instance.setToken('abc');
    Api.instance.httpClient = MockClient((request) async => throw Exception('offline'));
    signOut();
    await Future<void>.delayed(Duration.zero);
    expect(Session.instance.signedIn, isFalse);
    expect(Session.instance.pendingSignOuts, ['abc']);

    // The token survives a restart, apart from the session's own.
    await Session.instance.load();
    expect(Session.instance.signedIn, isFalse);
    expect(Session.instance.pendingSignOuts, ['abc']);

    // A server error leaves it for the next try.
    Api.instance.httpClient = MockClient((request) async => json({'error': 'down'}, status: 503));
    await confirmSignOuts();
    expect(Session.instance.pendingSignOuts, ['abc']);

    // A new session doesn't change whose sign out is sent.
    Session.instance.setToken('new');
    final sent = <String?>[];
    Api.instance.httpClient = MockClient((request) async {
      sent.add(request.headers['authorization']);
      return json({'success': true});
    });
    await confirmSignOuts();
    expect(sent, ['Bearer abc']);
    expect(Session.instance.pendingSignOuts, isEmpty);
    expect(Session.instance.token, 'new');
    await Session.instance.load();
    expect(Session.instance.pendingSignOuts, isEmpty);
  });

  test('a sign out the server refuses is not sent again', () async {
    await Session.instance.load();
    Session.instance.setToken('abc');
    Api.instance.httpClient = MockClient((request) async => json({'message': 'Unauthorized'}, status: 401));
    signOut();
    await Future<void>.delayed(Duration.zero);
    expect(Session.instance.pendingSignOuts, isEmpty);
  });
}
