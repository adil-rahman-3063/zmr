import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../providers/music_provider.dart';

class PlaylistPage extends ConsumerWidget {
  final ZmrPlaylist playlist;

  const PlaylistPage({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(playlistSongsProvider(playlist.id));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(playlistSongsProvider(playlist.id));
            },
            backgroundColor: Theme.of(context).colorScheme.surface,
            color: Theme.of(context).colorScheme.primary,
            child: CustomScrollView(
              slivers: [
                _buildCoverImage(context),
                _buildPlaylistInfo(context),
                _buildActionButtons(context, ref, songsAsync),
                songsAsync.when(
                  data: (songs) => SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _SongListItem(song: songs[index], index: index, allSongs: songs, playlistId: playlist.id),
                        childCount: songs.length,
                      ),
                    ),
                  ),
                  loading: () => SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          // Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: 380,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Theme.of(context).colorScheme.surface],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            playlist.thumbnailUrl.startsWith('assets/')
                ? Image.asset(playlist.thumbnailUrl, fit: BoxFit.cover)
                : Image.network(playlist.thumbnailUrl, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Theme.of(context).colorScheme.surface,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistInfo(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    playlist.title,
                    style: GoogleFonts.outfit(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    return IconButton(
                      onPressed: () async {
                        final songsAsync = ref.read(playlistSongsProvider(playlist.id));
                        final songs = songsAsync.asData?.value;
                        if (songs == null || songs.isEmpty) return;

                        final downloader = ref.read(downloadServiceProvider);
                        final downloadLoc = ref.read(downloadLocationProvider);
                        final folderId = ref.read(driveFolderProvider);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Starting download for ${songs.length} songs...'),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                        );

                        for (var song in songs) {
                          if (downloadLoc == 'drive') {
                            await downloader.downloadSongToDrive(song, folderId: folderId);
                          } else {
                            await downloader.downloadSongLocally(song);
                          }
                        }
                        ref.read(offlineRefreshProvider.notifier).refresh();
                      },
                      icon: Icon(Iconsax.import_1, color: Theme.of(context).colorScheme.onSurface, size: 28),
                      tooltip: 'Download All',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(50),
                  child: Icon(Iconsax.user, size: 12, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(width: 8),
                Text(
                  playlist.owner,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, AsyncValue<List<Song>> songsAsync) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final songs = songsAsync.asData?.value;
                  if (songs != null && songs.isNotEmpty) {
                    ref.read(playbackProvider.notifier).setQueue(songs, initialIndex: 0, playlistId: playlist.id);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.play, size: 20),
                    SizedBox(width: 8),
                    Text('Play', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(20)),
              ),
              child: IconButton(
                onPressed: () {
                  final songs = songsAsync.asData?.value;
                  if (songs != null && songs.isNotEmpty) {
                    // Enable shuffle on the notifier, then set queue
                    final notifier = ref.read(playbackProvider.notifier);
                    if (!ref.read(playbackProvider).isShuffle) notifier.toggleShuffle();
                    final randomIndex = Random().nextInt(songs.length);
                    notifier.setQueue(songs, initialIndex: randomIndex, playlistId: playlist.id);
                  }
                },
                icon: Icon(Iconsax.shuffle, color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongListItem extends ConsumerWidget {
  final Song song;
  final int index;
  final List<Song> allSongs;
  final String playlistId;

  const _SongListItem({required this.song, required this.index, required this.allSongs, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: () => ref.read(playbackProvider.notifier).setQueue(allSongs, initialIndex: index, playlistId: playlistId),
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              (index + 1).toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(100), fontSize: 12),
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
                    errorBuilder: (_, __, ___) => Icon(Iconsax.music, color: Theme.of(context).colorScheme.onSurface),
                  ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              song.title,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ref.watch(offlineStatusProvider(song.id)).when(
            data: (isOffline) => isOffline 
              ? const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 14),
                )
              : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      subtitle: Text(
        song.artist,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 12),
        maxLines: 1,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(song.duration, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(100), fontSize: 12)),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Iconsax.more, color: Theme.of(context).colorScheme.onSurface.withAlpha(128), size: 18),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                builder: (ctx) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
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
                        leading: Icon(Iconsax.import, color: Theme.of(context).colorScheme.onSurface),
                        title: Text('Download Offline', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final downloadLoc = ref.read(downloadLocationProvider);
                          final downloader = ref.read(downloadServiceProvider);
                          
                          if (downloadLoc == 'drive') {
                            final folderId = ref.read(driveFolderProvider);
                            await downloader.downloadSongToDrive(song, folderId: folderId);
                          } else {
                            await downloader.downloadSongLocally(song);
                          }
                          ref.read(offlineRefreshProvider.notifier).refresh();
                        },
                      ),
                      ListTile(
                        leading: Icon(Iconsax.share, color: Theme.of(context).colorScheme.onSurface),
                        title: Text('Share Link', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
                        onTap: () {
                          Navigator.pop(ctx);
                          Share.share('Check out this song on ZMR: ${song.title} - ${song.artist}\n${song.musicUrl}');
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.open_in_new, color: Theme.of(context).colorScheme.onSurface),
                        title: Text('Open in YT Music', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final uri = Uri.parse(song.musicUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
