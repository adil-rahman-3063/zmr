import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../services/youtube_service.dart';

final youtubeServiceProvider = Provider((ref) => YoutubeService());

final musicPlayerProvider = Provider((ref) => AudioPlayer());

class CurrentSongNotifier extends Notifier<Song?> {
  @override
  Song? build() => null;
  void setSong(Song? song) => state = song;
}

final currentSongProvider = NotifierProvider<CurrentSongNotifier, Song?>(CurrentSongNotifier.new);

final isPlayingProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(musicPlayerProvider);
  return player.playingStream;
});

class MusicNotifier extends Notifier<List<Song>> {
  @override
  List<Song> build() => [];

  Future<void> search(String query) async {
    final ytService = ref.read(youtubeServiceProvider);
    final results = await ytService.searchMusic(query);
    state = results;
  }

  Future<void> play(Song song) async {
    final player = ref.read(musicPlayerProvider);
    final ytService = ref.read(youtubeServiceProvider);
    
    ref.read(currentSongProvider.notifier).setSong(song);
    
    try {
      final url = await ytService.getStreamUrl(song.id);
      await player.setUrl(url);
      player.play();
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }
}

final musicNotifierProvider = NotifierProvider<MusicNotifier, List<Song>>(MusicNotifier.new);
