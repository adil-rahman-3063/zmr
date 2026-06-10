import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateBanner extends StatelessWidget {
  final String version;
  final String updateUrl;
  final VoidCallback onDismiss;

  const UpdateBanner({
    super.key,
    required this.version,
    required this.updateUrl,
    required this.onDismiss,
  });

  Future<void> _launchUpdateUrl() async {
    final uri = Uri.parse(updateUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 100,
        borderRadius: 24,
        blur: 20,
        alignment: Alignment.center,
        border: 1,
        linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withAlpha(150),
            Theme.of(context).colorScheme.primary.withAlpha(50),
          ],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha(100),
            Colors.white.withAlpha(20),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.flash, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Available!',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Version $version is out now.',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withAlpha(200),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _launchUpdateUrl();
                      onDismiss();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: Text('Update', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
