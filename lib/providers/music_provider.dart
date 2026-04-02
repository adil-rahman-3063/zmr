import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/home_section.dart';
import '../models/search_response.dart';
import '../services/youtube_service.dart';
import '../services/supabase_service.dart';
import '../services/download_service.dart';

// Provider for managing global bottom navigation index
class BottomNavNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final bottomNavProvider = NotifierProvider<BottomNavNotifier, int>(BottomNavNotifier.new);

// Global Navigator Key for consistent context access (e.g. showModalBottomSheet)
final navigatorKeyProvider = Provider((ref) => GlobalKey<NavigatorState>());

// Track if full player is visible to hide global elements
class FullPlayerVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setVisible(bool visible) => state = visible;
}
final isFullPlayerVisibleProvider = NotifierProvider<FullPlayerVisibilityNotifier, bool>(FullPlayerVisibilityNotifier.new);

// Track which card is active in the bottom stack (0: MiniPlayer, 1: NavBar)
class ShellCardIndexNotifier extends Notifier<int> {
  @override
  int build() => 1;
  void setIndex(int index) => state = index;
}
final shellCardIndexProvider = NotifierProvider<ShellCardIndexNotifier, int>(ShellCardIndexNotifier.new);

// Provider for SharedPreferences to be overridden in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// Provider for YouTube cookies with persistence
class YoutubeCookieNotifier extends Notifier<String?> {
  static const _cookieKey = 'yt_cookies';

  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_cookieKey);
  }

  void setCookies(String? cookies) {
    state = cookies;
    final prefs = ref.read(sharedPreferencesProvider);
    if (cookies == null) {
      prefs.remove(_cookieKey);
    } else {
      prefs.setString(_cookieKey, cookies);
    }
  }
}

final youtubeCookieProvider = NotifierProvider<YoutubeCookieNotifier, String?>(YoutubeCookieNotifier.new);

class DownloadLocationNotifier extends Notifier<String> {
  static const _key = 'zmr_download_location';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) ?? 'local';
  }

  void setLocation(String location) {
    state = location;
    ref.read(sharedPreferencesProvider).setString(_key, location);
  }
}

final downloadLocationProvider = NotifierProvider<DownloadLocationNotifier, String>(DownloadLocationNotifier.new);

class DriveFolderNotifier extends Notifier<String?> {
  static const _key = 'zmr_drive_folder_id';

  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key);
  }

  void setFolderId(String? folderId) {
    state = folderId;
    final prefs = ref.read(sharedPreferencesProvider);
    if (folderId == null) {
      prefs.remove(_key);
    } else {
      prefs.setString(_key, folderId);
    }
  }
}

final driveFolderProvider = NotifierProvider<DriveFolderNotifier, String?>(DriveFolderNotifier.new);

// User onboarding: Track if swipe-up hint was shown
class SwipeHintNotifier extends Notifier<bool> {
  static const _key = 'zmr_swipe_hint_shown';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  void markAsShown() {
    state = true;
    ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}

final swipeHintShownProvider = NotifierProvider<SwipeHintNotifier, bool>(SwipeHintNotifier.new);

// Dynamic Color Scheme provider based on current song thumbnail
final dynamicColorSchemeProvider = FutureProvider<ColorScheme?>((ref) async {
  final currentSong = ref.watch(currentSongProvider);
  if (currentSong == null) return null;

  try {
    final ImageProvider imageProvider = currentSong.thumbnailUrl.startsWith('assets/')
        ? AssetImage(currentSong.thumbnailUrl)
        : NetworkImage(currentSong.thumbnailUrl) as ImageProvider;

    return await ColorScheme.fromImageProvider(
      provider: imageProvider,
      brightness: Brightness.dark,
    );
  } catch (e) {
    debugPrint('ZMR [Theme]: Failed to generate dynamic color scheme: $e');
    return null;
  }
});

final youtubeServiceProvider = Provider((ref) {
  final ytService = YoutubeService();
  final cookies = ref.watch(youtubeCookieProvider);
  ytService.updateCookies(cookies);
  return ytService;
});

final supabaseServiceProvider = Provider((ref) => SupabaseService());

final downloadServiceProvider = Provider((ref) {
  final service = DownloadService(ref.watch(youtubeServiceProvider));
  
  // Link the service to the logging provider
  service.onLog = (msg) => ref.read(downloadLogsProvider.notifier).addLog(msg);
  service.onProgressUpdate = (id, progress) => ref.read(downloadLogsProvider.notifier).updateProgress(id, progress);
  
  return service;
});

class DownloadLogState {
  final List<String> logs;
  final Map<String, double> progress;
  DownloadLogState({required this.logs, required this.progress});
}

class DownloadLogNotifier extends Notifier<DownloadLogState> {
  @override
  DownloadLogState build() => DownloadLogState(logs: [], progress: {});

