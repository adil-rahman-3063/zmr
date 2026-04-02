import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song_model.dart';

class SupabaseService {
  final _client = Supabase.instance.client;
  SupabaseClient get client => _client;

  Future<void> syncSongs(List<Song> songs, {String? playlistName}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Deduplicate by yt_id within the batch to prevent "ON CONFLICT" errors in Supabase
    final Map<String, Map<String, dynamic>> deduped = {};
    
    for (var song in songs) {
      deduped[song.id] = {
        'user_id': user.id,
        'yt_id': song.id,
        'title': song.title,
        'artist': song.artist,
        'thumbnail_url': song.thumbnailUrl,
        'duration': song.duration,
        'is_music': song.isMusic,
        'playlist_name': playlistName,
        'synced_at': DateTime.now().toIso8601String(),
      };
    }

    final data = deduped.values.toList();

    try {
      // Upsert: Insert if not exists, do nothing if user_id + yt_id combination exists
      // This ensures we never duplicate a song for the same user.
      await _client
          .from('user_songs')
          .upsert(
            data,
            onConflict: 'user_id,yt_id',
          );
    } catch (e) {
      debugPrint('Supabase Sync Error: $e');
    }
  }

  /// Checks if a song exists in the local Supabase cache context
  Future<bool> isSongSavedOffline(String ytId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    
    try {
      final response = await _client
          .from('user_songs')
          .select('is_downloaded')
          .eq('user_id', user.id)
          .eq('yt_id', ytId)
          .maybeSingle();
      
      return response != null && response['is_downloaded'] == true;
    } catch (e) {
      debugPrint('isSongSavedOffline Error: $e');
      return false;
    }
  }

  /// Updates the download status and path for a specific song in Supabase
  Future<void> updateOfflineStatus(String ytId, bool isDownloaded, String localPath, {bool isDrive = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    try {
      await _client
          .from('user_songs')
          .update({
            'is_downloaded': isDownloaded,
            'local_path': localPath,
            'is_drive': isDrive,
          })
          .eq('user_id', user.id)
          .eq('yt_id', ytId);
    } catch (e) {
      debugPrint('updateOfflineStatus Error: $e');
    }
  }

  /// Creates a new user playlist in Supabase
  Future<void> createPlaylist(String title, {String? thumbnailUrl}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    try {
      await _client
          .from('playlists')
          .insert({
            'user_id': user.id,
            'title': title,
            'thumbnail_url': thumbnailUrl,
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Supabase createPlaylist Error: $e');
      rethrow;
    }
  }
}
