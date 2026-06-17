import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:zmr/services/audio_handler.dart';
import 'package:zmr/models/song_model.dart';
import 'package:zmr/models/playlist_model.dart';
import 'package:zmr/models/home_feed.dart';
import 'package:zmr/models/home_chip.dart';
import 'package:zmr/models/search_response.dart';
import 'package:zmr/models/lyrics_model.dart';
import 'package:zmr/models/artist_model.dart';
import 'package:zmr/models/artist_details.dart';
import 'package:zmr/services/youtube_service.dart';
import 'package:zmr/providers/settings_provider.dart';


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

// UI Help Video: Track if UI help bottom sheet has been shown to new users
class UIHelpNotifier extends Notifier<bool> {
  static const _key = 'zmr_ui_help_shown';

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

final uiHelpShownProvider = NotifierProvider<UIHelpNotifier, bool>(UIHelpNotifier.new);

// Cookie onboarding: Track if cookie dialog was shown to new users
class CookieOnboardingNotifier extends Notifier<bool> {
  static const _key = 'zmr_cookie_onboarding_shown';

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

final cookieOnboardingProvider = NotifierProvider<CookieOnboardingNotifier, bool>(CookieOnboardingNotifier.new);

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




final musicPlayerProvider = Provider<AudioPlayer?>((ref) {
  try {
    final h = zmrAudioHandlerInstance;
    if (h != null) {
      if (h is ZmrAudioHandler) {
        return h.internalPlayer;
      } else {
        debugPrint('ZMR [DEBUG]: Global Handler is NOT ZmrAudioHandler. It is ${h.runtimeType}');
      }
    } else {
      debugPrint('ZMR [DEBUG]: zmrAudioHandlerInstance is NULL');
    }
  } catch (e) {
    debugPrint('ZMR [DEBUG]: musicPlayerProvider error: $e');
  }
  return null;
});

final audioHandlerProvider = Provider<AudioHandler?>((ref) {
  return zmrAudioHandlerInstance;
});

final playerProcessingStateProvider = StreamProvider<ProcessingState>((ref) {
  final player = ref.watch(musicPlayerProvider);
  if (player == null) return const Stream.empty();
  return player.processingStateStream;
});

final playerPositionProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(musicPlayerProvider);
  if (player == null) return const Stream.empty();
  return player.positionStream;
});

final playerDurationProvider = StreamProvider<Duration?>((ref) {
  final player = ref.watch(musicPlayerProvider);
  if (player == null) return const Stream.empty();
  return player.durationStream;
});

final playerBufferedPositionProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(musicPlayerProvider);
  if (player == null) return const Stream.empty();
  return player.bufferedPositionStream;
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

  final bool isFetchingMore;
  final bool isSwitchingTrack; // New flag
  final int consecutiveFailures; // New counter
  final String? originPlaylistId;
  final int savedPositionMs; // New field for caching

  PlaybackState({
    required this.queue,
    required this.playlistOrder,
    required this.currentIndex,
    this.isShuffle = false,
    this.isRepeat = false,
    this.isRepeatOne = false,
    this.isFetchingMore = false,
    this.isSwitchingTrack = false,
    this.consecutiveFailures = 0,
    this.originPlaylistId,
    this.savedPositionMs = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'queue': queue.map((x) => x.toMap()).toList(),
      'playlistOrder': playlistOrder,
      'currentIndex': currentIndex,
      'isShuffle': isShuffle,
      'isRepeat': isRepeat,
      'isRepeatOne': isRepeatOne,
      'originPlaylistId': originPlaylistId,
      'savedPositionMs': savedPositionMs,
    };
  }

  factory PlaybackState.fromMap(Map<String, dynamic> map) {
    return PlaybackState(
      queue: List<Song>.from(map['queue']?.map((x) => Song.fromMap(x)) ?? []),
      playlistOrder: List<int>.from(map['playlistOrder'] ?? []),
      currentIndex: map['currentIndex']?.toInt() ?? -1,
      isShuffle: map['isShuffle'] ?? false,
      isRepeat: map['isRepeat'] ?? false,
      isRepeatOne: map['isRepeatOne'] ?? false,
      originPlaylistId: map['originPlaylistId'],
      savedPositionMs: map['savedPositionMs']?.toInt() ?? 0,
    );
  }

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
    bool? isSwitchingTrack,
    int? consecutiveFailures,
    String? originPlaylistId,
    int? savedPositionMs,
  }) {
    return PlaybackState(
      queue: queue ?? this.queue,
      playlistOrder: playlistOrder ?? this.playlistOrder,
      currentIndex: currentIndex ?? this.currentIndex,
      isShuffle: isShuffle ?? this.isShuffle,
      isRepeat: isRepeat ?? this.isRepeat,
      isRepeatOne: isRepeatOne ?? this.isRepeatOne,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      isSwitchingTrack: isSwitchingTrack ?? this.isSwitchingTrack,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      originPlaylistId: originPlaylistId ?? this.originPlaylistId,
      savedPositionMs: savedPositionMs ?? this.savedPositionMs,
    );
  }
}

