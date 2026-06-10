import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/music_provider.dart';
import '../providers/auth_provider.dart';
import 'settings_page.dart';
import '../widgets/zmr_snackbar.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final accountInfo = ref.watch(accountInfoProvider);
    final supabaseUser = ref.watch(currentUserProvider);

    final name = accountInfo.value?['name'] ?? supabaseUser?.userMetadata?['full_name'] ?? 'User Name';
    final ytEmail = accountInfo.value?['email'];
    final ytPhoto = accountInfo.value?['photoUrl'];

    final email = (ytEmail != null && ytEmail != 'Unknown') 
        ? ytEmail 
        : (supabaseUser?.email ?? 'user@email.com');
    final photoUrl = (ytPhoto != null && ytPhoto.isNotEmpty)
        ? ytPhoto
        : supabaseUser?.userMetadata?['avatar_url'];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primary.withAlpha(50),
                      colorScheme.surface,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: colorScheme.primary,
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                          ),
                        ) : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        email,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _ProfileTile(
                    icon: Iconsax.setting_2,
                    title: 'Settings',
                    subtitle: 'Playback, UI/UX, and account settings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ProfileTile(
                    icon: Iconsax.heart,
                    title: 'Donate to Developer',
                    subtitle: 'Support the development of ZMR',
                    onTap: () => _showDonationBanner(context),
                  ),
                  const SizedBox(height: 16),
                  _ProfileTile(
                    icon: Iconsax.mask,
                    title: 'Report Bug',
                    subtitle: 'Help us improve ZMR by reporting issues',
                    onTap: () => _showBugReportSheet(context, ref),
                  ),
                  const SizedBox(height: 16),
                  _ProfileTile(
                    icon: Iconsax.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your YouTube account',
                    isDestructive: true,
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                'Logout',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        ref.read(youtubeCookieProvider.notifier).setCookies(null);
                        // Auth status will update and listener in App will redirect to Login
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDonationBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final upiId = "adilrahman3063-1@okicici";
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        backgroundColor: colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24.0, left: 16, right: 16),
              child: Text(
                'Scan or Screenshot to Donate',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/donation.png',
              fit: BoxFit.contain,
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    'Or copy UPI ID:',
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurface.withAlpha(150),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: upiId));
                      ZmrSnackbar.show(context, 'UPI ID copied to clipboard');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.onSurface.withAlpha(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            upiId,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Icon(Iconsax.copy, color: colorScheme.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: colorScheme.surfaceContainerHighest.withAlpha(50),
                      ),
                      child: Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBugReportSheet(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final subjectController = TextEditingController();
    final detailsController = TextEditingController();
    final isSubmitting = ValueNotifier<bool>(false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withAlpha(30),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Report a Bug',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: subjectController,
                style: GoogleFonts.outfit(),
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'What is the issue?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha(50),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: detailsController,
                maxLines: 5,
                minLines: 3,
                style: GoogleFonts.outfit(),
                decoration: InputDecoration(
                  labelText: 'Bug Details',
                  hintText: 'Please describe the bug in detail...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha(50),
                ),
              ),
              const SizedBox(height: 24),
              ValueListenableBuilder<bool>(
                valueListenable: isSubmitting,
                builder: (context, loading, _) => SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      final subject = subjectController.text.trim();
                      final details = detailsController.text.trim();
                      
                      if (subject.isEmpty || details.isEmpty) {
                        ZmrSnackbar.show(context, 'Please fill all fields');
                        return;
                      }

                      isSubmitting.value = true;
                      try {
                        final supabase = Supabase.instance.client;
                        final account = ref.read(accountInfoProvider).value;
                        
                        await supabase.from('bugs').insert({
                          'subject': subject,
                          'details': details,
                          'user_email': account?['email'],
                          'user_id': supabase.auth.currentUser?.id,
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ZmrSnackbar.show(context, 'Bug reported successfully. Thank you!');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ZmrSnackbar.show(context, 'Failed to report bug: $e');
                        }
                      } finally {
                        isSubmitting.value = false;
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: loading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Submit Report', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.onSurface.withAlpha(10),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDestructive ? colorScheme.error : colorScheme.primary).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDestructive ? colorScheme.error : colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: color.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_right_3, color: color.withAlpha(100), size: 18),
          ],
        ),
      ),
    );
  }
}

// Provider for account info
final accountInfoProvider = FutureProvider<Map<String, String>?>((ref) async {
  final ytService = ref.watch(youtubeServiceProvider);
  final cookies = ref.watch(youtubeCookieProvider);
  if (cookies == null) return null;
  return await ytService.getAccountInfo();
});
