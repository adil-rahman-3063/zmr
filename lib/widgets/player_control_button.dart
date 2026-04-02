import 'package:flutter/material.dart';

class PlayerControlButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final double borderRadius;
  final bool isLoading;

  const PlayerControlButton({
    super.key,
    required this.icon,
    this.size = 24,
    required this.onTap,
    this.backgroundColor,
    this.iconColor = Colors.white,
    this.borderRadius = 20,
    this.isLoading = false,
  });

  @override
  State<PlayerControlButton> createState() => _PlayerControlButtonState();
}

class _PlayerControlButtonState extends State<PlayerControlButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isLoading) _controller.forward();
      },
      onTapUp: (_) {
        if (!widget.isLoading) _controller.reverse();
      },
      onTapCancel: () {
        if (!widget.isLoading) _controller.reverse();
      },
      onTap: widget.isLoading ? null : widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size * 2.5,
          height: widget.size * 2.5,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: CircularProgressIndicator(
                      color: widget.iconColor ?? Colors.black,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: widget.size * 1.2,
                  ),
          ),
        ),
      ),
    );
  }
}
