import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    if (currentSong == null) return const SizedBox.shrink();

    final isLoading = processingState == ProcessingState.buffering || 
                      processingState == ProcessingState.loading;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(isFullPlayerVisibleProvider.notifier).setVisible(true);
        },
        child: ClipRRect(
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: currentSong.thumbnailUrl.startsWith('assets/')
                        ? Image.asset(currentSong.thumbnailUrl, width: 48, height: 48, fit: BoxFit.cover)
                        : Image.network(
                            currentSong.thumbnailUrl, 
                            width: 48, 
                            height: 48, 
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentSong.artist,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontSize: 12),
                          maxLines: 1,
                        ),
                      ],
                    ),
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
      ),
    );
  }
}
