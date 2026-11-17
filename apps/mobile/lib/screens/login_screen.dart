import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// The web's `/login`. Shown for every route while signed out; signing in swaps it for the app.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _failure;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _emailError = RegExp(r'^\S+@\S+\.\S+$').hasMatch(email) ? null : 'Informe um e-mail válido';
      _passwordError = password.isEmpty ? 'Informe a senha' : null;
      _failure = null;
    });
    if (_emailError != null || _passwordError != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final failure = await signInEmail(email, password);
    // On success the app replaces this screen, so there is nothing left to update.
    if (mounted) {
      setState(() {
        _loading = false;
        _failure = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'maimoni',
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: palette.highlighted),
                    ),
                    const SizedBox(height: 4),
                    Text('Entre com seu e-mail e senha.', style: TextStyle(fontSize: 14, color: palette.muted)),
                    const SizedBox(height: 24),
                    if (_failure != null) ...[
                      Callout(icon: LucideIcons.circleAlert, title: _failure!, tone: Tone.error),
                      const SizedBox(height: 16),
                    ],
                    const FieldLabel('E-mail'),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(errorText: _emailError),
                    ),
                    const SizedBox(height: 16),
                    const FieldLabel('Senha'),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(errorText: _passwordError),
                    ),
                    const SizedBox(height: 24),
                    ActionButton(label: 'Entrar', loading: _loading, onPressed: _submit),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
