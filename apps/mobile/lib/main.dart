import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'routes.dart';
import 'state/app_updates.dart';
import 'state/months_store.dart';
import 'state/theme_controller.dart';
import 'state/toast.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([initializeDateFormatting('pt_BR'), ThemeController.instance.load()]);
  MonthsStore.instance.refresh();
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
      if (navigator != null) navigateWith(navigator, settingsRoute);
    },
  );
}

class MaimoniApp extends StatelessWidget {
  const MaimoniApp({super.key});

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
        onGenerateRoute: onGenerateRoute,
      ),
    );
  }
}
