import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'api/auth.dart';
import 'routes.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_updates.dart';
import 'state/local_mode.dart';
import 'state/months_store.dart';
import 'state/session.dart';
import 'state/currencies_store.dart';
import 'state/theme_controller.dart';
import 'state/toast.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([initializeDateFormatting('pt_BR'), ThemeController.instance.load(), Session.instance.load(), LocalMode.instance.load()]);
  if (LocalMode.instance.active) {
    MonthsStore.instance.refresh();
    CurrenciesStore.instance.refresh();
  } else if (Session.instance.signedIn) {
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
      if (navigator != null && _Gate.current == _Gate.app) openTabWith(navigator, AppTab.settings);
    },
  );
}

class MaimoniApp extends StatefulWidget {
  const MaimoniApp({super.key});

  @override
  State<MaimoniApp> createState() => _MaimoniAppState();
}

/// What the app shows at its root: the welcome screen, the first-run setup or the shell.
enum _Gate {
  welcome,
  onboarding,
  app;

  /// Without an account the device says whether the setup is done; signed in, the server does.
  static _Gate get current {
    final local = LocalMode.instance;
    if (local.active) return local.onboarded ? app : onboarding;
    final session = Session.instance;
    return !session.signedIn ? welcome : (session.onboarded ? app : onboarding);
  }
}

class _MaimoniAppState extends State<MaimoniApp> {
  _Gate _gate = _Gate.current;
  final _gateChanges = Listenable.merge([Session.instance, LocalMode.instance]);

  @override
  void initState() {
    super.initState();
    _gateChanges.addListener(_onGate);
  }

  @override
  void dispose() {
    _gateChanges.removeListener(_onGate);
    super.dispose();
  }

  /// Swaps the whole navigation stack when a session or the local mode starts or ends, so no page
  /// of one survives into the other, and when the user turns out to still have the first-run setup to go through.
  void _onGate() {
    final gate = _Gate.current;
    if (gate == _gate) return;
    final previous = _gate;
    _gate = gate;
    if (previous == _Gate.welcome) {
      MonthsStore.instance.refresh();
      CurrenciesStore.instance.refresh();
    } else if (gate == _Gate.welcome) {
      MonthsStore.instance.reset();
      CurrenciesStore.instance.reset();
      if (Session.instance.expired) toast('Sua sessão expirou', description: 'Entre de novo.');
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
        // The only named route: the welcome screen with neither a session nor the local mode, the
        // first-run setup for a user who hasn't been through it, and the shell otherwise. Everything
        // else is pushed above it.
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (_) => switch (_Gate.current) {
            _Gate.welcome => const WelcomeScreen(),
            _Gate.onboarding => const OnboardingScreen(),
            _Gate.app => const HomeShell(),
          },
        ),
      ),
    );
  }
}
