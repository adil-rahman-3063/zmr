import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class ZmrAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  AudioPlayer get internalPlayer => _player;
  
  VoidCallback? onNext;
  VoidCallback? onPrevious;

  ZmrAudioHandler(this._player) {
    // Forward playback state changes
    _player.playbackEventStream.listen(_broadcastState);
    
    // Handle processing state changes
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });

    // Update media item with precise duration when available
    _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        final item = mediaItem.value!.copyWith(duration: duration);
        mediaItem.add(item);
      }
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
  
  @override
  Future<void> skipToNext() async {
    if (onNext != null) onNext!();
  }
  
  @override
  Future<void> skipToPrevious() async {
    if (onPrevious != null) onPrevious!();
  }

  /// Broadcasts the current playback state to audio_service
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.playPause,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  /// Call this when the metadata changes (new song starts)
  void updateMetadata(MediaItem item) {
    mediaItem.add(item);
  }
}
