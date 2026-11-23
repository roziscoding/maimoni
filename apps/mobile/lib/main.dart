import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'api/auth.dart';
import 'routes.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
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
      if (navigator != null && Session.instance.signedIn) openTabWith(navigator, AppTab.settings);
    },
  );
}

class MaimoniApp extends StatefulWidget {
  const MaimoniApp({super.key});

  @override
  State<MaimoniApp> createState() => _MaimoniAppState();
}

/// What the app shows at its root: the login screen, the first-run setup or the shell.
enum _Gate {
  signedOut,
  onboarding,
  app;

  static _Gate of(Session session) => !session.signedIn ? signedOut : (session.onboarded ? app : onboarding);
}

class _MaimoniAppState extends State<MaimoniApp> {
  _Gate _gate = _Gate.of(Session.instance);

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

  /// Swaps the whole navigation stack when a session starts or ends, so no page of one survives
  /// into the other, and when the user turns out to still have the first-run setup to go through.
  void _onSession() {
    final session = Session.instance;
    final gate = _Gate.of(session);
    if (gate == _gate) return;
    final previous = _gate;
    _gate = gate;
    if (previous == _Gate.signedOut) {
      MonthsStore.instance.refresh();
      CurrenciesStore.instance.refresh();
    } else if (gate == _Gate.signedOut) {
      MonthsStore.instance.reset();
      CurrenciesStore.instance.reset();
      if (session.expired) toast('Sua sessão expirou', description: 'Entre de novo.');
    }
    // The setup ends on a screen of its own, which opens the app when its button is tapped.
    if (previous == _Gate.onboarding && gate == _Gate.app) return;
    shellTab.value = AppTab.today;
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
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
        // The only named route: the login screen without a session, the first-run setup for a user
        // who hasn't been through it, and the shell otherwise. Everything else is pushed above the shell.
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (_) => switch (_Gate.of(Session.instance)) {
            _Gate.signedOut => const LoginScreen(),
            _Gate.onboarding => const OnboardingScreen(),
            _Gate.app => const HomeShell(),
          },
        ),
      ),
    );
  }
}
