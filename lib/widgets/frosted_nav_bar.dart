import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';

/// Frosted, pill-shaped global navigation bar with a minimal Black-Grey aesthetic.
class FrostedNavBar extends ConsumerWidget {
  const FrostedNavBar({super.key});

  static const double _height = 76.0;
  static const double _pillRadius = 40.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(bottomNavProvider);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
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
                      if (Navigator.canPop(context)) {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }
                    },
                  );
                }),
              ),
            ),
          ),
        ),
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
        child: Icon(
          icon,
          color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withAlpha(128),
          size: 24,
        ),
      ),
    );
  }
}

const List<IconData> _icons = [
  Icons.home_filled,
  Icons.explore_rounded,
  Icons.library_music_rounded,
  Icons.person_rounded,
];