  void addLog(String message) {
    state = DownloadLogState(
      logs: [...state.logs, message],
      progress: state.progress,
    );
  }

  void updateProgress(String id, double p) {
    final nextProgress = Map<String, double>.from(state.progress);
    nextProgress[id] = p;
    state = DownloadLogState(logs: state.logs, progress: nextProgress);
  }
}

final downloadLogsProvider = NotifierProvider<DownloadLogNotifier, DownloadLogState>(DownloadLogNotifier.new);

final musicPlayerProvider = Provider((ref) {
  final player = AudioPlayer(
    userAgent: "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36",
  );
  
  // High-level listener for diagnostics
  player.playbackEventStream.listen((event) {
    // Slient in production/dev for less terminal noise
  }, onError: (Object e, StackTrace st) {
    debugPrint('ZMR CRITICAL PLAYER ERROR: $e');
    debugPrint('ZMR STACKTRACE: $st');
  });

  return player;
});

final playerProcessingStateProvider = StreamProvider<ProcessingState>((ref) {
  return ref.watch(musicPlayerProvider).processingStateStream;
});

final playerPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(musicPlayerProvider).positionStream;
});

final playerDurationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(musicPlayerProvider).durationStream;
});

final playerBufferedPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(musicPlayerProvider).bufferedPositionStream;
});

class CurrentSongNotifier extends Notifier<Song?> {
  @override
  Song? build() {
    // Sync with PlaybackNotifier
    return ref.watch(playbackProvider).currentSong;
  }
}

class PlaybackState {
  final List<Song> queue;
  final List<int> playlistOrder;
  final int currentIndex;
  final bool isShuffle;
  final bool isRepeat;
  final bool isRepeatOne;

  PlaybackState({
    required this.queue,
    required this.playlistOrder,
    required this.currentIndex,
    this.isShuffle = false,
    this.isRepeat = false,
    this.isRepeatOne = false,
    this.isFetchingMore = false,
    this.originPlaylistId,
  });

  final bool isFetchingMore;
  final String? originPlaylistId;

  Song? get currentSong => (currentIndex >= 0 && currentIndex < playlistOrder.length) 
      ? queue[playlistOrder[currentIndex]] 
      : null;

  PlaybackState copyWith({
    List<Song>? queue,
    List<int>? playlistOrder,
    int? currentIndex,
    bool? isShuffle,
    bool? isRepeat,
    bool? isRepeatOne,
    bool? isFetchingMore,
    String? originPlaylistId,
  }) {
    return PlaybackState(
      queue: queue ?? this.queue,
      playlistOrder: playlistOrder ?? this.playlistOrder,
      currentIndex: currentIndex ?? this.currentIndex,
      isShuffle: isShuffle ?? this.isShuffle,
      isRepeat: isRepeat ?? this.isRepeat,
      isRepeatOne: isRepeatOne ?? this.isRepeatOne,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      originPlaylistId: originPlaylistId ?? this.originPlaylistId,
    );
  }
}

class PlaybackNotifier extends Notifier<PlaybackState> {
  @override
  PlaybackState build() {
    return PlaybackState(queue: [], playlistOrder: [], currentIndex: -1, isFetchingMore: false, originPlaylistId: null);
  }

