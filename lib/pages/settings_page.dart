import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../providers/music_provider.dart';
import 'cookie_instructions_page.dart';
import '../widgets/zmr_snackbar.dart';


class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _cookieController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controller with current cookies
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentCookies = ref.read(youtubeCookieProvider);
      if (currentCookies != null) {
        _cookieController.text = currentCookies;
      }
    });
  }

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'YouTube Music API',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          _buildInstructionButton(context),
          const SizedBox(height: 32),
          Text(
            'Authentication Cookies',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Provide your YouTube Music cookies to enable fetching your private data like liked songs, playlists, and subscriptions.',
            style: GoogleFonts.outfit(fontSize: 14, color: colorScheme.onSurface.withAlpha(150)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cookieController,
            maxLines: 5,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Paste your cookie string here (e.g. VISITOR_INFO1_LIVE=...; LOGIN_INFO=...)',
              hintStyle: TextStyle(color: colorScheme.onSurface.withAlpha(100)),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _cookieController.clear();
                  ref.read(youtubeCookieProvider.notifier).setCookies(null);
                  ZmrSnackbar.show(context, 'Cookies cleared');
                },
                child: Text('Clear', style: GoogleFonts.outfit(color: colorScheme.error)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final text = _cookieController.text.trim();
                  if (text.isNotEmpty) {
                    ref.read(youtubeCookieProvider.notifier).setCookies(text);
                    ZmrSnackbar.show(context, 'Cookies saved successfully');
                    
                    // Invalidate providers that depend on auth so they reload with the new cookie
                    ref.invalidate(userPlaylistsProvider);
                    ref.invalidate(likedSongsProvider);
                    ref.invalidate(followedArtistsProvider);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Iconsax.save_2, size: 20),
                label: Text('Save Cookies', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.onSurface.withAlpha(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.shield_tick, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Privacy Disclaimer',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Everything you paste is stored locally as cache. Nothing is transferred to our servers. Your data stays on your device.',
                  style: GoogleFonts.outfit(fontSize: 12, color: colorScheme.onSurface.withAlpha(150)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withAlpha(40),
            colorScheme.primary.withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withAlpha(50)),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CookieInstructionsPage()));
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Iconsax.info_circle, color: Colors.white, size: 24),
        ),
        title: Text(
          'Need help getting cookies?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          'View step-by-step instructions with images',
          style: GoogleFonts.outfit(fontSize: 12, color: colorScheme.onSurface.withAlpha(150)),
        ),
        trailing: Icon(Iconsax.arrow_right_3, color: colorScheme.primary, size: 20),
      ),
    );
  }
}
