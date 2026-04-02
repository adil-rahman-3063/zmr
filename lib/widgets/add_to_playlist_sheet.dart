import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../widgets/zmr_snackbar.dart';

class AddToPlaylistSheet extends ConsumerStatefulWidget {
  final Song song;

  const AddToPlaylistSheet({super.key, required this.song});

  @override
  ConsumerState<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<AddToPlaylistSheet> {
  bool _isCreating = false;
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleCreatePlaylist() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final ytService = ref.read(youtubeServiceProvider);
      // Create the playlist and seed it with the song ID immediately
      final playlistId = await ytService.createPlaylist(title, videoId: widget.song.id);
      if (playlistId != null) {
        ref.invalidate(userPlaylistsProvider);
        if (mounted) {
          Navigator.pop(context);
          ZmrSnackbar.show(context, 'Created playlist "$title" and added song.');
        }
      }
    } catch (e) {
      if (mounted) {
        ZmrSnackbar.show(context, 'Failed to create playlist: $e');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(userPlaylistsProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add to Playlist',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        title: Text('New Playlist', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        content: TextField(
                          controller: _titleController,
                          autofocus: true,
                          style: GoogleFonts.outfit(),
                          decoration: InputDecoration(
                            hintText: 'Enter playlist title...',
                            hintStyle: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
                          ),
                          ElevatedButton(
                            onPressed: _isCreating ? null : () {
                              Navigator.pop(ctx);
                              _handleCreatePlaylist();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isCreating 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text('Create', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onPrimary)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(Iconsax.add_square, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: playlistsAsync.when(
              data: (playlists) => ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        playlist.thumbnailUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Iconsax.music),
                        ),
                      ),
                    ),
                    title: Text(
                      playlist.title,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${playlist.songCount} songs',
                      style: GoogleFonts.outfit(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                    ),
                    onTap: () async {
                      try {
                        await ref.read(youtubeServiceProvider).addToPlaylist(playlist.id, widget.song.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ZmrSnackbar.show(context, 'Added to ${playlist.title}');
                        }
                        // Refresh the playlist songs in case someone is watching
                        ref.invalidate(playlistSongsProvider(playlist.id));
                      } catch (e) {
                        if (context.mounted) {
                          final errorMessage = e.toString().contains('ALREADY_EXISTS')
                              ? 'Song already exists in this playlist'
                              : 'Failed to add: $e';
                          ZmrSnackbar.show(context, errorMessage);
                          // Don't pop if it failed, so user can try another playlist
                        }
                      }
                    },
                  );
                },
              ),
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
