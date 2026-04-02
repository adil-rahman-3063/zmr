import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/youtube_config.dart';

/// Comprehensive InnerTube Client ported from Metrolist.
/// This class handles the raw communication with YouTube Music's private API.
class InnerTubeClient {
  final Dio _dio = Dio();
  
  // Standard InnerTube Keys
  static const String defaultKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
  static const String transcriptKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX3';

  // Client Constants
  static const String clientName = 'WEB_REMIX';
  static const String clientVersion = '1.20260213.01.00';
  static const String userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0';
  static const String origin = 'https://music.youtube.com';
  static const String referer = 'https://music.youtube.com/';
  static const String apiBase = 'https://music.youtube.com/youtubei/v1';

  String? _visitorData;
  String? _poToken;
  String? _cookies;

  void updateTokens(String visitorData, String poToken) {
    _visitorData = visitorData;
    _poToken = poToken;
  }

  void updateCookies(String? cookies) {
    _cookies = cookies;
  }

  /// Generates the SAPISIDHASH required for authenticated requests.
  String? _getSapisidHash() {
    if (_cookies == null) return null;
    
    // Extract SAPISID from cookies
    final cookieMap = Map.fromEntries(
      _cookies!.split(';').map((e) {
        final parts = e.trim().split('=');
        if (parts.length < 2) return const MapEntry('', '');
        return MapEntry(parts[0], parts.sublist(1).join('='));
      }).where((e) => e.key.isNotEmpty),
    );

    final sapisid = cookieMap['SAPISID'];
    if (sapisid == null) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final hashInput = '$timestamp $sapisid $origin';
    final hash = sha1.convert(utf8.encode(hashInput)).toString();
    
    return 'SAPISIDHASH ${timestamp}_$hash';
  }

  Map<String, String> _getHeaders({bool requireAuth = false}) {
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': userAgent,
      'X-Goog-Api-Format-Version': '1',
      'X-YouTube-Client-Name': '67', // WEB_REMIX
      'X-YouTube-Client-Version': clientVersion,
      'X-Origin': origin,
      'Referer': referer,
    };

    if (_visitorData != null) {
      headers['X-Goog-Visitor-Id'] = _visitorData!;
    }

    if (_cookies != null) {
      headers['Cookie'] = _cookies!;
      final auth = _getSapisidHash();
      if (auth != null) {
        headers['Authorization'] = auth;
      }
    }

    return headers;
  }

  Map<String, dynamic> _getContext({bool setLogin = false}) {
    return {
      "context": {
        "client": {
          "clientName": clientName,
          "clientVersion": clientVersion,
          "hl": "en",
          "gl": "US",
          "visitorData": _visitorData,
          "poToken": _poToken,
        },
        "user": {
          "lockedSafetyMode": false,
        }
      }
    };
  }

  Future<Response> post(String endpoint, Map<String, dynamic> body, {String? key, bool setLogin = false}) async {
    final url = '$apiBase/$endpoint?key=${key ?? defaultKey}';
    final requestBody = _getContext(setLogin: setLogin);
    requestBody.addAll(body);

    try {
      final response = await _dio.post(
        url,
        data: jsonEncode(requestBody),
        options: Options(headers: _getHeaders()),
      );
      return response;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw Exception('AUTH_ERROR');
      }
      rethrow;
    }
  }

  // --- Endpoints Implementation ---

  /// Fetch Homepage, Playlists, Artists, Albums
  Future<Response> browse({String? browseId, String? params, String? continuation, bool setLogin = false}) {
    return post('browse', {
      if (continuation != null)
        'continuation': continuation
      else ...{
        if (browseId != null) 'browseId': browseId,
        if (params != null) 'params': params,
      }
    }, setLogin: setLogin);
  }

  /// Global Search
  Future<Response> search({String? query, String? params, String? continuation}) {
    return post('search', {
      if (query != null) 'query': query,
      if (params != null) 'params': params,
      if (continuation != null) 'continuation': continuation,
    });
  }

  /// Get search suggestions while typing
  Future<Response> getSearchSuggestions(String input) {
    return post('music/get_search_suggestions', {'input': input});
  }

  /// Player metadata and stream extraction
  Future<Response> player(String videoId, {String? playlistId}) {
    return post('player', {
      'videoId': videoId,
      if (playlistId != null) 'playlistId': playlistId,
      'playbackContext': {
        'contentPlaybackContext': {
          'signatureTimestamp': 20000 // Placeholder, updated in Metrolist
        }
      }
    });
  }

  /// Up Next, Related, and Lyrics Bridge
  Future<Response> next({
    String? videoId,
    String? playlistId,
    String? params,
    String? continuation,
  }) {
    return post('next', {
      if (videoId != null) 'videoId': videoId,
      if (playlistId != null) 'playlistId': playlistId,
      if (params != null) 'params': params,
      if (continuation != null) 'continuation': continuation,
    });
  }

  /// Liking/Disliking
  Future<Response> like(String videoId) => post('like/like', {
    'target': {'videoId': videoId}
  });

  Future<Response> unlike(String videoId) => post('like/removelike', {
    'target': {'videoId': videoId}
  });

  /// Subscriptions
  Future<Response> subscribe(String channelId) => post('subscription/subscribe', {
    'channelIds': [channelId]
  });

  Future<Response> unsubscribe(String channelId) => post('subscription/unsubscribe', {
    'channelIds': [channelId]
  });

  /// Playlist Management
  Future<Response> createPlaylist(String title) => post('playlist/create', {'title': title});
  
  Future<Response> deletePlaylist(String playlistId) => post('playlist/delete', {'playlistId': playlistId});

  Future<Response> editPlaylist(String playlistId, List<Map<String, dynamic>> actions) {
    return post('browse/edit_playlist', {
      'playlistId': playlistId.startsWith('VL') ? playlistId.substring(2) : playlistId,
      'actions': actions
    });
  }

  /// Fetch Radio/Playlist Queue
  Future<Response> getQueue({List<String>? videoIds, String? playlistId}) {
    return post('music/get_queue', {
      if (videoIds != null) 'videoIds': videoIds,
      if (playlistId != null) 'playlistId': playlistId,
    });
  }

  /// Fetch Transcript/Lyrics
  Future<Response> getTranscript(String videoId) {
    // Note: get_transcript uses a slightly different context/body structure in some versions
    return post('get_transcript', {
      'params': base64.encode(utf8.encode('\n\u000b$videoId'))
    }, key: transcriptKey);
  }
}