  List<int> _generateSmartShuffle(List<Song> currentQueue, int startIndex) {
    int length = currentQueue.length;
    if (length <= 1) return [0];
    List<int> indices = List.generate(length, (i) => i);
    indices.remove(startIndex);
    final random = Random();
    for (int i = indices.length - 1; i > 0; i--) {
      int j = random.nextInt(i + 1);
      int temp = indices[i];
      indices[i] = indices[j];
      indices[j] = temp;
    }
    List<int> result = [startIndex];
    List<int> pool = List.from(indices);
    while (pool.isNotEmpty) {
      final lastSong = currentQueue[result.last];
      int foundIndex = -1;
      for (int i = 0; i < pool.length; i++) {
        final candidate = currentQueue[pool[i]];
        if (candidate.artist != lastSong.artist) {
          foundIndex = i;
          break;
        }
      }
      int indexToAdd = foundIndex != -1 ? foundIndex : 0;
      result.add(pool.removeAt(indexToAdd));
    }
    return result;
  }

  /// Specialized method to start a radio session from a single song
  Future<void> startRadio(Song song) async {
    // 1. Initial State: Playing the seed song only, marking as fetching
    state = state.copyWith(
      queue: [song],
      playlistOrder: [0],
      currentIndex: 0,
      originPlaylistId: null,
      isFetchingMore: true,
    );
    
    // 2. Play immediately for instant gratification (don't await so discovery starts)
    _playCurrent();

    // 3. Background Radio Discovery
    try {
      debugPrint('ZMR [START-RADIO]: Entering discovery phase...');
      final ytService = ref.read(youtubeServiceProvider);
      
      debugPrint('ZMR [START-RADIO]: Calling ytService.fetchRadioSongs...');
      final radioSongs = await ytService.fetchRadioSongs(song.id);
      debugPrint('ZMR [START-RADIO]: ytService.fetchRadioSongs returned ${radioSongs.length} items.');
      
      if (radioSongs.isNotEmpty) {
        final startIdx = state.queue.length;
        final updatedQueue = [...state.queue, ...radioSongs];
        final newIndices = List.generate(radioSongs.length, (i) => startIdx + i);
        
        newIndices.shuffle();
        
        state = state.copyWith(
          queue: updatedQueue,
          playlistOrder: [0, ...newIndices],
        );
        debugPrint('ZMR [START-RADIO]: Queue updated successfully.');
      } else {
        debugPrint('ZMR [START-RADIO]: Radio songs list was empty.');
      }
    } catch (e) {
      debugPrint('ZMR [START-RADIO] ERROR: $e');
    } finally {
      debugPrint('ZMR [START-RADIO]: Discovery finished. Resetting isFetchingMore.');
      state = state.copyWith(isFetchingMore: false);
    }
  }

  Future<void> setQueue(List<Song> songs, {int initialIndex = 0, String? playlistId}) async {
    List<int> order;
    int indexInOrder = 0;
    if (state.isShuffle) {
      order = _generateSmartShuffle(songs, initialIndex);
      indexInOrder = 0;
    } else {
      order = List.generate(songs.length, (i) => i);
      indexInOrder = initialIndex;
    }
    state = state.copyWith(queue: songs, playlistOrder: order, currentIndex: indexInOrder, originPlaylistId: playlistId);
    if (state.currentSong != null) {
      await _playCurrent();
      if (playlistId == null) {
        _checkAndExtendQueue();
      }
    }
  }

  void toggleShuffle() {
    final newState = !state.isShuffle;
    List<int> newOrder;
    int newIndex = 0;
    if (newState && state.queue.isNotEmpty) {
      final currentIdx = state.playlistOrder[state.currentIndex];
      newOrder = _generateSmartShuffle(state.queue, currentIdx);
      newIndex = 0;
    } else if (state.queue.isNotEmpty) {
      final currentIdx = state.playlistOrder[state.currentIndex];
      newOrder = List.generate(state.queue.length, (i) => i);
      newIndex = currentIdx;
    } else {
      newOrder = [];
    }
    state = state.copyWith(isShuffle: newState, playlistOrder: newOrder, currentIndex: newIndex);
  }

