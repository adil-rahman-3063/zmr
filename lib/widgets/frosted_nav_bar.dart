import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Frosted, pill-shaped bottom navigation bar with a minimal Black-Grey aesthetic.
class FrostedNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const FrostedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const double _height = 76.0;
  static const double _horizontalPadding = 24.0;
  static const double _pillRadius = 40.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: 24,
      ),
      child: SizedBox(
        height: _height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_pillRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: _height,
              decoration: BoxDecoration(
                color: AppTheme.greyDark.withAlpha(102),
                borderRadius: BorderRadius.circular(_pillRadius),
                border: Border.all(
                  color: AppTheme.whiteBase.withAlpha(20),
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
                    onTap: onItemSelected,
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
          color: selected ? AppTheme.whiteBase : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Icon(
          icon,
          color: selected ? AppTheme.blackBase : AppTheme.whiteMuted.withAlpha(128),
          size: 24,
        ),
      ),
    );
  }
}

const List<IconData> _icons = [
  Icons.swap_horiz_rounded,
  Icons.home_filled,
  Icons.explore_rounded,
  Icons.list_alt_rounded,
  Icons.person_rounded,
];
