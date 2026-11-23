// The app, signed in, against a fake server kept in memory: every screen can be opened and used
// without a backend or an account. Run it with `mise run mobile:preview:android` (or `:ios`).
//
// It lives outside `lib/` so no build of the real app can pick it up. The data is made around
// today's date, and every change is lost when the app closes.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maimoni/api/client.dart';
import 'package:maimoni/api/models.dart';
import 'package:maimoni/domain/summary.dart';
import 'package:maimoni/main.dart';
import 'package:maimoni/state/currencies_store.dart';
import 'package:maimoni/state/months_store.dart';
import 'package:maimoni/state/session.dart';
import 'package:maimoni/state/theme_controller.dart';

final _today = DateTime.now();

/// The month [back] months before this one.
DateTime _monthAgo(int back) => DateTime(_today.year, _today.month - back);

String _key(DateTime month) => '${month.year}/${month.month}';

var _ids = 0;
String _id() => 'p${_ids++}';

final _currencies = <Json>[
  {'currency': 'EUR', 'enabled': true, 'main': true, 'inUse': true},
  {'currency': 'BRL', 'enabled': true, 'main': false, 'inUse': true},
];

final _rates = {
  'base': 'EUR',
  'rates': {'BRL': 6.2134, 'USD': 1.0812},
  'source': 'frankfurter',
  'fetchedAt': _today.toUtc().toIso8601String(),
  'stale': false,
};

/// Starts as a user who never set anything up, so the app opens on the first-run setup.
const _onboarding = bool.fromEnvironment('PREVIEW_ONBOARDING');

/// The main currency chosen in the setup; EUR until there is one.
String get _main => _currencies.where((entry) => entry['main'] == true).firstOrNull?['currency'] as String? ?? 'EUR';

/// [_rates] quoted against the main currency, which in the setup is whichever the person chose.
/// Only the three currencies above have a rate; any other goes without one.
Json get _liveRates {
  const perEuro = {'EUR': 1.0, 'BRL': 6.2134, 'USD': 1.0812};
  final base = perEuro[_main];
  if (base == null) return {..._rates, 'base': _main, 'rates': <String, double>{}};
  return {
    ..._rates,
    'base': _main,
    'rates': {
      for (final MapEntry(:key, :value) in perEuro.entries)
        if (key != _main) key: value / base,
    },
  };
}

Json _item(String name, String currency, String kind, num? amount, {bool paid = false, bool review = false, String? expression, bool variable = false}) => {
      'id': _id(),
      'monthId': 'm',
      'templateItemId': null,
      'name': name,
      'currency': currency,
      'kind': kind,
      'amount': amount,
      'expression': expression,
      'paid': paid,
      'needsReview': review,
      'variable': variable,
      'position': _ids,
    };

Json _spend(int day, num amount, String? note, {String currency = 'EUR', String? expression}) => {
      'id': _id(),
      'monthId': 'm',
      'day': day,
      'currency': currency,
      'amount': amount,
      'expression': expression,
      'note': note,
      // Only the order matters: spends of a day are listed by when they were entered.
      'createdAt': DateTime.utc(2000, 1, day, 12, 0, _ids % 60, _ids % 1000).toIso8601String(),
    };

List<Json> _baseItems({bool allPaid = false}) => [
      _item('Salário', 'EUR', 'income', 3200, paid: true),
      _item('Aluguel', 'EUR', 'expense', 950, paid: true),
      _item('Internet', 'EUR', 'expense', 39.9, paid: true),
      _item('Energia', 'EUR', 'expense', 80, review: !allPaid, paid: allPaid),
      _item('Cartão de crédito', 'EUR', 'expense', allPaid ? 612.4 : null, review: !allPaid, paid: allPaid),
      _item('Academia', 'EUR', 'expense', 35, paid: allPaid),
      _item('Streaming', 'EUR', 'expense', 17.98, expression: '11,99+5,99', paid: allPaid),
      _item('Freela', 'BRL', 'income', 2500, paid: allPaid),
      _item('Plano de saúde', 'BRL', 'expense', 480, paid: true),
    ];

Json _month(DateTime date, {int? activeDay, List<Json>? spends, String? note, bool allPaid = false}) => {
      'month': {
        'id': _id(),
        'year': date.year,
        'month': date.month,
        'mainCurrency': 'EUR',
        'lockedRates': allPaid ? {'BRL': 6.05} : <String, double>{},
        'activeDay': activeDay,
        'note': note,
        'createdAt': DateTime.utc(date.year, date.month).toIso8601String(),
      },
      'items': _baseItems(allPaid: allPaid),
      'spends': spends ?? <Json>[],
      'rates': _rates,
      'rateError': null,
    };

