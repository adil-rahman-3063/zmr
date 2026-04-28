import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CookieInstructionsPage extends StatelessWidget {
  const CookieInstructionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Cookie Instructions', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.primary.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(Iconsax.monitor, color: colorScheme.primary, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'These steps must be performed on a laptop or computer.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildStep(
            context,
            step: 1,
            title: 'Add Chrome Extension',
            description: 'In Chrome, add the "Get cookies.txt LOCALLY" extension from the Web Store.',
            icon: Iconsax.add_square,
            imageAsset: 'assets/cookies.png',
            onAction: () => launchUrl(Uri.parse('https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc')),
            actionLabel: 'Open Web Store',
          ),
          _buildStep(
            context,
            step: 2,
            title: 'Go to YouTube Music',
            description: 'Visit music.youtube.com and make sure you are logged into your account.',
            icon: Iconsax.global,
            onAction: () => launchUrl(Uri.parse('https://music.youtube.com')),
            actionLabel: 'Open YT Music',
          ),
          _buildStep(
            context,
            step: 3,
            title: 'Export Cookies',
            description: 'Press the extension icon in your browser and click the "Export" button.',
            icon: Iconsax.export_1,
            imageAsset: 'assets/export.png',
          ),
          _buildStep(
            context,
            step: 4,
            title: 'Paste in ZMR',
            description: 'A file will be downloaded. Open it, copy everything inside, and paste it into the Settings page in ZMR.',
            icon: Iconsax.import,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.onSurface.withAlpha(20)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Iconsax.shield_tick, color: colorScheme.primary, size: 24),
                    const SizedBox(width: 16),
                    Text(
                      'Disclaimer',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Everything you paste is stored locally as cache. Nothing is transferred to our servers or any third party. Your data stays on your device.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: colorScheme.onSurface.withAlpha(180),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, {
    required int step, 
    required String title, 
    required String description, 
    required IconData icon,
    String? imageAsset,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: GoogleFonts.outfit(
                      color: colorScheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: colorScheme.onSurface.withAlpha(180),
                    height: 1.5,
                  ),
                ),
                if (onAction != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Iconsax.link, size: 16),
                    label: Text(actionLabel ?? 'Action'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
                if (imageAsset != null) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.onSurface.withAlpha(20)),
                      ),
                      child: Image.asset(
                        imageAsset,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
