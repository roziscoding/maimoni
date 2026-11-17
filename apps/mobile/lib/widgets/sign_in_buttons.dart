import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Height of every sign in button below the form: the height of Google's button and of the app's
/// own. Apple doesn't allow its button to be smaller than the others, and ties its title's size to
/// the height.
const signInButtonHeight = 40.0;

/// "Continue with Google", drawn to Google's branding guidelines
/// (https://developers.google.com/identity/branding-guidelines): the light theme's fill, stroke
/// and text colors, Google Sans Medium 14/20, and the standard color "G" from Google's asset
/// bundle. The light theme is used on dark backgrounds too, where it matches the app's own white
/// buttons; Google's themes aren't tied to the app's.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const text = Color(0xFF1F1F1F);
    // Google's paddings: 16/12/16 on iOS, 12/10/12 on Android.
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final edge = ios ? 16.0 : 12.0;
    return _ProviderButton(
      fill: Colors.white,
      border: const Color(0xFF747775),
      onPressed: loading ? null : onPressed,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: edge),
        // Scales the logo and the title together when a large text size wouldn't fit the width.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 20,
                child: loading
                    ? const Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2, color: text))
                    : Image.asset('assets/sign-in/google-g.png'),
              ),
              SizedBox(width: ios ? 12 : 10),
              Text(
                'Continuar com o Google',
                style: GoogleFonts.googleSans(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, color: text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Continue with Apple": the `sign_in_with_apple` package's button, which follows Apple's
/// guidelines (https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)
/// and draws the logo itself, so no Apple artwork is kept in the repository. Black on a light
/// background and white on a dark one; the title is Apple's own wording for pt-BR.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final button = SignInWithAppleButton(
      text: 'Continuar com a Apple',
      height: signInButtonHeight,
      style: dark ? SignInWithAppleButtonStyle.white : SignInWithAppleButtonStyle.black,
      onPressed: loading ? null : onPressed,
    );
    if (!loading) return button;
    // The package's button has no loading state: dim it and put the spinner over it.
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.4, child: button),
        SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: dark ? Colors.black : Colors.white),
        ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({required this.fill, required this.onPressed, required this.child, this.border});

  final Color fill;
  final Color? border;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: border == null ? BorderSide.none : BorderSide(color: border!),
    );
    return Material(
      color: fill,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(height: signInButtonHeight, width: double.infinity, child: Center(child: child)),
      ),
    );
  }
}
