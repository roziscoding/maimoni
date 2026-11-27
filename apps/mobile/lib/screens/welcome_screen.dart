import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/client.dart';
import '../data/export_file.dart';
import '../main.dart' show navigatorKey;
import '../state/local_mode.dart';
import '../state/toast.dart';
import '../theme.dart';
import '../widgets/backup_prompt.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// The first screen without an account or a session: use the app on this device, or sign in.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _starting = false;

  Future<void> _useLocally() async {
    setState(() => _starting = true);
    try {
      // The gate in MaimoniApp swaps this screen for the setup.
      await LocalMode.instance.start();
    } catch (_) {
      toast('Não foi possível preparar o aparelho', tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Starts without an account from a file exported on another device, skipping the setup.
  Future<void> _import() async {
    try {
      final data = await pickExport();
      if (data == null) return;
      setState(() => _starting = true);
      await LocalMode.instance.start(data: data);
    } catch (err) {
      return toast('Não foi possível importar', description: errorMessage(err), tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
    // The setup that asks about the backup is skipped, so the question comes here, over the app.
    await WidgetsBinding.instance.endOfFrame;
    final root = navigatorKey.currentContext;
    if (root != null && root.mounted) await askForBackup(root);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget hint(String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(text, style: TextStyle(fontSize: 14, color: palette.muted)),
        );
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'maimoni',
                    style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1, color: palette.highlighted),
                  ),
                  const SizedBox(height: 6),
                  Text('Organize as contas do mês e veja quanto você pode gastar por dia.', style: TextStyle(fontSize: 16, color: palette.muted)),
                  const SizedBox(height: 40),
                  ActionButton(label: 'Usar sem conta', loading: _starting, onPressed: _starting ? null : _useLocally),
                  hint('Seus dados ficam só neste aparelho.'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      // No side padding, so the label lines up with the hint above it.
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 48)),
                      onPressed: _starting ? null : _import,
                      child: const Text('Tenho um arquivo exportado'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ActionButton(
                    label: 'Entrar',
                    style: ActionStyle.outline,
                    onPressed: _starting ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
                  ),
                  hint('Com uma conta, seus dados ficam guardados no servidor e você também pode usar o maimoni no navegador.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
