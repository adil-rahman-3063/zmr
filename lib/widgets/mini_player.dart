import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/music_provider.dart';

class GlobalMiniPlayer extends ConsumerWidget {
  const GlobalMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;
    final processingState = ref.watch(playerProcessingStateProvider).value ?? ProcessingState.idle;
    final swipeHintShown = ref.watch(swipeHintShownProvider);

    if (currentSong == null) return const SizedBox.shrink();

    final isLoading = processingState == ProcessingState.buffering || 
                      processingState == ProcessingState.loading;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(isFullPlayerVisibleProvider.notifier).setVisible(true);
          if (!swipeHintShown) {
            ref.read(swipeHintShownProvider.notifier).markAsShown();
          }
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 76,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withAlpha(102),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(20)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress Ring
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final position = ref.watch(playerPositionProvider).value ?? Duration.zero;
                            final duration = ref.watch(playerDurationProvider).value ?? Duration.zero;
                            final progress = duration.inSeconds > 0 
                                ? (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0) 
                                : 0.0;
                            return CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 2.5,
                              backgroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(20),
                              color: Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                      ),
                      Hero(
                        tag: 'albumArt_${currentSong.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: currentSong.thumbnailUrl.startsWith('assets/')
                              ? Image.asset(currentSong.thumbnailUrl, width: 44, height: 44, fit: BoxFit.cover)
                              : Image.network(
                                  currentSong.thumbnailUrl, 
                                  width: 44, 
                                  height: 44, 
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentSong.title,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ).animate().fade(delay: 100.ms).slideX(begin: -0.1),
                  ),
                  IconButton(
                    onPressed: () {
                      if (isLoading) return;
                      final player = ref.read(musicPlayerProvider);
                      if (isPlaying) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    },
                    icon: isLoading 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary, strokeWidth: 2),
                        )
                      : Icon(isPlaying ? Iconsax.pause : Iconsax.play, color: Theme.of(context).colorScheme.onSurface, size: 28),
                  ),
                  ],
                ),
              ),
            ),
          ),
          if (!swipeHintShown)
            Positioned(
              top: -65,
              left: 54,
              child: Icon(
                Icons.keyboard_double_arrow_up_rounded,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
                shadows: [
                  Shadow(color: Colors.black.withAlpha(128), blurRadius: 15, offset: const Offset(0, 4)),
                ],
              )
              .animate(onPlay: (c) => c.repeat())
              .moveY(begin: 30, end: -15, duration: 1.8.seconds, curve: Curves.easeInOut)
              .fade(begin: 0.1, end: 1.0, duration: 800.ms)
              .then()
              .fade(end: 0.0, duration: 800.ms),
            ),
        ],
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.5, end: 0, curve: Curves.easeOutQuart),
    );
  }
}
