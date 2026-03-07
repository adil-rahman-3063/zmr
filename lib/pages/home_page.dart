import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../core/app_theme.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';
import '../widgets/frosted_nav_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 1; // Home icon index
  final _searchController = TextEditingController();

  Widget _buildHomeContent() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          floating: false,
          pinned: true,
          backgroundColor: AppTheme.blackBase,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: false,
            titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            title: Text(
              'Your Library',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: AppTheme.whiteBase,
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Dark Overlay for depth
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.blackBase, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                // Decorative Black-Grey elements
                Positioned(
                  top: 60,
                  right: -40,
                  child: Icon(
                    Iconsax.music,
                    size: 200,
                    color: AppTheme.greyDark.withAlpha(77),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Iconsax.setting_2, color: AppTheme.whiteBase),
            ),
          ],
        ),
        
        // Playlists / Suggestions Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: 'Quick Picks'),
                const SizedBox(height: 16),
                // Mock playlist list
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    itemBuilder: (context, index) => _SongCard(index: index),
                  ),
                ),
                const SizedBox(height: 32),
                const _SectionHeader(title: 'Daily Mix'),
              ],
            ),
          ),
        ),
        
        // Recent Activity
        SliverPadding(
          padding: const EdgeInsets.all(24.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ActivityItem(index: index),
              childCount: 10,
            ),
          ),
        ),
        
        // Bottom Spacer for Nav Bar
        const SliverToBoxAdapter(child: SizedBox(height: 150)),
      ],
    );
  }

  Widget _buildSearchContent() {
    final searchResults = ref.watch(musicNotifierProvider);
    
    return Column(
      children: [
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppTheme.whiteBase),
            onSubmitted: (val) => ref.read(musicNotifierProvider.notifier).search(val),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.greyDark,
              prefixIcon: const Icon(Iconsax.search_normal, color: AppTheme.whiteMuted),
              hintText: 'Search Music...',
              hintStyle: TextStyle(color: AppTheme.whiteMuted.withAlpha(100)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final song = searchResults[index];
              return _SongListItem(song: song);
            },
          ),
        ),
        const SizedBox(height: 150),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.blackBase,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildSearchContent(), // 0
              _buildHomeContent(),   // 1
              const Center(child: Text('Lib', style: TextStyle(color: Colors.white))), // 2
            ],
          ),
          
          // Mini Player
          const Positioned(
            left: 16,
            right: 16,
            bottom: 90,
            child: _MiniPlayer(),
          ),

          // Custom Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FrostedNavBar(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                setState(() => _selectedIndex = index);
              },
            ),
          ),
        ],
      ),
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
        child: Image.network(song.thumbnailUrl, width: 50, height: 50, fit: BoxFit.cover),
      ),
      title: Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1),
      subtitle: Text(song.artist, style: TextStyle(color: AppTheme.whiteMuted.withAlpha(128))),
      trailing: const Icon(Iconsax.more, color: AppTheme.whiteMuted),
    );
  }
}

class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;

    if (currentSong == null) return const SizedBox.shrink();

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.greyDark.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.whiteBase.withAlpha(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(currentSong.thumbnailUrl, width: 44, height: 44, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentSong.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1),
                Text(currentSong.artist, style: TextStyle(color: AppTheme.whiteMuted.withAlpha(128), fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              final player = ref.read(musicPlayerProvider);
              if (isPlaying) {
                player.pause();
              } else {
                player.play();
              }
            },
            icon: Icon(isPlaying ? Iconsax.pause : Iconsax.play, color: Colors.white),
          ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.whiteBase,
          ),
        ),
        Icon(Iconsax.arrow_right_1, size: 20, color: AppTheme.whiteMuted.withAlpha(128)),
      ],
    );
  }
}

class _SongCard extends StatelessWidget {
  final int index;
  const _SongCard({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppTheme.greyDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.greyMedium,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Iconsax.music, color: AppTheme.whiteMuted, size: 32),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.whiteBase.withAlpha(178),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 50,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.whiteMuted.withAlpha(77),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final int index;
  const _ActivityItem({required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.greyDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.music, size: 24, color: AppTheme.whiteMuted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Song Title ${index + 1}',
                  style: GoogleFonts.outfit(
                    color: AppTheme.whiteBase,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Artist Name',
                  style: GoogleFonts.outfit(
                    color: AppTheme.whiteMuted.withAlpha(128),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Iconsax.more, color: AppTheme.whiteMuted.withAlpha(77)),
        ],
      ),
    );
  }
}