final _months = <String, Json>{
  // This month, with today open and a few spends on every day before it.
  _key(_today): _month(_today, activeDay: _today.day, note: 'Seguro do carro vence no fim do mês.', spends: [
    for (var day = 1; day < _today.day; day++) ...[
      _spend(day, 12 + (day * 7) % 31, const ['Mercado', 'Almoço', 'Padaria', 'Farmácia'][day % 4]),
      if (day % 3 == 0) _spend(day, 6.5 + day % 5, 'Café'),
      if (day % 9 == 0) _spend(day, 180, 'Presente', currency: 'BRL'),
    ],
    _spend(_today.day, 4.5, 'Café'),
    _spend(_today.day, 23.8, 'Mercado', expression: '18,30+5,50'),
    _spend(_today.day, 45, 'Uber', currency: 'BRL'),
  ]),
  // Closed months: one with daily spends, one without, and one from a year before for the list by year.
  _key(_monthAgo(1)): _month(_monthAgo(1), allPaid: true, spends: [for (var day = 1; day <= 28; day++) _spend(day, 20 + (day * 5) % 23, 'Mercado')]),
  _key(_monthAgo(2)): _month(_monthAgo(2), allPaid: true),
  _key(_monthAgo(12)): _month(_monthAgo(12), allPaid: true),
};

final _template = <Json>[
  for (final item in _baseItems())
    {
      ...item,
      'variable': item['name'] == 'Energia' || item['name'] == 'Cartão de crédito',
      'amount': item['name'] == 'Cartão de crédito' ? null : item['amount'],
    },
];

Json _summaryJson(Json detail) {
  final parsed = MonthDetail.fromJson(detail);
  final summary = summarizeMonth(parsed.month, parsed.items, rates: parsed.rates?.rates, spends: parsed.spends);
  return {
    'main': summary.main.code,
    'totals': {
      for (final MapEntry(:key, :value) in summary.totals.entries)
        key.code: {
          'income': value.income,
          'expenses': value.expenses,
          'net': value.net,
          'paid': value.paid,
          'pending': value.pending,
          'unresolved': value.unresolved,
        },
    },
    'rates': ratesToJson(summary.rates),
    'conversions': [
      for (final entry in summary.conversions)
        {'currency': entry.currency.code, 'rate': entry.rate, 'rateLocked': entry.rateLocked, 'net': entry.net, 'converted': entry.converted},
    ],
    'converted': summary.converted,
    'net': summary.net,
    'allowance': {
      'activeDay': summary.allowance.activeDay,
      'days': summary.allowance.days,
      'spentBefore': summary.allowance.spentBefore,
      'spentToday': summary.allowance.spentToday,
      'spentTotal': summary.allowance.spentTotal,
      'amount': summary.allowance.amount,
      'remaining': summary.allowance.remaining,
    },
  };
}

