import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../providers/settings_provider.dart';
import 'yt_login_webview.dart';
import 'cookie_instructions_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SectionHeader(title: '⏭ Playback Behavior'),
          const SizedBox(height: 16),
          _buildSliderTile(
            context: context,
            title: 'Crossfade',
            subtitle: '${settings.crossfadeSeconds.toInt()} seconds',
            value: settings.crossfadeSeconds,
            min: 0,
            max: 10,
            onChanged: (val) => settingsNotifier.setCrossfade(val),
          ),
          _buildSwitchTile(
            context: context,
            title: 'Gapless Playback',
            subtitle: 'Avoid silence between tracks',
            value: settings.gaplessPlayback,
            onChanged: (val) => settingsNotifier.setGapless(val),
          ),
          _buildSwitchTile(
            context: context,
            title: 'Normalize Volume',
            subtitle: 'Balance volume across different tracks',
            value: settings.normalizeVolume,
            onChanged: (val) => settingsNotifier.setNormalize(val),
          ),
          const SizedBox(height: 32),
          _SectionHeader(title: '🎨 UI / UX Settings'),
          const SizedBox(height: 16),
          _buildThemeSelector(context, ref, settings),
          _buildSwitchTile(
            context: context,
            title: 'AMOLED Mode',
            subtitle: 'Use true black for dark theme',
            value: settings.amoledMode,
            onChanged: (val) => settingsNotifier.setAmoled(val),
          ),
          const SizedBox(height: 32),
          _SectionHeader(title: '🔑 YouTube Authentication'),
          const SizedBox(height: 16),
          _buildActionTile(
            context: context,
            icon: Iconsax.global,
            title: 'Login via Webview',
            subtitle: 'Recommended for connecting your library',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const YtLoginWebview()),
            ),
          ),
          _buildActionTile(
            context: context,
            icon: Iconsax.info_circle,
            title: 'Cookie Instructions',
            subtitle: 'Learn how to get auth cookies manually',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CookieInstructionsPage()),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withAlpha(10)),
      ),
      child: SwitchListTile(
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: colorScheme.onSurface.withAlpha(150))),
        value: value,
        onChanged: onChanged,
        activeThumbColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSliderTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16)),
              Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: max.toInt(),
            onChanged: onChanged,
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withAlpha(10)),
      ),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: colorScheme.onSurface.withAlpha(150))),
        trailing: const Icon(Iconsax.arrow_right_3, size: 18),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref, ZmrSettings settings) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              _ThemeOption(
                label: 'Light',
                icon: Iconsax.sun_1,
                selected: settings.themeMode == ThemeMode.light,
                onTap: () => ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                label: 'Dark',
                icon: Iconsax.moon,
                selected: settings.themeMode == ThemeMode.dark,
                onTap: () => ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark),
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                label: 'System',
                icon: Iconsax.setting_5,
                selected: settings.themeMode == ThemeMode.system,
                onTap: () => ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.system),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.onSurface.withAlpha(20),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? colorScheme.onPrimary : colorScheme.onSurface, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
