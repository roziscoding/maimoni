import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// "Continue with Apple", drawn to Apple's guidelines for a custom button
/// (https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple): black on a
/// light background and white on a dark one, Apple's logo artwork at the button's full height, and
/// a title at 43% of that height. The title is Apple's own wording for pt-BR.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = dark ? Colors.black : Colors.white;
    return _ProviderButton(
      fill: dark ? Colors.white : Colors.black,
      onPressed: loading ? null : onPressed,
      // The logo file has its own side padding; Apple asks for at least 8% of the width after the title.
      child: FractionallySizedBox(
        widthFactor: 0.84,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The artwork is 31x44, rendered from Apple's vector file at this height. It must fill
              // the button's height, with no cropping and no vertical padding.
              SizedBox(
                width: signInButtonHeight * 31 / 44,
                height: signInButtonHeight,
                child: loading
                    ? Center(child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: content)))
                    : Image.asset('assets/sign-in/apple-logo-${dark ? 'black' : 'white'}.png'),
              ),
              Text(
                'Continuar com a Apple',
                style: TextStyle(fontSize: signInButtonHeight * 0.43, fontWeight: FontWeight.w500, color: content),
              ),
            ],
          ),
        ),
      ),
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
