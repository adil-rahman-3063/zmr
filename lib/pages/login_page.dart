import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import 'home_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.blackBase,
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
                color: AppTheme.blackBase.withAlpha(160), // Dark overlay
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
                          color: AppTheme.whiteBase,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Iconsax.music, color: AppTheme.blackBase, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'ZMR',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppTheme.whiteBase,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                  Text(
                    'Unlock your Music',
                    style: GoogleFonts.outfit(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.whiteBase,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Experience your library in high fidelity',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: AppTheme.whiteMuted.withAlpha(128),
                    ),
                  ),
                  const Spacer(),
                  
                  // Glassmorphic Google Sign In Button
                  SizedBox(
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
                        colors: [
                          AppTheme.whiteBase.withAlpha(20),
                          AppTheme.whiteBase.withAlpha(5),
                        ],
                      ),
                      borderGradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.whiteBase.withAlpha(128),
                          AppTheme.whiteBase.withAlpha(26),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            try {
                              final authService = ref.read(authServiceProvider);
                              await authService.signInWithGoogle();
                              
                              if (context.mounted) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (context) => const HomePage()),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.g_mobiledata, size: 42, color: AppTheme.whiteBase),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Continue with Google',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.whiteBase,
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
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const HomePage()),
                        );
                      },
                      child: Text(
                        'Skip to Home (Debug Mode)',
                        style: GoogleFonts.outfit(
                          color: AppTheme.whiteMuted.withAlpha(128),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
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