class PlaybackNotifier extends Notifier<PlaybackState> {
  static const _cacheKey = 'zmr_playback_state_cache';
  Timer? _saveTimer;
  int _currentPlayId = 0;

  @override
  PlaybackState build() {
    // Connect audio handler callbacks to this notifier's methods
    try {
      final h = zmrAudioHandlerInstance;
      if (h is ZmrAudioHandler) {
        h.onNext = () => next();
        h.onPrevious = () => previous();
      }
    } catch (_) {}

    // Load from cache or default
    PlaybackState initialState = PlaybackState(
      queue: [], 
      playlistOrder: [], 
      currentIndex: -1, 
    );
    
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final cachedStr = prefs.getString(_cacheKey);
      if (cachedStr != null) {
        initialState = PlaybackState.fromMap(jsonDecode(cachedStr));
        
        // Restore player state silently (queue up but don't play)
        if (initialState.currentSong != null) {
          Future.microtask(() => _restorePlayerSilently(initialState));
        }
      }
    } catch (e) {
      debugPrint('ZMR [CACHE]: Failed to load playback state: $e');
    }

    // Listen to position stream to debounce save position and auto-recover from stuck buffering
    Future.microtask(() {
      final player = ref.read(musicPlayerProvider);
      if (player != null) {
        final subPos = player.positionStream.listen((pos) {
          final posMs = pos.inMilliseconds;
          // Save every ~5 seconds to avoid spamming SharedPreferences
          if (posMs > 0 && (posMs - state.savedPositionMs).abs() > 5000) {
            state = state.copyWith(savedPositionMs: posMs);
          }
        });
        
        Timer? stuckTimer;
        int recoveryAttempts = 0;

        void checkStuckState() {
          final isBuffering = player.processingState == ProcessingState.buffering;
          final isPlaying = player.playing;

          if (isBuffering && isPlaying) {
            if (stuckTimer == null) {
              debugPrint('ZMR [RECOVERY]: Player stuck in buffering. Starting periodic recovery timer.');
              stuckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
                if (player.processingState == ProcessingState.buffering && player.playing) {
                  recoveryAttempts++;
                  debugPrint('ZMR [RECOVERY]: Stuck buffering detected. Attempt #$recoveryAttempts.');
                  
                  if (recoveryAttempts == 1) {
                    try {
                      debugPrint('ZMR [RECOVERY]: Attempting simple pause/play reset.');
                      await player.pause();
                      await player.play();
                    } catch (e) {
                      debugPrint('ZMR [RECOVERY]: Pause/play failed: $e');
                    }
                  } else if (recoveryAttempts >= 2) {
                    debugPrint('ZMR [RECOVERY]: Still stuck buffering. Triggering full track reload.');
                    timer.cancel();
                    stuckTimer = null;
                    recoveryAttempts = 0;
                    
                    try {
                      await _playCurrent();
                    } catch (e) {
                      debugPrint('ZMR [RECOVERY]: Full track reload failed: $e');
                    }
                  }
                } else {
                  timer.cancel();
                  stuckTimer = null;
                  recoveryAttempts = 0;
                }
              });
            }
          } else {
            if (stuckTimer != null) {
              debugPrint('ZMR [RECOVERY]: Player active/paused. Resetting recovery timer.');
              stuckTimer!.cancel();
              stuckTimer = null;
              recoveryAttempts = 0;
            }
          }
        }

        final subState = player.processingStateStream.listen((_) => checkStuckState());
        final subPlaying = player.playingStream.listen((_) => checkStuckState());

        ref.onDispose(() {
          subPos.cancel();
          subState.cancel();
          subPlaying.cancel();
          stuckTimer?.cancel();
        });
      }
    });

    return initialState;
  }

  @override
  set state(PlaybackState value) {
    final previous = super.state;
    super.state = value;
    if (previous != value) {
      _scheduleSave();
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        prefs.setString(_cacheKey, jsonEncode(state.toMap()));
      } catch (e) {
        debugPrint('ZMR [CACHE]: Failed to save state: $e');
      }
    });
  }

  Future<void> _restorePlayerSilently(PlaybackState savedState) async {
    final song = savedState.currentSong;
    if (song == null) return;
    
    try {
      final handler = zmrAudioHandlerInstance as ZmrAudioHandler;
      // Immediately populate metadata for mini player to show something
      handler.updateMetadata(
        MediaItem(
          id: song.id,
          album: song.artist,
          title: song.title,
          artist: song.artist,
          artUri: Uri.parse(song.thumbnailUrl),
        ),
      );
      
      final player = ref.read(musicPlayerProvider);
      if (player != null) {
        await player.setLoopMode(savedState.isRepeatOne ? LoopMode.one : (savedState.isRepeat ? LoopMode.all : LoopMode.off));
        
        // Fetch the fresh stream URL in the background to be ready when user hits play
        final ytService = ref.read(youtubeServiceProvider);
        try {
          final playUrl = await ytService.getDirectStreamUrl(song.id).timeout(const Duration(seconds: 15));
          if (playUrl.isNotEmpty) {
            await player.setAudioSource(
              AudioSource.uri(
                Uri.parse(playUrl),
                tag: MediaItem(
                  id: song.id,
                  album: song.artist,
                  title: song.title,
                  artist: song.artist,
                  artUri: Uri.parse(song.thumbnailUrl),
                ),
              ),
              preload: true,
            );
            
            // Seek to the saved position!
            if (savedState.savedPositionMs > 0) {
              await player.seek(Duration(milliseconds: savedState.savedPositionMs));
            }
          }
        } catch (e) {
          debugPrint('ZMR [CACHE]: Failed to pre-fetch stream URL for restored song: $e');
        }
      }
    } catch (e) {
      debugPrint('ZMR [CACHE]: Restore failed: $e');
    }
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

  /// Plays a list of songs (playlist), optionally shuffled
  Future<void> playPlaylist(List<Song> songs, {bool shuffle = false, String? playlistId}) async {
    if (songs.isEmpty) return;
    
    List<int> order = List.generate(songs.length, (i) => i);
    if (shuffle) {
      order.shuffle();
    }
    
    state = state.copyWith(
      queue: songs,
      playlistOrder: order,
      currentIndex: 0,
      isShuffle: shuffle,
      originPlaylistId: playlistId,
    );
    
    await _playCurrent();
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
    final player = ref.read(musicPlayerProvider);
    if (state.isRepeatOne) {
      state = state.copyWith(isRepeat: false, isRepeatOne: false);
      player?.setLoopMode(LoopMode.off);
    } else if (state.isRepeat) {
      state = state.copyWith(isRepeat: true, isRepeatOne: true);
      player?.setLoopMode(LoopMode.one);
    } else {
      state = state.copyWith(isRepeat: true, isRepeatOne: false);
      player?.setLoopMode(LoopMode.all);
    }
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;
    int nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.playlistOrder.length) {
      if (state.isRepeat) {
        nextIndex = 0;
      } else {
        return;
      }
    }
    state = state.copyWith(currentIndex: nextIndex);
    await _playCurrent();
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;
    int prevIndex = state.currentIndex - 1;
    if (prevIndex < 0) {
      if (state.isRepeat) {
        prevIndex = state.playlistOrder.length - 1;
      } else {
        prevIndex = 0;
      }
    }
    state = state.copyWith(currentIndex: prevIndex);
    await _playCurrent();
  }

  Future<void> jumpTo(int orderIndex) async {
    if (state.queue.isEmpty) return;
    final clampedIndex = orderIndex.clamp(0, state.playlistOrder.length - 1);
    state = state.copyWith(currentIndex: clampedIndex);
    await _playCurrent();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (state.queue.isEmpty) return;
    
    // Calculate the actual indices in the playlistOrder list
    // The list in the UI starts at currentIndex + 1
    final offset = state.currentIndex + 1;
    final realOldIndex = oldIndex + offset;
    int realNewIndex = newIndex + offset;

    if (realOldIndex < 0 || realOldIndex >= state.playlistOrder.length) return;
    if (realNewIndex < 0) realNewIndex = 0;
    if (realNewIndex > state.playlistOrder.length) realNewIndex = state.playlistOrder.length;

    final newOrder = List<int>.from(state.playlistOrder);
    final item = newOrder.removeAt(realOldIndex);
    
    // If we're moving down, adjusting the target index because removeAt shifted everything
    if (realNewIndex > realOldIndex) {
      realNewIndex -= 1;
    }
    
    newOrder.insert(realNewIndex, item);
    state = state.copyWith(playlistOrder: newOrder);
  }

  Future<void> _playCurrent() async {
    final playId = ++_currentPlayId;
    final song = state.currentSong;
    if (song == null) return;
    
    debugPrint('ZMR [PLAY]: Attempting to play ${song.title} (PlayId: $playId)');
    final player = ref.read(musicPlayerProvider);
    if (player == null) {
      debugPrint('ZMR [PLAY] ABORT: musicPlayerProvider returned null');
      return;
    }

    final ytService = ref.read(youtubeServiceProvider);
    final handler = zmrAudioHandlerInstance as ZmrAudioHandler;

    state = state.copyWith(isSwitchingTrack: true);

    try {
      // 1. Prepare for transition
      await player.stop();
      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled at stop step');
        return;
      }
      await player.seek(Duration.zero);
      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled at seek step');
        return;
      }

      // 2. IMMEDIATELY update metadata for UI responsiveness
      handler.updateMetadata(
        MediaItem(
          id: song.id,
          album: song.artist,
          title: song.title,
          artist: song.artist,
          artUri: Uri.parse(song.thumbnailUrl),
        ),
      );

      // 3. Broadcast LOADING state to the system
      handler.broadcastLoading();

      // 4. Fetch URL with timeout/retry logic
      String playUrl = '';
      int retries = 0;
      Exception? lastError;

      while (retries < 3) {
        if (_currentPlayId != playId) {
          debugPrint('ZMR [PLAY]: Request $playId cancelled during fetch retry check');
          return;
        }
        try {
          debugPrint('ZMR [PLAY]: Fetching stream URL for ${song.id} (Attempt ${retries + 1}, PlayId: $playId)...');
          playUrl = await ytService.getDirectStreamUrl(song.id).timeout(const Duration(seconds: 15));
          if (playUrl.isNotEmpty) break;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          retries++;
          debugPrint('ZMR [PLAY]: Attempt $retries failed: $e');
          if (retries < 3) await Future.delayed(Duration(seconds: retries));
        }
      }

      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled after URL fetch');
        return;
      }

      if (playUrl.isEmpty) {
        throw lastError ?? Exception('Failed to resolve stream URL for ${song.id}');
      }
      
      debugPrint('ZMR [PLAY]: Stream URL obtained. Configuring session...');

      // 5. Configure audio session
      final session = await AudioSession.instance;
      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled before session configure');
        return;
      }
      await session.configure(const AudioSessionConfiguration.music());
      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled before session setActive');
        return;
      }
      await session.setActive(true);

      // 6. Set Player Options
      final settings = ref.read(settingsProvider);
      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled before setting volume');
        return;
      }
      await player.setVolume(settings.normalizeVolume ? 0.7 : 1.0);
      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled before setting loop mode');
        return;
      }
      await player.setLoopMode(state.isRepeatOne ? LoopMode.one : LoopMode.off);

      // 7. LOAD AND PLAY
      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled before setAudioSource');
        return;
      }
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(playUrl),
          tag: MediaItem(
            id: song.id,
            album: song.artist,
            title: song.title,
            artist: song.artist,
            artUri: Uri.parse(song.thumbnailUrl),
          ),
        ),
        preload: true,
      );

      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled before playback start');
        return;
      }

      // Track is successfully loaded. Reset switching flag now.
      state = state.copyWith(isSwitchingTrack: false, consecutiveFailures: 0);
      debugPrint('ZMR [PLAY]: Audio source set. Starting playback.');
      
      if (settings.crossfadeSeconds > 0) {
        player.setVolume(0);
        player.play();
        final targetVolume = settings.normalizeVolume ? 0.7 : 1.0;
        const steps = 10;
        final stepDuration = Duration(milliseconds: (settings.crossfadeSeconds * 1000 / steps).toInt());
        for (int i = 1; i <= steps; i++) {
          if (_currentPlayId != playId) {
            debugPrint('ZMR [PLAY]: Request $playId cancelled during crossfade step $i');
            return;
          }
          await Future.delayed(stepDuration);
          if (_currentPlayId != playId) {
            debugPrint('ZMR [PLAY]: Request $playId cancelled after crossfade step $i delay');
            return;
          }
          player.setVolume((targetVolume / steps) * i);
        }
      } else {
        await player.play(); 
      }

      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled after play call');
        return;
      }
      _checkAndExtendQueue();
      
    } catch (e) {
      if (_currentPlayId != playId) {
        debugPrint('ZMR [PLAY]: Request $playId cancelled during exception handling');
        return;
      }
      debugPrint('ZMR [PLAY] CRITICAL ERROR: $e');
      
      final failures = state.consecutiveFailures + 1;
      state = state.copyWith(isSwitchingTrack: false, consecutiveFailures: failures);

      if (failures >= 5) {
        debugPrint('ZMR [PLAY]: Too many consecutive failures ($failures). Stopping auto-skip.');
        return;
      }

      await Future.delayed(const Duration(seconds: 3));
      if (_currentPlayId != playId) return;
      
      if (state.currentSong?.id == song.id && state.queue.isNotEmpty) {
        debugPrint('ZMR [PLAY]: Auto-skipping to next after error (Failures: $failures).');
        next();
      }
    }
  }
}

