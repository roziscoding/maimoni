import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth.dart';
import '../api/providers.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';
import '../widgets/sign_in_buttons.dart';
import 'forgot_password_screen.dart';

/// The web's `/login`, opened from the welcome screen; signing in swaps it for the app.
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
  bool _showPassword = false;
  List<String> _providers = const [];
  String? _busyProvider;

  bool get _busy => _loading || _busyProvider != null;
  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  bool get _mobile => _ios || defaultTargetPlatform == TargetPlatform.android;
  bool get _google => _mobile && _providers.contains('google') && googleWebClientId.isNotEmpty && (!_ios || googleIosClientId.isNotEmpty);
  // Apple's native sheet only exists on iOS.
  bool get _apple => _ios && _providers.contains('apple');

  @override
  void initState() {
    super.initState();
    signInProviders().then((value) {
      if (mounted) setState(() => _providers = value);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
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

  Future<void> _social(String provider, Future<ProviderToken?> Function() ask) async {
    setState(() {
      _busyProvider = provider;
      _failure = null;
    });
    String? failure;
    try {
      final credential = await ask();
      // Null: the person closed the provider's sheet.
      if (credential != null) failure = await signInSocial(provider, token: credential.token, nonce: credential.nonce);
    } catch (_) {
      failure = 'Não foi possível entrar com essa conta.';
    }
    if (mounted) {
      setState(() {
        _busyProvider = null;
        _failure = failure;
      });
    }
  }

  Future<void> _passkey() async {
    setState(() {
      _busyProvider = 'passkey';
      _failure = null;
    });
    final failure = await signInPasskey();
    if (mounted) {
      setState(() {
        _busyProvider = null;
        _failure = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      // Opened from the welcome screen, which it goes back to.
      appBar: Navigator.of(context).canPop() ? AppBar() : null,
      body: SafeArea(
        // From the top, like any other screen; only a tablet is wide enough to need the limit.
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'maimoni',
                      style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1, color: palette.highlighted),
                    ),
                    const SizedBox(height: 6),
                    Text('Entre com seu e-mail e senha.', style: TextStyle(fontSize: 16, color: palette.muted)),
                    const SizedBox(height: 32),
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
                      obscureText: !_showPassword,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        errorText: _passwordError,
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Esconder a senha' : 'Mostrar a senha',
                          icon: Icon(_showPassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 20),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ForgotPasswordScreen(email: _email.text.trim()))),
                        child: const Text('Esqueceu a senha?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ActionButton(label: 'Entrar', loading: _loading, onPressed: _submit),
                    // The passkey button is always there on a phone, so the separator is too.
                    if (_mobile) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ou', style: TextStyle(fontSize: 12, color: palette.muted)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Apple's button only shows on iOS, where it comes first.
                      if (_apple) ...[
                        AppleSignInButton(
                          loading: _busyProvider == 'apple',
                          onPressed: _busy ? null : () => _social('apple', appleIdToken),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_google) ...[
                        GoogleSignInButton(
                          loading: _busyProvider == 'google',
                          onPressed: _busy ? null : () => _social('google', googleIdToken),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        height: signInButtonHeight,
                        child: ActionButton(
                          label: 'Entrar com passkey',
                          icon: LucideIcons.keyRound,
                          style: ActionStyle.outline,
                          loading: _busyProvider == 'passkey',
                          onPressed: _busy ? null : _passkey,
                        ),
                      ),
                    ],
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
