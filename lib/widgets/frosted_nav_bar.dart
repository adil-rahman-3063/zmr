import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../providers/music_provider.dart';

/// Frosted, pill-shaped global navigation bar with a minimal Black-Grey aesthetic.
class FrostedNavBar extends ConsumerWidget {
  const FrostedNavBar({super.key});

  static const double _height = 76.0;
  static const double _pillRadius = 40.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(bottomNavProvider);
    final swipeHintShown = ref.watch(swipeHintShownProvider);
    final hasSong = ref.watch(currentSongProvider) != null;

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: _height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_pillRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: _height,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withAlpha(102),
                    borderRadius: BorderRadius.circular(_pillRadius),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(20),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_icons.length, (i) {
                      final icon = _icons[i];
                      final selected = i == selectedIndex;
                      return _NavItem(
                        icon: icon,
                        index: i,
                        selected: selected,
                        onTap: (index) {
                          ref.read(bottomNavProvider.notifier).setIndex(index);
                          
                          // Handle root navigator popping for pages pushed onto the main stack (like PlaylistPage)
                          final navKey = ref.read(navigatorKeyProvider);
                          if (navKey.currentState?.canPop() ?? false) {
                            navKey.currentState?.popUntil((route) => route.isFirst);
                          }
                        },
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          if (hasSong && !swipeHintShown)
            Positioned(
              top: -65,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_double_arrow_up_rounded,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                    shadows: [
                      Shadow(color: Colors.black.withAlpha(128), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(begin: 15, end: -10, duration: 1.5.seconds, curve: Curves.easeInOut)
                  .fade(begin: 0.1, end: 1.0, duration: 600.ms)
                  .then()
                  .fade(end: 0.0, duration: 600.ms),
                  const SizedBox(width: 8),
                  Text(
                    'Swipe for mini player',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        const Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                  ).animate().fade(duration: 800.ms).slideX(begin: 0.2),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final int index;
  final bool selected;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(32),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: selected ? 1.2 : 1.0,
          curve: Curves.easeOutBack,
          child: Icon(
            icon,
            color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withAlpha(128),
            size: 24,
          ),
        ),
      ),
    );
  }
}

const List<IconData> _icons = [
  Iconsax.home_1,
  Iconsax.search_normal_1,
  Iconsax.music_playlist,
  Iconsax.user,
];
