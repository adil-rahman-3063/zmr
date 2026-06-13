import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'yt_login_webview.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../widgets/zmr_snackbar.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shellVisibilityOverrideProvider.notifier).setState(false);
    });
  }

  @override
  void dispose() {
    // Restore shell visibility when leaving this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.context.mounted) {
        ref.read(shellVisibilityOverrideProvider.notifier).setState(true);
      }
    });
    super.dispose();
  }

  void _showDocumentDialog(BuildContext context, String title, String assetPath) async {
    String content = "";
    try {
      content = await rootBundle.loadString(assetPath);
    } catch (e) {
      content = "Could not load document: $e";
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: GlassmorphicContainer(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.7,
            borderRadius: 24,
            blur: 20,
            border: 1.5,
            linearGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withAlpha(200),
                Colors.black.withAlpha(150),
              ],
            ),
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withAlpha(128),
                Theme.of(context).colorScheme.primary.withAlpha(26),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        content,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/login.jpg',
              fit: BoxFit.cover,
            ),
          ),
          
          // Blur and Dark Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                color: Theme.of(context).colorScheme.surface.withAlpha(160), // Dark overlay
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  // Logo: Minimal White on Black
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Iconsax.music, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'ZMR',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 500.ms).slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 64),
                  Text(
                    'Unlock your Music',
                    style: GoogleFonts.outfit(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ).animate().fade(delay: 200.ms, duration: 500.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    'Experience your library in high fidelity',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                    ),
                  ).animate().fade(delay: 400.ms, duration: 500.ms).slideX(begin: -0.1, end: 0),
                  const Spacer(),
                  
                  // Checkbox Row
                  Row(
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        activeColor: Theme.of(context).colorScheme.primary,
                        checkColor: Theme.of(context).colorScheme.onPrimary,
                        onChanged: (val) {
                          setState(() {
                            _agreedToTerms = val ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: InkWell(
                                  onTap: () => _showDocumentDialog(context, 'Terms of Service', 'TERMS_OF_SERVICE.md'),
                                  child: Text(
                                    'Terms of Service',
                                    style: GoogleFonts.outfit(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: InkWell(
                                  onTap: () => _showDocumentDialog(context, 'Privacy Policy', 'PRIVACY_POLICY.md'),
                                  child: Text(
                                    'Privacy Policy',
                                    style: GoogleFonts.outfit(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 600.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 16),

                  // Glassmorphic Google Sign In Button
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _agreedToTerms ? 1.0 : 0.4,
                    child: SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: GlassmorphicContainer(
                        width: double.infinity,
                        height: 64,
                        borderRadius: 18,
                        blur: 15,
                        alignment: Alignment.center,
                        border: 1.5,
                        linearGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _agreedToTerms
                              ? [
                                  Theme.of(context).colorScheme.primary.withAlpha(20),
                                  Theme.of(context).colorScheme.primary.withAlpha(5),
                                ]
                              : [
                                  Colors.white.withAlpha(5),
                                  Colors.white.withAlpha(2),
                                ],
                        ),
                        borderGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _agreedToTerms
                              ? [
                                  Theme.of(context).colorScheme.primary.withAlpha(128),
                                  Theme.of(context).colorScheme.primary.withAlpha(26),
                                ]
                              : [
                                  Colors.white.withAlpha(30),
                                  Colors.white.withAlpha(10),
                                ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _agreedToTerms
                                ? () async {
                                    try {
                                      // First, log into Supabase using Google Sign-In
                                      await ref.read(authServiceProvider).signInWithGoogle();
                                      
                                      // If successful, proceed to capture YouTube cookies
                                      if (context.mounted) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (context) => const YtLoginWebview()),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ZmrSnackbar.show(context, 'Login failed: $e');
                                      }
                                    }
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Iconsax.user, size: 32, color: Theme.of(context).colorScheme.onSurface),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Login using Google',
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ).animate().fade(delay: 800.ms).slideY(begin: 0.2, end: 0).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
