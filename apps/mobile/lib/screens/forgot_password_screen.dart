import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// The web's `/forgot-password`. Asks for the link only; the new password is set on the web page it opens.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  /// What was typed on the login screen, to start from.
  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  String? _emailError;
  String? _failure;
  bool _loading = false;

  /// The address the request was made for, once it went through.
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _email.text.trim();
    setState(() {
      _emailError = RegExp(r'^\S+@\S+\.\S+$').hasMatch(email) ? null : 'Informe um e-mail válido';
      _failure = null;
    });
    if (_emailError != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final failure = await requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failure = failure;
      if (failure == null) _sentTo = email;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sentTo = _sentTo;
    return Scaffold(
      appBar: AppBar(title: const Text('Redefinir senha')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sentTo != null
                    ? [
                        Callout(
                          icon: LucideIcons.mailCheck,
                          title: 'Confira seu e-mail',
                          description: 'Se existir uma conta para $sentTo, enviamos um link para redefinir a senha. Ele vale por 1 hora.',
                          tone: Tone.success,
                        ),
                        const SizedBox(height: 16),
                        ActionButton(label: 'Voltar para o login', style: ActionStyle.subtle, onPressed: () => Navigator.of(context).pop()),
                      ]
                    : [
                        Text('Informe seu e-mail para receber um link de redefinição.', style: TextStyle(fontSize: 16, color: palette.muted)),
                        const SizedBox(height: 24),
                        if (_failure != null) ...[
                          Callout(icon: LucideIcons.circleAlert, title: _failure!, tone: Tone.error),
                          const SizedBox(height: 16),
                        ],
                        const FieldLabel('E-mail'),
                        TextField(
                          controller: _email,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.email],
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(errorText: _emailError),
                        ),
                        const SizedBox(height: 24),
                        ActionButton(label: 'Enviar link', loading: _loading, onPressed: _submit),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
