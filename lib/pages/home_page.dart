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
import '../providers/music_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/add_to_playlist_sheet.dart';
import 'playlist_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

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
          
          // Playlists Section
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
                ],
              ),
            ),
          ),
          
          // Home Feed (Quick Picks, etc.)
          _buildHomeFeedSliver(homeFeedAsync),
  
          // Trending Section
          _buildTrendingSectionSliver(trendingSongsAsync),
          
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
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

  Widget _buildHomeFeedSliver(AsyncValue<List<HomeSection>> asyncValue) {
    return asyncValue.when(
      data: (sections) {
        // Filter out sections as requested
        final filteredSections = sections.where((s) {
          final title = s.title.toLowerCase();
          // Keep Quick Picks
          if (title.contains('quick picks')) return true;
          
          // Remove these specific sections
          return !title.contains('listen again') && 
                 !title.contains('liked songs') && 
                 !title.contains('liked music') &&
                 !title.contains('your likes') &&
                 !title.contains('favorites') &&
                 !title.contains('fresh find');
        }).toList();

        if (filteredSections.isEmpty) {
           return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final section = filteredSections[index];
              final titleLower = section.title.toLowerCase();
              final hasSongs = section.items.any((i) => i is Song);
              
              // Grid layouts
              final isQuickPicks = hasSongs && (
                                  titleLower.contains('quick picks') || 
                                  titleLower.contains('picks for you') ||
                                  titleLower.contains('start radio') ||
                                  titleLower.contains('mixed for you'));

              // Force grid for specific discovery sections and filter for songs only
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
            childCount: filteredSections.length,
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

    // Group songs into columns of 4
    final List<List<Song>> columns = [];
    for (var i = 0; i < songs.length; i += 4) {
      columns.add(songs.sublist(i, (i + 4) > songs.length ? songs.length : i + 4));
    }

    return SizedBox(
      height: 280, // Height for 4 rows
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        itemCount: columns.length,
        itemBuilder: (context, colIdx) {
          final columnSongs = columns[colIdx];
          return Container(
            width: MediaQuery.of(context).size.width - 64,
            margin: const EdgeInsets.only(right: 16),
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
                icon: Icon(Iconsax.refresh, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                onPressed: () => ref.refresh(userPlaylistsProvider),
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
          const _DownloadSettingsTile(),
          const SizedBox(height: 16),
          const _DownloadActivityTile(),
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
          _buildProfileContent(), // 3 (Person Icon)
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
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(youtubeCookieProvider.notifier).setCookies(controller.text);
                    Navigator.pop(context);
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
        // Future: Navigate to Artist profiles
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
      subtitle: Text(song.artist, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(128))),
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

class _PlaylistCard extends StatelessWidget {
  final ZmrPlaylist playlist;
  final bool showCount;
  final bool useFullWidth;
  const _PlaylistCard({required this.playlist, this.showCount = true, this.useFullWidth = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistPage(playlist: playlist),
          ),
        );
      },
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
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.transparent,
                        child: Center(
                          child: Icon(
                            Iconsax.add_circle,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary,
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

void _showAddPlaylistDialog(BuildContext context, WidgetRef ref) {
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
            'New Playlist',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Playlist Name',
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
                child: ElevatedButton(
                  onPressed: () async {
                    final title = controller.text.trim();
                    if (title.isNotEmpty) {
                      await ref.read(supabaseServiceProvider).createPlaylist(title);
                      Navigator.pop(context);
                      ref.invalidate(userPlaylistsProvider);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
        ],
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
            Text(
              song.artist,
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                fontSize: 11,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    ).animate().scale(begin: const Offset(0.95, 0.95), duration: 400.ms, curve: Curves.easeOutBack).fade();
  }
}


class _DownloadSettingsTile extends ConsumerWidget {
  const _DownloadSettingsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(downloadLocationProvider);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(20)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        leading: Icon(
          location == 'drive' ? Iconsax.cloud_plus : Iconsax.folder_2,
          color: Theme.of(context).colorScheme.onSurface,
          size: 28,
        ),
        title: Text(
          'Download Location',
          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          location == 'drive' ? 'Google Drive' : 'Local Device Storage',
          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontSize: 13),
        ),
        trailing: Icon(Iconsax.arrow_right_3, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            builder: (ctx) => const _DownloadLocationPicker(),
          );
        },
      ),
    );
  }
}

class _DownloadLocationPicker extends ConsumerWidget {
  const _DownloadLocationPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(downloadLocationProvider);
    
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 24.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Save offline music to',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            RadioListTile<String>(
              title: Text('Local Device Storage', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500)),
              subtitle: Text('Fast, offline playback directly from your phone.', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 13)),
              activeColor: Theme.of(context).colorScheme.primary,
              value: 'local',
              groupValue: location,
              onChanged: (val) {
                if (val != null) {
                  ref.read(downloadLocationProvider.notifier).setLocation(val);
                }
              },
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: Text('Google Drive', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500)),
              subtitle: Text('Sync seamlessly to your cloud storage.', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 13)),
              activeColor: Theme.of(context).colorScheme.primary,
              value: 'drive',
              groupValue: location,
              onChanged: (val) {
                if (val != null) {
                  ref.read(downloadLocationProvider.notifier).setLocation(val);
                }
              },
            ),
            if (location == 'drive') ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Folder Link (Optional)',
                      style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (val) {
                        // Extract Folder ID from link
                        // Format: https://drive.google.com/drive/folders/FOLDER_ID
                        String folderId = val.trim();
                        if (folderId.contains('folders/')) {
                          folderId = folderId.split('folders/').last.split('?').first;
                        } else if (folderId.contains('id=')) {
                          folderId = folderId.split('id=').last.split('&').first;
                        }
                        ref.read(driveFolderProvider.notifier).setFolderId(folderId);
                      },
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Paste Drive folder link...',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(80)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(150),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withAlpha(20)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ensure the authorized account has permission to upload here.',
                      style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(100), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Done', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DownloadActivityTile extends ConsumerWidget {
  const _DownloadActivityTile();

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
        leading: Icon(Iconsax.activity, color: Theme.of(context).colorScheme.onSurface, size: 28),
        title: Text(
          'Download Activity',
          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'View real-time progress & logs',
          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontSize: 13),
        ),
        trailing: Icon(Iconsax.arrow_right_3, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
        onTap: () {
          showModalBottomSheet(
            useRootNavigator: true,
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            builder: (ctx) => const _DownloadActivityViewer(),
          );
        },
      ),
    );
  }
}

class _DownloadActivityViewer extends ConsumerWidget {
  const _DownloadActivityViewer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadLogsProvider);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
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
              const SizedBox(height: 24),
              Text(
                'Download Activity',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              if (state.progress.isNotEmpty) ...[
                Text(
                  'Active Transfers',
                  style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                ...state.progress.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Song ID: ${e.key}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: e.value,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 32),
              ],
              Text(
                'Event Logs',
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: state.logs.length,
                  itemBuilder: (context, index) {
                    final log = state.logs[state.logs.length - 1 - index]; // Show newest first
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        '[$index] $log',
                        style: GoogleFonts.firaCode(color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontSize: 11),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Artist artist;
  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    ).animate().scale(begin: const Offset(0.95, 0.95), duration: 400.ms, curve: Curves.easeOutBack).fade();
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
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(128), fontSize: 12),
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
