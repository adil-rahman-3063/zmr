import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/music_provider.dart';
import '../providers/auth_provider.dart';
import 'settings_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final accountInfo = ref.watch(accountInfoProvider);

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
                        child: Text(
                          accountInfo.value?['name']?[0].toUpperCase() ?? 'U',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        accountInfo.value?['name'] ?? 'User Name',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        accountInfo.value?['email'] ?? 'user@email.com',
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields')),
                        );
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bug reported successfully. Thank you!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to report bug: $e')),
                          );
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