  Future<void> _checkAndExtendQueue() async {
    if (state.queue.isEmpty || state.isFetchingMore) return;
    
    state = state.copyWith(isFetchingMore: true);
    
    try {
      final remainingCount = state.playlistOrder.length - 1 - state.currentIndex;
      debugPrint('ZMR [QUEUE]: Checking extension. Remaining: $remainingCount. Origin: ${state.originPlaylistId}');
      
      if (remainingCount < 10) {
        debugPrint('ZMR [QUEUE]: Near end of queue. Fetching more...');
        await _performQueueExtension();
      } else {
        debugPrint('ZMR [QUEUE]: Sufficient buffer remaining.');
      }
    } catch (e) {
      debugPrint('ZMR [QUEUE] Auto-extend check error: $e');
    } finally {
      state = state.copyWith(isFetchingMore: false);
    }
  }

  Future<void> _performQueueExtension() async {
    final currentSong = state.currentSong;
    if (currentSong == null) return;
    
    final ytService = ref.read(youtubeServiceProvider);
    
    // PRIORITY 1: Fetch more from ORIGINAL PLAYLIST if applicable (Lazy Load)
    if (state.originPlaylistId != null) {
      // NOTE: Our fetchPlaylistSongs already tries to get all, but if it was capped/failed,
      // we might want a way to Resume Fetching. For now, since we updated YoutubeService to 5000,
      // it should be full. If not, radio is the secondary fallback.
    }

    // FALLBACK / AUTO-PLAY: Fetch 'Radio' / Related songs for the current track
    try {
      final radioSongs = await ytService.fetchRadioSongs(currentSong.id);
      if (radioSongs.isNotEmpty) {
        final existingIds = state.queue.map((s) => s.id).toSet();
        final uniqueNewSongs = radioSongs.where((s) => !existingIds.contains(s.id)).toList();
        
        if (uniqueNewSongs.isNotEmpty) {
          final startIdx = state.queue.length;
          final updatedQueue = [...state.queue, ...uniqueNewSongs];
          final newOrderIndices = List.generate(uniqueNewSongs.length, (i) => startIdx + i);
          
          if (state.isShuffle || state.originPlaylistId == null) {
            newOrderIndices.shuffle();
          }
          
          final updatedOrder = [...state.playlistOrder, ...newOrderIndices];
          state = state.copyWith(queue: updatedQueue, playlistOrder: updatedOrder);
          debugPrint('ZMR [QUEUE]: Auto-appended ${uniqueNewSongs.length} unique related songs.');
        }
      }
    } catch (e) {
      debugPrint('ZMR [QUEUE] Auto-extend failed: $e');
    }
  }

  void toggleRepeat() {
    if (state.isRepeatOne) state = state.copyWith(isRepeat: false, isRepeatOne: false);
    else if (state.isRepeat) state = state.copyWith(isRepeat: true, isRepeatOne: true);
    else state = state.copyWith(isRepeat: true, isRepeatOne: false);
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;
    int nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.playlistOrder.length) {
      if (state.isRepeat) nextIndex = 0;
      else return;
    }
    state = state.copyWith(currentIndex: nextIndex);
    await _playCurrent();
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;
    int prevIndex = state.currentIndex - 1;
    if (prevIndex < 0) {
      if (state.isRepeat) prevIndex = state.playlistOrder.length - 1;
      else prevIndex = 0;
    }
    state = state.copyWith(currentIndex: prevIndex);
    await _playCurrent();
  }

  /// Jump directly to a specific position in the play order
  Future<void> jumpTo(int orderIndex) async {
    if (state.queue.isEmpty) return;
    final clampedIndex = orderIndex.clamp(0, state.playlistOrder.length - 1);
    state = state.copyWith(currentIndex: clampedIndex);
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final song = state.currentSong;
    if (song == null) return;
    final player = ref.read(musicPlayerProvider);
    final ytService = ref.read(youtubeServiceProvider);
    final dbService = ref.read(supabaseServiceProvider);
    try {
      await player.stop();
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.music());
      await session.setActive(true);
      String playUrl = '';
      final isOffline = await dbService.isSongSavedOffline(song.id);
      if (isOffline) {
        final user = dbService.client.auth.currentUser;
        if (user != null) {
          final res = await dbService.client.from('user_songs').select('local_path').eq('user_id', user.id).eq('yt_id', song.id).maybeSingle();
          if (res != null && res['local_path'] != null) playUrl = res['local_path'] as String;
        }
      }
      if (playUrl.isEmpty) playUrl = await ytService.getDirectStreamUrl(song.id);
      player.setVolume(1.0);
      if (playUrl.startsWith('http')) await player.setUrl(playUrl);
      else await player.setFilePath(playUrl);
      await player.play(); 

      // If we are getting near the end of the current queue, fetch related songs
      _checkAndExtendQueue();
    } catch (e) {
      debugPrint('ZMR Playback Error: $e');
    }
  }
}