final playbackProvider = NotifierProvider<PlaybackNotifier, PlaybackState>(PlaybackNotifier.new);

final currentSongProvider = NotifierProvider<CurrentSongNotifier, Song?>(CurrentSongNotifier.new);

final isPlayingProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(musicPlayerProvider);
  return player?.playingStream ?? const Stream.empty();
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

// Home Feed Provider (Quick Picks, Chips, etc.)
final homeFeedProvider = AsyncNotifierProvider<HomeFeedNotifier, HomeFeed>(HomeFeedNotifier.new);

class HomeFeedNotifier extends AsyncNotifier<HomeFeed> {
  String? _currentParams;

  @override
  Future<HomeFeed> build() async {
    final ytService = ref.watch(youtubeServiceProvider);
    return await ytService.fetchHomeFeed(params: _currentParams);
  }

  Future<void> selectCategory(HomeChip chip) async {
    // If selecting an already selected chip (that's not 'All'), we treat it as deselecting?
    // Actually YTM chips usually have a deselect endpoint or you just tap another one.
    // We'll just update params and refresh.
    _currentParams = chip.params;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await ref.read(youtubeServiceProvider).fetchHomeFeed(params: _currentParams);
    });
  }

  void reset() {
    _currentParams = null;
    ref.invalidateSelf();
  }
}

