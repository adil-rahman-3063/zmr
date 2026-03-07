import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../core/youtube_config.dart';
import '../models/song_model.dart';

class TokenPair {
  final String visitorData;
  final String poToken;

  TokenPair({required this.visitorData, required this.poToken});

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      visitorData: json['visitorData'] ?? '',
      poToken: json['poToken'] ?? '',
    );
  }
}

class YoutubeService {
  final _dio = Dio();
  final _yt = YoutubeExplode();

  static const String innertubeKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
  
  TokenPair? _tokens;

  /// Fetches fresh tokens from the Render backend if not already available.
  Future<TokenPair> getValidTokens() async {
    if (_tokens != null) return _tokens!;
    return await fetchTokens();
  }

  /// Fetches fresh tokens from the Render backend.
  Future<TokenPair> fetchTokens() async {
    try {
      final response = await _dio.get('${YoutubeConfig.renderBaseUrl}${YoutubeConfig.dataEndpoint}');
      if (response.statusCode == 200) {
        _tokens = TokenPair.fromJson(response.data);
        return _tokens!;
      } else {
        throw Exception('Failed to fetch tokens from Render: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching tokens: $e');
    }
  }

  /// Searches for music tracks on YouTube Music using Innertube with poToken/visitorData.
  Future<List<Song>> searchMusic(String query) async {
    try {
      final tokens = await getValidTokens();
      
      final url = 'https://music.youtube.com/youtubei/v1/search?key=$innertubeKey';
      
      final body = {
        "context": {
          "client": {
            "clientName": "WEB_REMIX",
            "clientVersion": "1.20240101.01.00",
            "visitorData": tokens.visitorData
          },
          "serviceIntegrityDimensions": {
            "poToken": tokens.poToken
          }
        },
        "query": query,
        "params": "Eg-KAQwIARAAGAAgACgA" // Filter specifically for "Songs"
      };

      final response = await _dio.post(
        url,
        data: jsonEncode(body),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'x-goog-visitor-id': tokens.visitorData,
            'Origin': 'https://music.youtube.com',
          },
        ),
      );

      if (response.statusCode == 200) {
        return _parseSearchResponse(response.data);
      } else {
        throw Exception('Search request failed: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to youtube_explode if direct Innertube fails
      final result = await _yt.search.search(query);
      return result.map((v) => Song.fromVideo(v)).toList();
    }
  }

  /// Basic parser for YT Music search response (Simplified)
  List<Song> _parseSearchResponse(dynamic data) {
    final List<Song> songs = [];
    try {
      final sections = data['contents']['tabbedSearchResultsRenderer']['tabs'][0]['tabRenderer']['content']['sectionListRenderer']['contents'];
      
      for (var section in sections) {
        final shelf = section['musicShelfRenderer'];
        if (shelf == null) continue;
        
        final contents = shelf['contents'];
        for (var item in contents) {
          final renderer = item['musicResponsiveListItemRenderer'];
          if (renderer == null) continue;

          final flexCols = renderer['flexColumns'];
          final title = flexCols[0]['musicResponsiveListItemFlexColumnRenderer']['text']['runs'][0]['text'];
          final id = renderer['playlistItemData']?['videoId'] ?? renderer['onTap']?['watchEndpoint']?['videoId'];
          if (id == null) continue;

          final artist = flexCols[1]['musicResponsiveListItemFlexColumnRenderer']['text']['runs'][0]['text'];
          final thumbnail = renderer['thumbnail']['musicThumbnailRenderer']['thumbnail']['thumbnails'].last['url'];

          songs.add(Song(
            id: id,
            title: title,
            artist: artist,
            duration: '', // Duration needs deeper nesting
            thumbnailUrl: thumbnail,
          ));
        }
      }
    } catch (e) {
      debugPrint('Parsing error: $e');
    }
    return songs;
  }

  /// Gets the stream URL for a given video ID.
  Future<String> getStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      throw Exception('Error getting stream URL: $e');
    }
  }

  void dispose() {
    _yt.close();
  }
}