final playbackProvider = NotifierProvider<PlaybackNotifier, PlaybackState>(PlaybackNotifier.new);

final currentSongProvider = NotifierProvider<CurrentSongNotifier, Song?>(CurrentSongNotifier.new);

final isPlayingProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(musicPlayerProvider);
  return player.playingStream;
});

class MusicNotifier extends Notifier<SearchResponse> {
  @override
  SearchResponse build() => SearchResponse.empty();

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = SearchResponse.empty();
      return;
    }
    
    state = state.copyWith(isLoading: true);
    final ytService = ref.read(youtubeServiceProvider);
    try {
      final results = await ytService.searchMusic(query);
      state = results.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> play(Song song) async {
    await ref.read(playbackProvider.notifier).startRadio(song);
  }
}

final musicNotifierProvider = NotifierProvider<MusicNotifier, SearchResponse>(MusicNotifier.new);

// Trending Songs Provider
final trendingSongsProvider = AsyncNotifierProvider<TrendingSongsNotifier, List<Song>>(TrendingSongsNotifier.new);

class TrendingSongsNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() async {
    final ytService = ref.read(youtubeServiceProvider);
    return await ytService.getTrendingSongs();
  }
}

// Home Feed Provider (Quick Picks, etc.)
final homeFeedProvider = AsyncNotifierProvider<HomeFeedNotifier, List<HomeSection>>(HomeFeedNotifier.new);

class HomeFeedNotifier extends AsyncNotifier<List<HomeSection>> {
  @override
  Future<List<HomeSection>> build() async {
    final ytService = ref.watch(youtubeServiceProvider);
    return await ytService.fetchHomeFeed();
  }
}

// User Playlists Provider
final userPlaylistsProvider = AsyncNotifierProvider<UserPlaylistsNotifier, List<ZmrPlaylist>>(UserPlaylistsNotifier.new);

class UserPlaylistsNotifier extends AsyncNotifier<List<ZmrPlaylist>> {
  static const _cacheKey = 'zmr_cached_playlists';

  @override
  Future<List<ZmrPlaylist>> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final ytService = ref.watch(youtubeServiceProvider);
    
    // Watch liked songs to update the count in the library view instantly
    final likedSongs = ref.watch(likedSongsProvider).asData?.value ?? [];
    
    try {
      final playlists = await ytService.fetchPlaylists();
      
      if (playlists.isNotEmpty) {
        // Update cache
        final jsonStr = json.encode(playlists.map((p) => p.toMap()).toList());
        prefs.setString(_cacheKey, jsonStr);

        return playlists.map((p) {
          if (p.id == 'LM' || p.id == 'VLLM' || p.id == 'FEmusic_liked_songs' || p.id == 'FEmusic_liked_videos') {
            return p.copyWith(songCount: likedSongs.length);
          }
          return p;
        }).toList();
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        debugPrint('ZMR [AUTH]: Clearing expired cookies from Playlists provider.');
        Future.microtask(() => ref.read(youtubeCookieProvider.notifier).setCookies(null));
      }
      debugPrint('Fetch Playlists Error: $e');
    }

    // fallback to cache
    final cachedJson = prefs.getString(_cacheKey);
    if (cachedJson != null) {
      final List decoded = json.decode(cachedJson);
      return decoded.map((p) => ZmrPlaylist.fromMap(p)).toList();
    }

    return [];
  }
}


// Liked Songs Provider (Quick Play)
final likedSongsProvider = AsyncNotifierProvider<LikedSongsNotifier, List<Song>>(LikedSongsNotifier.new);

class LikedSongsNotifier extends AsyncNotifier<List<Song>> {
  static const _cacheKey = 'zmr_cached_liked_songs';