// Followed Artists Provider
final followedArtistsProvider = AsyncNotifierProvider<FollowedArtistsNotifier, List<Artist>>(FollowedArtistsNotifier.new);

class FollowedArtistsNotifier extends AsyncNotifier<List<Artist>> {
  @override
  Future<List<Artist>> build() async {
    final ytService = ref.watch(youtubeServiceProvider);
    return await ytService.fetchSubscribedArtists();
  }

  Future<void> toggleFollow(Artist artist) async {
    final ytService = ref.read(youtubeServiceProvider);
    final previousState = state;
    final currentList = state.value ?? [];
    final isFollowing = currentList.any((a) => a.id == artist.id);

    // 1. Optimistic Update
    if (isFollowing) {
      state = AsyncData(currentList.where((a) => a.id != artist.id).toList());
    } else {
      state = AsyncData([artist, ...currentList]);
    }

    // 2. Network Request
    try {
      if (isFollowing) {
        await ytService.unsubscribeFromArtist(artist.id);
      } else {
        await ytService.subscribeToArtist(artist.id);
      }
      // Re-fetch to be absolutely sure we're in sync with the server
      ref.invalidateSelf();
    } catch (e) {
      // 3. Rollback
      state = previousState;
      debugPrint('ZMR [FOLLOW-TOGGLE] Error (Rolled back): $e');
      rethrow;
    }
  }
}

