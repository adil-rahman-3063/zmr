// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/music_provider.dart';
import '../widgets/squiggly_slider.dart';
import '../widgets/player_control_button.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/zmr_snackbar.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../models/song_model.dart';
import '../models/artist_model.dart';
import 'artist_page.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  bool _isQueueVisible = false;
  bool _showLyrics = false;
  final ScrollController _lyricsScrollController = ScrollController();

  void _hideQueue() {
    setState(() {
      _isQueueVisible = false;
    });
  }

  void _showQueue() {
    setState(() {
      _isQueueVisible = true;
    });
  }

  Duration _parseDuration(String durationStr) {
    if (durationStr.isEmpty) return Duration.zero;
    try {
      final parts = durationStr.split(':');
      if (parts.length == 2) {
        return Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
      }
    } catch (_) {}
    return Duration.zero;
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '0:00';
    String minutes = duration.inMinutes.toString();
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Circular toggle button — shows a tinted ring + glow when active
  Widget _buildToggleButton({
    required BuildContext context,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isActive ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? color.withAlpha(35) : Colors.transparent,
            border: isActive ? Border.all(color: color.withAlpha(90), width: 1.5) : null,
          ),
          child: Icon(
            icon,
            color: isActive ? color : Theme.of(context).colorScheme.onSurface.withAlpha(160),
            size: 22,
          ),
        ),
      ),
    );
  }

  void _showMoreOptions(Song currentSong) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.only(top: 12, bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Iconsax.export, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Share Song', style: GoogleFonts.outfit()),
              subtitle: Text('Send to friends or copy link', style: GoogleFonts.outfit(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(120))),
              onTap: () {
                Navigator.pop(context);
                final deepLink = 'https://zmr.app/song/${currentSong.id}';
                final ytLink = 'https://music.youtube.com/watch?v=${currentSong.id}';
                Share.share(
                  '🎵 ${currentSong.title} by ${currentSong.artist}\n\nListen on ZMR: $deepLink\n\nOr on YouTube Music: $ytLink',
                  subject: '${currentSong.title} — ${currentSong.artist}',
                );
              },
            ),
            ListTile(
              leading: Icon(Iconsax.music_play, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Go to Album', style: GoogleFonts.outfit()),
              onTap: () {
                Navigator.pop(context);
                ZmrSnackbar.show(context, 'Album view coming soon!');
              },
            ),
            ListTile(
              leading: Icon(Iconsax.user, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Artist Profile', style: GoogleFonts.outfit()),
              onTap: () {
                Navigator.pop(context);
                if (currentSong.artistId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArtistPage(
                        artist: Artist(
                          id: currentSong.artistId!,
                          name: currentSong.artist,
                          thumbnailUrl: '', // Will be fetched or show placeholder
                        ),
                      ),
                    ),
                  );
                } else {
                  ZmrSnackbar.show(context, 'Artist profile not available for this song');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsOverlay(Song currentSong, Duration position) {
    final lyricsAsync = ref.watch(lyricsProvider(currentSong.id));
    
    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics == null || lyrics.lines.isEmpty) {
          return Center(
            child: Text(
              'Lyrics not available',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          );
        }

        int currentLineIdx = -1;
        if (lyrics.isSynced) {
          for (int i = 0; i < lyrics.lines.length; i++) {
            if (position >= lyrics.lines[i].timestamp) {
              currentLineIdx = i;
            } else {
              break;
            }
          }
        }

        return ListView.builder(
          controller: _lyricsScrollController,
          padding: const EdgeInsets.symmetric(vertical: 140, horizontal: 24),
          itemCount: lyrics.lines.length,
          itemBuilder: (context, index) {
            final line = lyrics.lines[index];
            final bool isActive = index == currentLineIdx;
            
            return AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: GoogleFonts.outfit(
                fontSize: isActive ? 22 : 18,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : Colors.white.withAlpha(80),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    line.text,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white54)),
      error: (e, _) => Center(child: Text('Lyrics load failed', style: GoogleFonts.outfit(color: Colors.white70))),
    );
  }

  Widget _buildQueueSheetContent(PlaybackState playback) {
    final queue = playback.queue;
    final order = playback.playlistOrder;
    final currentIdx = playback.currentIndex;
    final allUpNext = (currentIdx >= 0 && currentIdx < order.length - 1)
        ? order.sublist(currentIdx + 1)
        : <int>[];
    final upNextIndices = allUpNext;

    return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Theme.of(context).colorScheme.surface.withAlpha(220),
                  child: Column(
                    children: [
                      // Handle bar
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Up Next',
                              style: GoogleFonts.outfit(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (playback.isShuffle)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(80)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Iconsax.shuffle, size: 14, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Shuffled',
                                      style: GoogleFonts.outfit(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Queue list
                      Expanded(
                        child: upNextIndices.isEmpty
                            ? playback.isFetchingMore
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(strokeWidth: 2),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Discovering related music...',
                                          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                                        ),
                                      ],
                                    ),
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Iconsax.music_play, size: 48, color: Theme.of(context).colorScheme.onSurface).animate().fade(duration: 600.ms).scale(delay: 200.ms),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Nothing up next',
                                          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
                                        ),
                                      ],
                                    ),
                                  )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: upNextIndices.length + (playback.isFetchingMore ? 1 : 0),
                                itemBuilder: (context, i) {
                                  if (i >= upNextIndices.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 32.0),
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    );
                                  }
                                  final songIndex = upNextIndices[i];
                                  final song = queue[songIndex];
                                  final queuePosition = (currentIdx + 1 + i);
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          child: Text(
                                            '$queuePosition',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface.withAlpha(80),
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: song.thumbnailUrl.startsWith('assets/')
                                              ? Image.asset(song.thumbnailUrl, width: 48, height: 48, fit: BoxFit.cover)
                                              : Image.network(
                                                  song.thumbnailUrl,
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    width: 48,
                                                    height: 48,
                                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                    child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                      song.title,
                                      style: GoogleFonts.outfit(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      song.artist,
                                      style: GoogleFonts.outfit(
                                        color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      _hideQueue();
                                      ref.read(playbackProvider.notifier).jumpTo(currentIdx + 1 + i);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider);
    if (currentSong == null) return const Scaffold();

    final isPlaying = ref.watch(isPlayingProvider).value ?? false;
    final player = ref.watch(musicPlayerProvider);
    final playback = ref.watch(playbackProvider);
    final size = MediaQuery.of(context).size;



    // Live playback streams
    final position = ref.watch(playerPositionProvider).value ?? Duration.zero;
    final liveDuration = ref.watch(playerDurationProvider).value;
    final metaDuration = _parseDuration(currentSong.duration);
    final duration = (liveDuration != null && liveDuration != Duration.zero) ? liveDuration : metaDuration;

    final processingState = ref.watch(playerProcessingStateProvider).value ?? ProcessingState.idle;
    final isLoading = processingState == ProcessingState.buffering || processingState == ProcessingState.loading;

    // Lyrics Auto-scroll implementation
    if (_showLyrics) {
      ref.listen(playerPositionProvider, (previous, next) {
        final pos = next.value ?? Duration.zero;
        final lyricsAsync = ref.read(lyricsProvider(currentSong.id));
        lyricsAsync.whenData((lyrics) {
          if (lyrics != null && lyrics.isSynced && _lyricsScrollController.hasClients) {
            int lineIdx = -1;
            for (int i = 0; i < lyrics.lines.length; i++) {
              if (pos >= lyrics.lines[i].timestamp) {
                lineIdx = i;
              } else {
                break;
              }
            }
            if (lineIdx != -1) {
              // Estimate line height + padding = ~48 pixels
              _lyricsScrollController.animateTo(
                (lineIdx * 48.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutQuart,
              );
            }
          }
        });
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // Background blur
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Opacity(
                opacity: 0.5,
                child: currentSong.thumbnailUrl.startsWith('assets/')
                    ? Image.asset(currentSong.thumbnailUrl, fit: BoxFit.cover)
                    : Image.network(
                        currentSong.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                      ),
              ),
            ),
          ),
          // Dark overlay
          Positioned.fill(
            child: Container(color: Theme.of(context).colorScheme.surface.withAlpha(120)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => ref.read(isFullPlayerVisibleProvider.notifier).setVisible(false),
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.onSurface, size: 32),
                      ),
                      Text(
                        'NOW PLAYING',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showMoreOptions(currentSong),
                        icon: Icon(Iconsax.more, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Album Art
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: _showLyrics
                            ? Container(
                                key: const ValueKey('lyrics'),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  color: Colors.black38,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: 0.5,
                                          child: ImageFiltered(
                                            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                                            child: currentSong.thumbnailUrl.startsWith('assets/')
                                                ? Image.asset(currentSong.thumbnailUrl, fit: BoxFit.cover)
                                                : Image.network(currentSong.thumbnailUrl, fit: BoxFit.cover),
                                          ),
                                        ),
                                      ),
                                      _buildLyricsOverlay(currentSong, position),
                                    ],
                                  ),
                                ),
                              )
                            : Hero(
                                tag: 'albumArt_${currentSong.id}',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: currentSong.thumbnailUrl.startsWith('assets/')
                                      ? Image.asset(currentSong.thumbnailUrl, fit: BoxFit.cover)
                                      : Image.network(
                                          currentSong.thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurface, size: 64),
                                          ),
                                        ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Song info + like
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong.title,
                              style: GoogleFonts.outfit(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                if (currentSong.artistId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ArtistPage(
                                        artist: Artist(
                                          id: currentSong.artistId!,
                                          name: currentSong.artist,
                                          thumbnailUrl: '',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                currentSong.artist,
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
                                  fontSize: 18,
                                  decoration: currentSong.artistId != null ? TextDecoration.underline : null,
                                  decorationColor: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (context) => AddToPlaylistSheet(song: currentSong),
                          );
                        },
                        icon: Icon(
                          Iconsax.add_square,
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
                          size: 28,
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final likedSongsAsync = ref.watch(likedSongsProvider);
                          final isLiked = likedSongsAsync.maybeWhen(
                            data: (songs) => songs.any((s) => s.id == currentSong.id),
                            orElse: () => false,
                          );
                          return IconButton(
                            onPressed: () async {
                              try {
                                await ref.read(likedSongsProvider.notifier).toggleLike(currentSong);
                                if (context.mounted) {
                                  ZmrSnackbar.show(context, isLiked ? 'Removed from Liked Songs' : 'Added to Liked Songs');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ZmrSnackbar.show(context, 'Failed to update: $e');
                                }
                              }
                            },
                            icon: Icon(
                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isLiked ? Colors.red : Theme.of(context).colorScheme.onSurface.withAlpha(200),
                              size: 28,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Progress bar
                  Column(
                    children: [
                      SquigglySlider(
                        value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                        max: duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds.toDouble(),
                        onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Theme.of(context).colorScheme.primary.withAlpha(30),
                        isPlaying: isPlaying,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 12)),
                            Text(_formatDuration(duration), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Playback controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PlayerControlButton(
                        icon: Iconsax.previous,
                        size: 28,
                        iconColor: Theme.of(context).colorScheme.onSurface,
                        onTap: () => ref.read(playbackProvider.notifier).previous(),
                      ),
                      const SizedBox(width: 24),
                      PlayerControlButton(
                        icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 42,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        iconColor: Theme.of(context).colorScheme.onPrimary,
                        borderRadius: 28,
                        isLoading: isLoading,
                        onTap: () => isPlaying ? player.pause() : player.play(),
                      ),
                      const SizedBox(width: 24),
                      PlayerControlButton(
                        icon: Iconsax.next,
                        size: 28,
                        iconColor: Theme.of(context).colorScheme.onSurface,
                        onTap: () => ref.read(playbackProvider.notifier).next(),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Bottom action row: Shuffle | Share | Queue | Repeat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 🔀 Shuffle — circle glow when active
                      _buildToggleButton(
                        context: context,
                        icon: Iconsax.shuffle,
                        isActive: playback.isShuffle,
                        onTap: () => ref.read(playbackProvider.notifier).toggleShuffle(),
                      ),
                      // 🎵 Lyrics — toggles the view on the album art
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showLyrics = !_showLyrics;
                          });
                        },
                        child: Padding(
                           padding: const EdgeInsets.all(10.0),
                           child: Icon(
                            Iconsax.document_text, 
                            color: _showLyrics 
                              ? Theme.of(context).colorScheme.primary 
                              : Theme.of(context).colorScheme.onSurface.withAlpha(160), 
                            size: 22
                          ),
                        ),
                      ),
                      // 🌙 Sleep Timer — opens timer controls, glows primary color when active
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            useRootNavigator: true,
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const SleepTimerSheet(),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Consumer(
                            builder: (context, ref, child) {
                              final hasTimer = ref.watch(sleepTimerProvider) != null;
                              return Icon(
                                Iconsax.moon, 
                                color: hasTimer 
                                  ? Theme.of(context).colorScheme.primary 
                                  : Theme.of(context).colorScheme.onSurface.withAlpha(160), 
                                size: 22
                              );
                            },
                          ),
                        ),
                      ),
                      // 📋 Up Next — queue count badge
                      Builder(
                        builder: (context) {
                          final currentIdx = playback.currentIndex;
                          final orderLength = playback.playlistOrder.length;
                          final upcomingCount = (currentIdx >= 0 && currentIdx < orderLength - 1)
                              ? orderLength - 1 - currentIdx
                              : 0;
                          final displayCount = upcomingCount;

                          return GestureDetector(
                            onTap: _showQueue,
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(Iconsax.music_playlist, color: Theme.of(context).colorScheme.onSurface.withAlpha(160), size: 22),
                                  if (displayCount > 0)
                                    Positioned(
                                      top: -5,
                                      right: -7,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                                        constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                                        child: Text(
                                          '$displayCount',
                                          style: GoogleFonts.outfit(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // 🔁 Repeat — circle glow, icon changes for repeat-one
                      _buildToggleButton(
                        context: context,
                        icon: playback.isRepeatOne ? Iconsax.repeate_one : Iconsax.repeat,
                        isActive: playback.isRepeat,
                        onTap: () => ref.read(playbackProvider.notifier).toggleRepeat(),
                      ),
                    ],
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
          // Queue Overlay (drawn inside the local Stack so it appears ON TOP of PlayerPage)
          // Background Dimmer
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isQueueVisible ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_isQueueVisible,
              child: GestureDetector(
                onTap: _hideQueue,
                child: Container(color: Colors.black54),
              ),
            ),
          ),
          
          // Sliding Queue Content
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutQuart,
            left: 0,
            right: 0,
            bottom: _isQueueVisible ? 0 : -size.height * 0.8,
            height: size.height * 0.8,
            child: _buildQueueSheetContent(playback),
          ),
        ],
      ),
    );
  }
}
