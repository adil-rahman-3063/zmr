// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/artist_model.dart';
import '../models/home_section.dart';
import '../models/home_feed.dart';
import '../models/home_chip.dart';
import '../providers/music_provider.dart';
import 'playlist_page.dart';
import 'profile_page.dart';
import 'artist_page.dart';
import 'settings_page.dart';
import '../providers/auth_provider.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/zmr_snackbar.dart';
import '../main.dart';
import 'yt_login_webview.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shellVisibilityOverrideProvider.notifier).setState(true);
      _checkOnboarding();
    });
  }

  void _checkOnboarding() {
    final onboardingShown = ref.read(cookieOnboardingProvider);
    final hasCookies = ref.read(youtubeCookieProvider) != null;
    
    if (!onboardingShown && !hasCookies) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(Iconsax.info_circle, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text('Welcome to ZMR!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'To connect your YouTube Music library and see your playlists, you will need to provide authentication cookies.\n\nInstructions on how to do this can be found in the Settings page.',
            style: GoogleFonts.outfit(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(cookieOnboardingProvider.notifier).markAsShown();
                Navigator.pop(ctx);
              },
              child: Text('Later', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(cookieOnboardingProvider.notifier).markAsShown();
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const YtLoginWebview()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Connect YouTube', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(musicNotifierProvider.notifier).search(query);
    });
  }

  Widget _buildLibrarySection({
    required AsyncValue<List<dynamic>> asyncValue,
    required Widget Function(List<dynamic>) itemBuilder,
    required String emptyMessage,
  }) {
    final hasCookie = ref.watch(youtubeCookieProvider) != null;

    if (!hasCookie) {
      return _ConnectLibraryCTA(message: emptyMessage);
    }

    return asyncValue.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                   Icon(Iconsax.music_playlist, color: Theme.of(context).colorScheme.onSurface.withAlpha(50), size: 40),
                   const SizedBox(height: 12),
                   Text(
                    'No items found. Try refreshing or check your YouTube Music library.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
                  ),
                ],
              ),
            ),
          );
        }
        return itemBuilder(items);
      },
      loading: () => const _HorizontalShimmer(),
      error: (e, _) {
        final isAuth = e.toString().contains('AUTH_ERROR');
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                isAuth ? 'YouTube Cookies Expired' : 'Library Sync Error',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => showCookieInputDialog(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer.withAlpha(150),
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  elevation: 0,
                ),
                child: Text(isAuth ? 'Update Cookies' : 'Retry Connection'),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildHomeContent() {
    final playlistsAsync = ref.watch(userPlaylistsProvider);
    final homeFeedAsync = ref.watch(homeFeedProvider);
    final trendingSongsAsync = ref.watch(trendingSongsProvider);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeFeedProvider);
        ref.invalidate(trendingSongsProvider);
        ref.invalidate(userPlaylistsProvider);
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      color: Theme.of(context).colorScheme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: Text(
                'ZMR',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: colorScheme.onSurface,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.surface, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    right: -40,
                    child: Icon(
                      Iconsax.music,
                      size: 200,
                      color: colorScheme.primary.withAlpha(50),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Category Chips
          _buildChipsSliver(homeFeedAsync),
          
          // Home Feed (Quick Picks, personalized sections, etc.)
          _buildHomeFeedSliver(homeFeedAsync),
          
          // Your Library sections (Playlists, Artists)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(title: 'Your Playlists'),
                  const SizedBox(height: 16),
                  _buildLibrarySection(
                    asyncValue: playlistsAsync,
                    itemBuilder: (playlists) => SizedBox(
                      height: 210, 
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 24),
                        itemCount: playlists.length,
                        itemBuilder: (context, index) => _PlaylistCard(playlist: playlists[index] as ZmrPlaylist),
                      ),
                    ),
                    emptyMessage: 'Connect your YouTube library to see your playlists',
                  ),
                  const SizedBox(height: 32),
                  const _SectionHeader(title: 'Following Artists'),
                  const SizedBox(height: 16),
                  _buildLibrarySection(
                    asyncValue: ref.watch(followedArtistsProvider),
                    itemBuilder: (artists) => SizedBox(
                      height: 180, 
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 24),
                        itemCount: artists.length,
                        itemBuilder: (context, index) => _ArtistCard(artist: artists[index] as Artist),
                      ),
                    ),
                    emptyMessage: 'Follow artists on YouTube Music to see them here',
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Followed Artists New Releases
          _buildFollowedArtistsSections(ref),
  
          // Trending Section
          _buildTrendingSectionSliver(trendingSongsAsync),
          
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
    );
  }

  Widget _buildFollowedArtistsSections(WidgetRef ref) {
    final artistsAsync = ref.watch(followedArtistsProvider);

    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final artist = artists[index];
              final releasesAsync = ref.watch(artistNewReleasesProvider(artist.id));

              return releasesAsync.when(
                data: (songs) {
                  if (songs.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: _SectionHeader(title: '${artist.name} - New Releases'),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(left: 24),
                            itemCount: songs.length,
                            itemBuilder: (context, songIdx) => _SongCard(song: songs[songIdx]),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(delay: (index * 100).ms, duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuart);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
            childCount: artists.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildTrendingSectionSliver(AsyncValue<List<Song>> asyncValue) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: _SectionHeader(title: 'Trending Now'),
            ),
            const SizedBox(height: 16),
            asyncValue.when(
              data: (songs) => _ThumbnailGrid(items: songs),
              loading: () => const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: _HorizontalShimmer(),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipsSliver(AsyncValue<HomeFeed> asyncValue) {
    return asyncValue.when(
      data: (feed) {
        if (feed.chips.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              itemCount: feed.chips.length,
              itemBuilder: (context, index) {
                final chip = feed.chips[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(chip.title),
                    selected: chip.isSelected,
                    onSelected: (selected) {
                      ref.read(homeFeedProvider.notifier).selectCategory(chip);
                    },
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: GoogleFonts.outfit(
                      color: chip.isSelected 
                          ? Theme.of(context).colorScheme.onPrimary 
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: chip.isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none,
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildHomeFeedSliver(AsyncValue<HomeFeed> asyncValue) {
    return asyncValue.when(
      data: (feed) {
        final sections = feed.sections;
        if (sections.isEmpty) {
           return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final section = sections[index];
              final titleLower = section.title.toLowerCase();
              
              // Count specific item types to guess layout
              final songCount = section.items.whereType<Song>().length;
              final hasPlaylists = section.items.any((i) => i is ZmrPlaylist);
              
              // Grid layouts logic:
              // 1. Explicitly named "Quick picks" etc.
              // 2. High density of songs (more than 5) and no playlists/artists
              final isQuickPicks = (songCount > 4 && !hasPlaylists) || 
                                  titleLower.contains('quick picks') || 
                                  titleLower.contains('picks for you') ||
                                  titleLower.contains('start radio') ||
                                  titleLower.contains('mixed for you');

              // Thumbnail grid for discovery
              final isThumbnailGrid = titleLower.contains('fresh find') || 
                                     titleLower.contains('new release') ||
                                     titleLower.contains('discover') ||
                                     titleLower.contains('trending');
              
              if (isQuickPicks) {
                debugPrint('ZMR [UI]: Rendering "$titleLower" as a Quick Picks grid');
              } else if (isThumbnailGrid) {
                debugPrint('ZMR [UI]: Rendering "$titleLower" as a Thumbnail grid (Force filtered for songs)');
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _SectionHeader(title: section.title),
                    ),
                    const SizedBox(height: 16),
                    if (isQuickPicks)
                      _buildQuickPicksGrid(section.items)
                    else if (isThumbnailGrid)
                      _ThumbnailGrid(items: section.items.whereType<Song>().toList())
                    else
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          itemCount: section.items.length,
                          itemBuilder: (context, idx) {
                            final item = section.items[idx];
                            if (item is Song) return _SongCard(song: item);
                            if (item is ZmrPlaylist) return _PlaylistCard(playlist: item, showCount: false);
                            if (item is Artist) return _ArtistCard(artist: item);
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                  ],
                ),
              ).animate().fade(delay: (index * 100).ms, duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuart);
            },
            childCount: sections.length,
          ),
        );
      },
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
        ),
      ),
      error: (e, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildQuickPicksGrid(List<dynamic> items) {
    final songs = items.whereType<Song>().toList();
    if (songs.isEmpty) return const SizedBox.shrink();
    final displaySongs = songs.take(20).toList();

    // Group songs into columns of 4
    final List<List<Song>> columns = [];
    for (var i = 0; i < displaySongs.length; i += 4) {
      columns.add(displaySongs.sublist(i, (i + 4) > displaySongs.length ? displaySongs.length : i + 4));
    }

    return SizedBox(
      height: 300, // Increased height for 4 rows + padding
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        itemCount: columns.length,
        itemBuilder: (context, colIdx) {
          final columnSongs = columns[colIdx];
          return Container(
            width: MediaQuery.of(context).size.width * 0.88, // Show a peek of the next column
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              children: columnSongs.map((song) => _SongGridItem(song: song)).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchContent() {
    final searchResponse = ref.watch(musicNotifierProvider);
    final trendingSongsAsync = ref.watch(trendingSongsProvider);

    return Column(
      children: [
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            onChanged: _onSearchChanged,
            onSubmitted: (val) => ref.read(musicNotifierProvider.notifier).search(val),
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              prefixIcon: Icon(Iconsax.search_normal, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
              hintText: 'Songs, Artists...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: searchResponse.isLoading 
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)
                    ),
                  )
                : (_searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(musicNotifierProvider.notifier).search('');
                        },
                      )
                    : null),
            ),
          ),
        ),
        if (searchResponse.isLoading)
           LinearProgressIndicator(
             backgroundColor: Colors.transparent,
             color: Theme.of(context).colorScheme.primary.withAlpha(50),
           ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_searchController.text.isEmpty) ...[
                Text(
                  'Trending Today',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                trendingSongsAsync.when(
                  data: (songs) => Column(
                    children: songs.take(10).map((s) => _SongListItem(song: s)).toList(),
                  ),
                  loading: () => const _HorizontalShimmer(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ] else ...[
                if (searchResponse.artists.isNotEmpty) ...[
                  Text(
                    'Artists',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...searchResponse.artists.map((artist) => _ArtistListItem(artist: artist)),
                  const SizedBox(height: 24),
                ],
                if (searchResponse.songs.isNotEmpty) ...[
                  Text(
                    'Songs',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...searchResponse.songs.map((song) => _SongListItem(song: song)),
                ],
                if (!searchResponse.isLoading && searchResponse.artists.isEmpty && searchResponse.songs.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Iconsax.search_status, size: 64, color: Theme.of(context).colorScheme.onSurface.withAlpha(50)),
                          const SizedBox(height: 16),
                          Text(
                            'No results for "${_searchController.text}"',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 150),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryContent() {
    final playlistsAsync = ref.watch(userPlaylistsProvider);
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userPlaylistsProvider);
        ref.invalidate(likedSongsProvider);
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      color: Theme.of(context).colorScheme.primary,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Library',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Iconsax.add_square, color: Theme.of(context).colorScheme.primary),
                onPressed: () => _showAddPlaylistDialog(context, ref),
                tooltip: 'New Playlist',
              ),
              IconButton(
                icon: Icon(Iconsax.refresh, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                onPressed: () => ref.refresh(userPlaylistsProvider),
                tooltip: 'Refresh Library',
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: _buildLibrarySectionSliver(playlistsAsync),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
    );
  }

  Widget _buildLibrarySectionSliver(AsyncValue<List<ZmrPlaylist>> asyncValue) {
    final hasCookie = ref.watch(youtubeCookieProvider) != null;

    if (!hasCookie) {
      return const SliverToBoxAdapter(
        child: _ConnectLibraryCTA(message: 'Connect your YouTube library to see your playlists'),
      );
    }

    return asyncValue.when(
      data: (playlists) {
        if (playlists.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Iconsax.music_playlist, color: Theme.of(context).colorScheme.onSurface.withAlpha(50), size: 64),
                   const SizedBox(height: 12),
                   Text(
                    'No playlists found in your library.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
                  ),
                ],
              ),
            ),
          );
        }
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 24,
            crossAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == 0) return const _AddPlaylistTile();
              return _PlaylistCard(playlist: playlists[index - 1], useFullWidth: true);
            },
            childCount: playlists.length + 1,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (e, _) {
        final isAuth = e.toString().contains('AUTH_ERROR');
        return SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  isAuth ? 'YouTube Cookies Expired' : 'Library Sync Error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => showCookieInputDialog(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.errorContainer.withAlpha(150),
                    foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  child: Text(isAuth ? 'Update Cookies' : 'Retry Connection'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileContent() {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Center(
        child: Text(
          'Not signed in',
          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
        ),
      );
    }

    final String? avatarUrl = user.userMetadata?['avatar_url'];
    final String fullName = user.userMetadata?['full_name'] ?? 'Guest User';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        children: [
          const SizedBox(height: 40),
          Text(
            'Profile',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(30), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Icon(Iconsax.user, size: 40, color: Theme.of(context).colorScheme.onSurface)
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  fullName,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email ?? '',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          const _CookieSettingsTile(),
          const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error.withAlpha(30),
                  foregroundColor: Theme.of(context).colorScheme.error,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Theme.of(context).colorScheme.error.withAlpha(100)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.logout_1, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(bottomNavProvider);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: IndexedStack(
        index: selectedIndex,
        children: [
          _buildHomeContent(),    // 0 (Home Icon)
          _buildSearchContent(),  // 1 (Discover/Explore Icon)
          _buildLibraryContent(), // 2 (Library Icon)
          const ProfilePage(),     // 3 (User Icon)
        ],
      ),
    );
  }
}


void showCookieInputDialog(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  showModalBottomSheet(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect YouTube Music',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Paste your YouTube cookies here (risky approach).',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            maxLines: 5,
            autofocus: true,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'SID=...; HSID=...; SAPISID=...;',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(150),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withAlpha(20)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: ValueNotifier<bool>(false), // Placeholder, I'll use a local state
                  builder: (context, loading, _) => ElevatedButton(
                    onPressed: () async {
                      final cookies = controller.text.trim();
                      if (cookies.isEmpty) return;
                      
                      ref.read(youtubeCookieProvider.notifier).setCookies(cookies);
                      
                      // Test the connection immediately
                      final isValid = await ref.read(youtubeServiceProvider).testAuth();
                      
                      if (context.mounted) {
                        if (isValid) {
                          ZmrSnackbar.show(context, 'Successfully connected to YouTube Music!');
                          Navigator.pop(context);
                        } else {
                          ZmrSnackbar.show(context, 'Failed to connect. Please check your cookies.');
                          // Keep the dialog open for correction
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Connect'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}


class _ArtistListItem extends StatelessWidget {
  final Artist artist;
  const _ArtistListItem({required this.artist});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistPage(artist: artist)));
      },
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        backgroundImage: artist.thumbnailUrl.isNotEmpty 
          ? NetworkImage(artist.thumbnailUrl) 
          : null,
        child: artist.thumbnailUrl.isEmpty 
          ? Icon(Iconsax.user, color: Theme.of(context).colorScheme.onSurface) 
          : null,
      ),
      title: Text(
        artist.name,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
      ),
      subtitle: Text('Artist', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(128))),
      trailing: Icon(Iconsax.arrow_right_3, color: Theme.of(context).colorScheme.onSurface.withAlpha(128), size: 16),
    );
  }
}

class _SongListItem extends ConsumerWidget {
  final Song song;
  const _SongListItem({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: () => ref.read(musicNotifierProvider.notifier).play(song),
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: song.thumbnailUrl.startsWith('assets/')
            ? Image.asset(
                song.thumbnailUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              )
            : Image.network(
                song.thumbnailUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Iconsax.music, color: Theme.of(context).colorScheme.onSurface),
              ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(song.title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold), maxLines: 1)),

        ],
      ),
      subtitle: GestureDetector(
        onTap: () {
          if (song.artistId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArtistPage(
                  artist: Artist(
                    id: song.artistId!,
                    name: song.artist,
                    thumbnailUrl: '',
                  ),
                ),
              ),
            );
          }
        },
        child: Text(
          song.artist,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            decoration: song.artistId != null ? TextDecoration.underline : null,
            decorationColor: Theme.of(context).colorScheme.onSurface.withAlpha(50),
          ),
        ),
      ),
      trailing: IconButton(
        icon: Icon(Iconsax.more, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
        onPressed: () {
          showModalBottomSheet(
            useRootNavigator: true,
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
                  // Grab handle
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
                    leading: Icon(Iconsax.radar, color: Theme.of(context).colorScheme.onSurface),
                    title: Text('Start Radio', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(playbackProvider.notifier).startRadio(song);
                    },
                  ),
                  ListTile(
                    leading: Icon(Iconsax.add_square, color: Theme.of(context).colorScheme.onSurface),
                    title: Text('Add to Playlist', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
                    onTap: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        useRootNavigator: true,
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => AddToPlaylistSheet(song: song),
                      );
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
    );
  }
}


class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Icon(Iconsax.arrow_right_1, size: 20, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
      ],
    );
  }
}

class _PlaylistCard extends ConsumerWidget {
  final ZmrPlaylist playlist;
  final bool showCount;
  final bool useFullWidth;
  const _PlaylistCard({required this.playlist, this.showCount = true, this.useFullWidth = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistPage(playlist: playlist),
          ),
        );
      },
      onLongPress: () => _showPlaylistOptions(context, ref, playlist),
      child: Container(
        width: useFullWidth ? null : 150,
        margin: useFullWidth ? EdgeInsets.zero : const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: playlist.thumbnailUrl.startsWith('assets/')
                    ? Image.asset(
                        playlist.thumbnailUrl,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        playlist.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(Iconsax.music, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.title,
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showCount)
              Text(
                '${playlist.songCount} songs',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    ).animate().scale(begin: const Offset(0.95, 0.95), duration: 400.ms, curve: Curves.easeOutBack).fade();
  }
}


class _AddPlaylistTile extends ConsumerWidget {
  const _AddPlaylistTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showAddPlaylistDialog(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                   Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(20),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withAlpha(40),
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(100), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withAlpha(60),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Iconsax.add_circle,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add Playlist',
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Text(
            'Create new',
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

void _showPlaylistOptions(BuildContext context, WidgetRef ref, ZmrPlaylist playlist) {
  showModalBottomSheet(
    context: rootNavigatorKey.currentContext ?? context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(30),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: playlist.thumbnailUrl.startsWith('assets/')
                    ? Image.asset(playlist.thumbnailUrl, width: 60, height: 60, fit: BoxFit.cover)
                    : Image.network(playlist.thumbnailUrl, width: 60, height: 60, fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${playlist.songCount} songs',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Iconsax.shuffle),
            title: const Text('Shuffle All'),
            onTap: () async {
              Navigator.pop(ctx);
              final ytService = ref.read(youtubeServiceProvider);
              final songs = await ytService.fetchPlaylistSongs(playlist.id);
              if (songs.isNotEmpty) {
                final mutableSongs = List<Song>.from(songs);
                mutableSongs.shuffle();
                ref.read(playbackProvider.notifier).setQueue(mutableSongs, initialIndex: 0);
              }
            },
          ),
          ListTile(
            leading: const Icon(Iconsax.edit),
            title: const Text('Rename Playlist'),
            onTap: () {
              Navigator.pop(ctx);
              _showRenamePlaylistDialog(context, ref, playlist);
            },
          ),
          ListTile(
            leading: Icon(Iconsax.trash, color: Theme.of(context).colorScheme.error),
            title: Text('Delete Playlist', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(ctx);
              _showDeletePlaylistConfirmation(context, ref, playlist);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

void _showRenamePlaylistDialog(BuildContext context, WidgetRef ref, ZmrPlaylist playlist) {
  final controller = TextEditingController(text: playlist.title);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename Playlist'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'New playlist name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            final newTitle = controller.text.trim();
            if (newTitle.isNotEmpty && newTitle != playlist.title) {
              Navigator.pop(ctx);
              await ref.read(userPlaylistsProvider.notifier).renamePlaylist(playlist.id, newTitle);
            }
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}

void _showDeletePlaylistConfirmation(BuildContext context, WidgetRef ref, ZmrPlaylist playlist) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Playlist'),
      content: Text('Are you sure you want to delete "${playlist.title}"? This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await ref.read(userPlaylistsProvider.notifier).deletePlaylist(playlist.id);
          },
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

void _showAddPlaylistDialog(BuildContext context, WidgetRef ref) {

  final controller = TextEditingController();
  final isLoading = ValueNotifier<bool>(false);

  showModalBottomSheet(
    context: rootNavigatorKey.currentContext ?? context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(20), width: 1),
        ),
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Iconsax.music_playlist, color: Theme.of(context).colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  'Create Playlist',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'What should we call your playlist?',
                hintStyle: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(150),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                prefixIcon: Icon(Iconsax.edit, color: Theme.of(context).colorScheme.onSurface.withAlpha(150), size: 20),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withAlpha(20)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ValueListenableBuilder<bool>(
              valueListenable: isLoading,
              builder: (context, loading, _) => SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    final title = controller.text.trim();
                    if (title.isNotEmpty) {
                      isLoading.value = true;
                      try {
                        await ref.read(youtubeServiceProvider).createPlaylist(title);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ZmrSnackbar.show(context, 'Playlist "$title" created successfully!');
                        }
                        ref.invalidate(userPlaylistsProvider);
                      } catch (e) {
                         if (context.mounted) {
                           ZmrSnackbar.show(context, 'Error creating playlist: $e');
                         }
                      } finally {
                        isLoading.value = false;
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    shadowColor: Theme.of(context).colorScheme.primary.withAlpha(100),
                  ),
                  child: loading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(
                        'Create Playlist', 
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe Later', 
                  style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SongCard extends ConsumerWidget {
  final Song song;
  const _SongCard({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(musicNotifierProvider.notifier).play(song),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Fix height overflow
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: song.thumbnailUrl.startsWith('assets/')
                    ? Image.asset(
                        song.thumbnailUrl,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        song.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(Iconsax.music, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            GestureDetector(
              onTap: () {
                if (song.artistId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArtistPage(
                        artist: Artist(
                          id: song.artistId!,
                          name: song.artist,
                          thumbnailUrl: '',
                        ),
                      ),
                    ),
                  );
                }
              },
              child: Text(
                song.artist,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                  fontSize: 11,
                  decoration: song.artistId != null ? TextDecoration.underline : null,
                  decorationColor: Theme.of(context).colorScheme.onSurface.withAlpha(50),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(begin: const Offset(0.95, 0.95), duration: 400.ms, curve: Curves.easeOutBack).fade();
  }
}



class _CookieSettingsTile extends ConsumerWidget {
  const _CookieSettingsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(20)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Iconsax.setting_2,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
        ),
        title: Text(
          'YouTube Music Cookies',
          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Manage your authentication tokens',
          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontSize: 13),
        ),
        trailing: Icon(Iconsax.arrow_right_3, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
        },
      ),
    );
  }
}


class _ArtistCard extends StatelessWidget {
  final Artist artist;
  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistPage(artist: artist)));
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 65,
              backgroundImage: artist.thumbnailUrl.startsWith('http') 
                  ? NetworkImage(artist.thumbnailUrl) 
                  : null,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: !artist.thumbnailUrl.startsWith('http') 
                  ? Icon(Iconsax.user, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)) 
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ).animate().scale(begin: const Offset(0.95, 0.95), duration: 400.ms, curve: Curves.easeOutBack).fade(),
    );
  }
}

class _SongGridItem extends ConsumerWidget {
  final Song song;
  const _SongGridItem({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => ref.read(musicNotifierProvider.notifier).play(song),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                song.thumbnailUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 50,
                  height: 50,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(Iconsax.music, color: Theme.of(context).colorScheme.onSurface.withAlpha(100), size: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      if (song.artistId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArtistPage(
                              artist: Artist(
                                id: song.artistId!,
                                name: song.artist,
                                thumbnailUrl: '',
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                        fontSize: 12,
                        decoration: song.artistId != null ? TextDecoration.underline : null,
                        decorationColor: Theme.of(context).colorScheme.onSurface.withAlpha(50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.more, color: Theme.of(context).colorScheme.onSurface.withAlpha(128), size: 18),
          ],
        ),
      ),
    );
  }
}

class _ConnectLibraryCTA extends ConsumerWidget {
  final String message;
  const _ConnectLibraryCTA({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(20)),
      ),
      child: Column(
        children: [
          Icon(Iconsax.magic_star, color: Theme.of(context).colorScheme.onSurface, size: 32),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => showCookieInputDialog(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Connect YouTube'),
          ),
        ],
      ),
    );
  }
}

class _HorizontalShimmer extends StatelessWidget {
  const _HorizontalShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          width: 140,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
class _ThumbnailGrid extends ConsumerWidget {
  final List<dynamic> items;
  const _ThumbnailGrid({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = items.whereType<Song>().toList();
    if (songs.isEmpty) return const SizedBox.shrink();
    final displaySongs = songs.take(16).toList();

    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: displaySongs.length,
      itemBuilder: (context, index) {
        final song = displaySongs[index];
        return GestureDetector(
          onTap: () => ref.read(musicNotifierProvider.notifier).play(song),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              song.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Iconsax.music, color: Theme.of(context).colorScheme.onSurface.withAlpha(100), size: 20),
              ),
            ),
          ).animate().fade(delay: (index * 40).ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
        );
      },
    );
  }
}