// Artist New Releases Provider
final artistNewReleasesProvider = FutureProvider.family<List<Song>, String>((ref, artistId) async {
  final ytService = ref.watch(youtubeServiceProvider);
  return await ytService.fetchArtistNewReleases(artistId);
});

final artistDetailsProvider = FutureProvider.family<ArtistDetails, String>((ref, artistId) async {
  final ytService = ref.watch(youtubeServiceProvider);
  return await ytService.fetchArtistDetails(artistId);
});

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
        debugPrint('ZMR [AUTH]: Auth error detected in Playlists provider.');
        // Future.microtask(() => ref.read(youtubeCookieProvider.notifier).setCookies(null));
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

  Future<void> deletePlaylist(String playlistId) async {
    final ytService = ref.read(youtubeServiceProvider);
    await ytService.deletePlaylist(playlistId);
    ref.invalidateSelf();
  }

  Future<void> renamePlaylist(String playlistId, String newTitle) async {
    final ytService = ref.read(youtubeServiceProvider);
    await ytService.renamePlaylist(playlistId, newTitle);
    ref.invalidateSelf();
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
        debugPrint('ZMR [AUTH]: Auth error detected in Liked Songs provider.');
        // Future.microtask(() => ref.read(youtubeCookieProvider.notifier).setCookies(null));
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
  final songs = await ytService.fetchPlaylistSongs(playlistId);
  

  
  return songs;
});

// Simple refresh notifier for offline status

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
        zmrAudioHandlerInstance?.pause();
      } else {
        state = state! - const Duration(seconds: 1);
      }
    });
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, Duration?>(SleepTimerNotifier.new);

final lyricsProvider = FutureProvider.family<LyricsData?, String>((ref, songId) async {
  final ytService = ref.read(youtubeServiceProvider);
  return await ytService.fetchLyrics(songId);
});
