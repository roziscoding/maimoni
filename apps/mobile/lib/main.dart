import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'api/auth.dart';
import 'routes.dart';
import 'screens/login_screen.dart';
import 'state/app_updates.dart';
import 'state/months_store.dart';
import 'state/session.dart';
import 'state/currencies_store.dart';
import 'state/theme_controller.dart';
import 'state/toast.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([initializeDateFormatting('pt_BR'), ThemeController.instance.load(), Session.instance.load()]);
  if (Session.instance.signedIn) {
    MonthsStore.instance.refresh();
    CurrenciesStore.instance.refresh();
    checkSession();
  }
  confirmSignOuts();
  runApp(const MaimoniApp());
  _offerUpdate();
}

/// On Android, tells the person when a newer release is out; Settings downloads and installs it.
Future<void> _offerUpdate() async {
  final updates = AppUpdates.instance;
  await updates.load();
  final release = await updates.check();
  if (release == null) return;
  toast(
    'Versão ${release.version} disponível',
    icon: LucideIcons.download,
    duration: const Duration(seconds: 10),
    actionLabel: 'Ver',
    onAction: () {
      final navigator = navigatorKey.currentState;
      if (navigator != null && Session.instance.signedIn) navigateWith(navigator, settingsRoute);
    },
  );
}

class MaimoniApp extends StatefulWidget {
  const MaimoniApp({super.key});

  @override
  State<MaimoniApp> createState() => _MaimoniAppState();
}

class _MaimoniAppState extends State<MaimoniApp> {
  bool _signedIn = Session.instance.signedIn;

  @override
  void initState() {
    super.initState();
    Session.instance.addListener(_onSession);
  }

  @override
  void dispose() {
    Session.instance.removeListener(_onSession);
    super.dispose();
  }

  /// Swaps the whole navigation stack when a session starts or ends, so no page of one survives into the other.
  void _onSession() {
    final session = Session.instance;
    if (session.signedIn == _signedIn) return;
    _signedIn = session.signedIn;
    if (_signedIn) {
      MonthsStore.instance.refresh();
      CurrenciesStore.instance.refresh();
    } else {
      MonthsStore.instance.reset();
      CurrenciesStore.instance.reset();
      if (session.expired) toast('Sua sessão expirou', description: 'Entre de novo.');
    }
    navigatorKey.currentState?.pushNamedAndRemoveUntil(todayRoute, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) => MaterialApp(
        title: 'maimoni',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver],
        scaffoldMessengerKey: messengerKey,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        initialRoute: todayRoute,
        // Signed out, every route is the login screen: no page that needs a session can be reached.
        onGenerateRoute: (settings) =>
            Session.instance.signedIn ? onGenerateRoute(settings) : MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      ),
    );
  }
}
