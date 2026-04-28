import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/artist_model.dart';
import '../models/artist_details.dart';
import '../providers/music_provider.dart';
import '../models/song_model.dart';

class ArtistPage extends ConsumerWidget {
  final Artist artist;

  const ArtistPage({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(artistDetailsProvider(artist.id));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            actions: [
              Consumer(
                builder: (context, ref, child) {
                  final followingAsync = ref.watch(followedArtistsProvider);
                  return followingAsync.maybeWhen(
                    data: (artists) {
                      final isFollowing = artists.any((a) => a.id == artist.id);
                      return Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: ChoiceChip(
                          label: Text(isFollowing ? 'Following' : 'Follow'),
                          selected: isFollowing,
                          onSelected: (val) async {
                            try {
                              await ref.read(followedArtistsProvider.notifier).toggleFollow(artist);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          labelStyle: GoogleFonts.outfit(
                            color: isFollowing ? colorScheme.onPrimary : colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          selectedColor: colorScheme.primary,
                          backgroundColor: colorScheme.surfaceContainerHighest.withAlpha(150),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          showCheckmark: false,
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              title: Text(
                artist.name,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: colorScheme.onSurface),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (artist.thumbnailUrl.isNotEmpty)
                    Opacity(
                      opacity: 0.6,
                      child: Image.network(
                        artist.thumbnailUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.surface, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0.1, 0.6],
                      ),
                    ),
                  ),
                  if (artist.thumbnailUrl.isNotEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40.0),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(50),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 85,
                            backgroundColor: colorScheme.primary.withAlpha(30),
                            backgroundImage: NetworkImage(artist.thumbnailUrl),
                          ),
                        ),
                      ),
                    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack).fade(),
                ],
              ),
            ),
          ),
          detailsAsync.when(
            data: (ArtistDetails details) {
              return SliverList(
                delegate: SliverChildListDelegate([
                  if (details.popularSongs.isNotEmpty) ...[
                    _SectionHeader(title: 'Songs'),
                    ...details.popularSongs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final song = entry.value;
                      return _ArtistSongTile(
                        song: song,
                        index: index,
                        onTap: () {
                          ref.read(playbackProvider.notifier).setQueue(details.popularSongs, initialIndex: index);
                        },
                      ).animate().fade(delay: (index * 40).ms).slideX(begin: 0.1, end: 0);
                    }),
                    const SizedBox(height: 32),
                  ],
                  ...details.sections.map((section) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(title: section.title),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: section.items.length,
                            itemBuilder: (context, index) {
                              final song = section.items[index];
                              return _HorizontalSongCard(
                                song: song,
                                onTap: () {
                                  ref.read(playbackProvider.notifier).setQueue(section.items, initialIndex: index);
                                },
                              ).animate().fade(delay: (index * 50).ms).scale(begin: const Offset(0.9, 0.9));
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  }),
                  if (details.popularSongs.isEmpty && details.sections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Text('No music found', style: GoogleFonts.outfit(color: colorScheme.onSurface.withAlpha(150))),
                      ),
                    ),
                ]),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _HorizontalSongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _HorizontalSongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: song.thumbnailUrl.isNotEmpty
                    ? Image.network(song.thumbnailUrl, fit: BoxFit.cover)
                    : Container(color: colorScheme.surfaceContainerHighest, child: const Icon(Iconsax.music)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.onSurface),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 12, color: colorScheme.onSurface.withAlpha(150)),
            ),
          ],
        ),
      ),
    );
  }
}


class _ArtistSongTile extends ConsumerWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;

  const _ArtistSongTile({required this.song, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
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
      title: Text(
        song.title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 12),
        maxLines: 1,
      ),
      trailing: Text(song.duration, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(100), fontSize: 12)),
    );
  }
}