  @override
  Future<List<Song>> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final ytService = ref.watch(youtubeServiceProvider);
    
    try {
      final songs = await ytService.fetchLikedSongs();
      if (songs.isNotEmpty) {
        // Update cache
        final jsonStr = json.encode(songs.map((s) => s.toMap()).toList());
        prefs.setString(_cacheKey, jsonStr);
        
        return songs;
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        debugPrint('ZMR [AUTH]: Clearing expired cookies from Liked Songs provider.');
        Future.microtask(() => ref.read(youtubeCookieProvider.notifier).setCookies(null));
      }
      debugPrint('Fetch Liked Songs Error: $e');
    }

    // fallback to cache
    final cachedJson = prefs.getString(_cacheKey);
    if (cachedJson != null) {
      final List decoded = json.decode(cachedJson);
      return decoded.map((s) => Song.fromMap(s)).toList();
    }

    return [];
  }

  /// Optimistically toggles the liked status of a song
  Future<void> toggleLike(Song song) async {
    final ytService = ref.read(youtubeServiceProvider);
    
    // Capture current state for potential revert
    final previousState = state;
    final currentList = state.value ?? [];
    final isLiked = currentList.any((s) => s.id == song.id);
    
    // 1. Update UI Immediately (Optimistic)
    if (isLiked) {
      // Remove from list
      state = AsyncData(currentList.where((s) => s.id != song.id).toList());
    } else {
      // Add to front of list
      state = AsyncData([song, ...currentList]);
    }
    
    // 2. Perform Backend Update
    try {
      if (isLiked) {
        await ytService.unlikeVideo(song.id);
      } else {
        await ytService.likeVideo(song.id);
      }
    } catch (e) {
      // 3. Rollback if API fails
      state = previousState;
      debugPrint('ZMR [LIKE-TOGGLE] Error (Rolled back): $e');
      rethrow;
    }
  }
}

// Single Playlist Songs Provider
final playlistSongsProvider = FutureProvider.family<List<Song>, String>((ref, playlistId) async {
  // If it's the virtual Liked Songs ID, use the dedicated provider
  if (playlistId == 'LM' || playlistId == 'FEmusic_liked_songs' || playlistId == 'FEmusic_liked_videos') {
    return ref.watch(likedSongsProvider.future);
  }

  final ytService = ref.watch(youtubeServiceProvider);
  final dbService = ref.read(supabaseServiceProvider);
  
  // Try to find the playlist name from the already loaded playlists
  final playlists = ref.read(userPlaylistsProvider).asData?.value ?? [];
  final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
  final playlistName = playlist?.title ?? 'Unknown Playlist';

  final songs = await ytService.fetchPlaylistSongs(playlistId);
  
  if (songs.isNotEmpty) {
    // Sync newly discovered playlist songs to Supabase with the correct playlist name
    dbService.syncSongs(songs, playlistName: playlistName);
  }
  
  return songs;
});

// Simple refresh notifier for offline status
class OfflineStatusNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state = state + 1;
}
final offlineRefreshProvider = NotifierProvider<OfflineStatusNotifier, int>(OfflineStatusNotifier.new);

final offlineStatusProvider = FutureProvider.family<bool, String>((ref, songId) async {
  ref.watch(offlineRefreshProvider); // Re-run when manually refreshed
  final dbService = ref.read(supabaseServiceProvider);
  return await dbService.isSongSavedOffline(songId);
});

// Sleep Timer Logic
class SleepTimerNotifier extends Notifier<Duration?> {
  Timer? _timer;

  @override
  Duration? build() => null;

  void setTimer(Duration duration) {
    _timer?.cancel();
    state = duration;
    _startCountdown();
  }

  void cancelTimer() {
    _timer?.cancel();
    state = null;
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state == null) {
        timer.cancel();
        return;
      }
      
      if (state!.inSeconds <= 0) {
        timer.cancel();
        state = null;
        // Auto-pause playback when timer hits 0
        ref.read(musicPlayerProvider).pause();
      } else {
        state = state! - const Duration(seconds: 1);
      }
    });
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, Duration?>(SleepTimerNotifier.new);