http.Response _json(Object? body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

Future<http.Response> _serve(http.Request request) async {
  await Future<void>.delayed(const Duration(milliseconds: 120));
  final segments = request.url.pathSegments.skip(1).toList(); // drops `api`
  final path = segments.join('/');
  final method = request.method;
  final body = request.body.isEmpty ? null : jsonDecode(request.body);

  if (path == 'months' && method == 'GET') {
    final keys = _months.keys.toList()
      ..sort((a, b) {
        int index(String key) => int.parse(key.split('/')[0]) * 12 + int.parse(key.split('/')[1]);
        return index(b).compareTo(index(a));
      });
    return _json([
      for (final key in keys) {...(_months[key]!['month'] as Json), 'summary': _summaryJson(_months[key]!)},
    ]);
  }
  if (path == 'months' && method == 'POST') {
    final year = body['year'] as int;
    final month = body['month'] as int;
    final created = _month(DateTime(year, month), activeDay: null);
    // After the setup, the month is made of what the person entered, in the currency they chose.
    if (_onboarding) {
      created['month'] = {...(created['month'] as Json), 'mainCurrency': _main};
      created['items'] = [
        for (final item in _template) {...item, 'id': _id(), 'templateItemId': item['id'], 'paid': false, 'needsReview': item['variable'] == true},
      ];
      created['rates'] = _liveRates;
    }
    _months['$year/$month'] = created;
    return _json(created, 201);
  }
  if (segments.length >= 3 && segments[0] == 'months') {
    final key = '${segments[1]}/${segments[2]}';
    final detail = _months[key];
    if (detail == null) return _json({'error': 'Not found'}, 404);
    if (segments.length == 3) {
      if (method == 'DELETE') {
        _months.remove(key);
        return http.Response('', 204);
      }
      if (method == 'PATCH') detail['month'] = {...(detail['month'] as Json), ...(body as Json)};
      return _json(detail);
    }
    final list = detail[segments[3]] as List<Json>;
    if (segments.length == 4 && method == 'POST') {
      final created = segments[3] == 'items'
          ? {..._item('', 'EUR', 'expense', null), ...(body as Json)}
          : {..._spend(body['day'] as int, 0, null), ...(body as Json)};
      list.add(created);
      return _json(created, 201);
    }
    final index = list.indexWhere((row) => row['id'] == segments[4]);
    if (segments.length == 6) return _json({...list[index], 'variable': false});
    if (method == 'DELETE') {
      list.removeAt(index);
      return http.Response('', 204);
    }
    list[index] = {...list[index], ...(body as Json), if ((body).containsKey('amount')) 'needsReview': false};
    return _json(list[index]);
  }
  if (path == 'template') return _json({'items': _template});
  if (path == 'template/items/order') {
    final ids = (body['ids'] as List).cast<String>();
    for (final item in _template) {
      item['position'] = ids.indexOf(item['id'] as String);
    }
    return _json(_template);
  }
  if (path == 'template/items' && method == 'POST') {
    _template.add({..._item('', 'EUR', 'expense', null), ...(body as Json)});
    return _json(_template.last, 201);
  }
  if (segments.length == 3 && segments[0] == 'template') {
    final index = _template.indexWhere((row) => row['id'] == segments[2]);
    if (method == 'DELETE') {
      _template.removeAt(index);
      return http.Response('', 204);
    }
    _template[index] = {..._template[index], ...(body as Json)};
    return _json(_template[index]);
  }
  if (path == 'rates/live') return _json(_liveRates);
  if (path == 'auth/update-user') return _json({'status': true});
  if (path == 'settings/currencies' && method == 'GET') return _json(_currencies);
  if (path == 'settings/currencies' && method == 'PUT') {
    final used = {for (final item in _template) item['currency']};
    _currencies
      ..clear()
      ..addAll([
        for (final entry in (body['currencies'] as List).cast<Json>())
          {'currency': entry['currency'], 'enabled': entry['enabled'], 'main': entry['currency'] == body['main'], 'inUse': used.contains(entry['currency'])},
      ]);
    return _json(_currencies);
  }
  if (path == 'settings/currencies' && method == 'POST') {
    _currencies.add({'currency': body['currency'], 'enabled': true, 'main': false, 'inUse': false});
    return _json(_currencies.last, 201);
  }
  if (segments.length == 3 && segments[1] == 'currencies') {
    final row = _currencies.firstWhere((entry) => entry['currency'] == segments[2]);
    if (method == 'DELETE') {
      _currencies.remove(row);
      return http.Response('', 204);
    }
    if ((body as Json)['main'] == true) {
      for (final other in _currencies) {
        other['main'] = false;
      }
    }
    row.addAll(body);
    return _json(_currencies);
  }
  if (path == 'flags') return _json({'purge': true});
  if (path == 'sessions' && method == 'GET') {
    return _json([
      {'id': 's1', 'current': true, 'userAgent': 'maimoni-app (android)', 'ipAddress': '203.0.113.7', 'createdAt': _today.subtract(const Duration(days: 3)).toUtc().toIso8601String()},
      {
        'id': 's2',
        'current': false,
        'userAgent': 'Mozilla/5.0 (X11; Linux x86_64) Chrome/142.0.0.0 Safari/537.36',
        'ipAddress': '203.0.113.9',
        'createdAt': _today.subtract(const Duration(days: 21)).toUtc().toIso8601String(),
      },
    ]);
  }
  return _json({'error': 'Not found'}, 404);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The same seam the tests use to answer the app's requests.
  // ignore: invalid_use_of_visible_for_testing_member
  Api.instance.httpClient = MockClient(_serve);
  await Future.wait([initializeDateFormatting('pt_BR'), ThemeController.instance.load()]);
  const signedOut = bool.fromEnvironment('PREVIEW_SIGNED_OUT');
  if (_onboarding) {
    _currencies.clear();
    _template.clear();
    _months.clear();
  }
  if (!signedOut) {
    Session.instance.setToken('preview');
    Session.instance.setUser(const SessionUser(name: 'Ana Prévia', email: 'ana@example.com', onboarded: !_onboarding));
    MonthsStore.instance.refresh();
    CurrenciesStore.instance.refresh();
  }
  runApp(const MaimoniApp());
}
