import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/artist_model.dart';
import '../models/search_response.dart';
import '../core/youtube_config.dart';
import '../models/home_section.dart';
import '../models/lyrics_model.dart';
import '../models/artist_details.dart';
import 'youtube_extractor_service.dart';
import 'innertube_client.dart';
import '../models/home_chip.dart';
import '../models/home_feed.dart';

class TokenPair {
  final String visitorData;
  final String poToken;
  final String? dataSyncId;

  TokenPair({required this.visitorData, required this.poToken, this.dataSyncId});

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      visitorData: Uri.decodeComponent(json['visitorData'] ?? ''),
      poToken: Uri.decodeComponent(json['poToken'] ?? ''),
      dataSyncId: json['dataSyncId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visitorData': visitorData,
      'poToken': poToken,
      'dataSyncId': dataSyncId,
    };
  }
}

class YoutubeService {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final _extractor = YouTubeExtractorService();
  final _innerTube = InnerTubeClient();
  
  static const String innertubeKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
  
  TokenPair? _tokens;
  static const String _tokenKey = 'zmr_tokens';
  String? _cookies;

  /// Fetches fresh tokens from the Cloudflare backend if not already available.
  /// If [forceRefresh] is true, it will fetch from the server regardless of cache.
  Future<TokenPair> getValidTokens({bool forceRefresh = false}) async {
    // If we have an authenticated session (dataSyncId), we MUST stick to its visitorData.
    // Overwriting it with a generic one from the worker will break the session.
    if (_tokens != null && _tokens!.dataSyncId != null) {
       _innerTube.updateTokens(_tokens!.visitorData, _tokens!.poToken, dataSyncId: _tokens!.dataSyncId);
       return _tokens!;
    }

    if (_tokens != null && !forceRefresh) {
       _innerTube.updateTokens(_tokens!.visitorData, _tokens!.poToken, dataSyncId: _tokens!.dataSyncId);
       return _tokens!;
    }

    if (!forceRefresh) {
      // Try to load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedTokens = prefs.getString(_tokenKey);
      if (savedTokens != null) {
        try {
          _tokens = TokenPair.fromJson(jsonDecode(savedTokens));
          _innerTube.updateTokens(_tokens!.visitorData, _tokens!.poToken, dataSyncId: _tokens!.dataSyncId);
          debugPrint('ZMR [TOKENS]: Loaded from CACHE.');
          return _tokens!;
        } catch (e) {
          debugPrint('ZMR [TOKENS]: Cache corruption error: $e');
        }
      }
    }

    try {
      final freshTokens = await fetchTokens();
      _innerTube.updateTokens(freshTokens.visitorData, freshTokens.poToken, dataSyncId: freshTokens.dataSyncId);
      return freshTokens;
    } catch (e) {
      debugPrint('ZMR [TOKENS]: Fetch failed, using safety fallback. Error: $e');
      final fallback = TokenPair(
        visitorData: 'CgtSdU9mS3A3S09RNCi95fWwBg%3D%3D', // Standard YTM visitor data fallback
        poToken: '',
      );
      _tokens = fallback;
      _innerTube.updateTokens(fallback.visitorData, fallback.poToken, dataSyncId: fallback.dataSyncId);
      return fallback;
    }
  }

  void setTokens(TokenPair tokens) async {
    _tokens = tokens;
    _innerTube.updateTokens(tokens.visitorData, tokens.poToken, dataSyncId: tokens.dataSyncId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, jsonEncode(tokens.toJson()));
  }

  Future<Map<String, String>?> getAccountInfo() async {
    try {
      final response = await _innerTube.getAccountMenu();
      if (response.statusCode == 200) {
        final data = response.data;
        // Basic parsing of account menu renderer
        final header = _findAllElements(data, 'activeAccountHeaderRenderer').firstOrNull;
        if (header != null) {
          final name = _getText(header['accountName']);
          final email = _getText(header['accountEmail']);
          final handle = _getText(header['channelHandle']);
          return {
            'name': name,
            'email': email,
            'handle': handle,
          };
        }
      }
    } catch (e) {
      debugPrint('ZMR [ACCOUNT]: Failed to get account info: $e');
    }
    return null;
  }

  /// Fetches fresh tokens from the Cloudflare backend and saves them to cache.
  Future<TokenPair> fetchTokens() async {
    try {
      debugPrint('ZMR [TOKENS]: Fetching from ${YoutubeConfig.tokenProviderUrl}...');
      final response = await _dio.get('${YoutubeConfig.tokenProviderUrl}${YoutubeConfig.dataEndpoint}');
      
      if (response.statusCode == 200) {
        dynamic data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            debugPrint('ZMR [TOKENS]: Failed to decode JSON string: $e');
            throw Exception('Invalid JSON format from Token Provider');
          }
        }
        
        if (data is! Map<String, dynamic>) {
          throw Exception('Token Provider returned ${data.runtimeType} instead of Map');
        }

        final newData = TokenPair.fromJson(data);
        
        // CRITICAL: Preserve dataSyncId and the session-linked visitorData
        // Overwriting visitorData during a session will cause 401/403 errors
        _tokens = TokenPair(
          visitorData: (_tokens?.dataSyncId != null) ? (_tokens?.visitorData ?? newData.visitorData) : newData.visitorData,
          poToken: newData.poToken,
          dataSyncId: _tokens?.dataSyncId,
        );
        
        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, jsonEncode(_tokens!.toJson()));
        
        debugPrint('ZMR [TOKENS]: Success - poToken and visitorData obtained and cached.');
        return _tokens!;
      } else {
        throw Exception('Failed to fetch tokens: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint('ZMR [TOKENS] Network Error: ${e.type} - ${e.message}');
        if (e.error != null) debugPrint('ZMR [TOKENS] Underlying Error: ${e.error}');
      } else {
        debugPrint('ZMR [TOKENS] Error: $e');
      }
      throw Exception('Token Provider Error: $e');
    }
  }

  /// Searches for music tracks and artists on YouTube using InnerTube.
  Future<SearchResponse> searchMusic(String query, {bool isRetry = false}) async {
    try {
      debugPrint('ZMR [SEARCH]: Searching for $query using InnerTube...');
      await getValidTokens(forceRefresh: isRetry);
      
      final response = await _innerTube.search(query: query);

      if (response.statusCode == 200) {
        return _parseSearch(response.data);
      } else if (!isRetry) {
        debugPrint('ZMR [SEARCH]: Status ${response.statusCode}, retrying with fresh tokens...');
        return searchMusic(query, isRetry: true);
      }
    } catch (e) {
      debugPrint('ZMR [SEARCH] Failed: $e');
      if (!isRetry) {
        debugPrint('ZMR [SEARCH]: Exception, retrying with fresh tokens...');
        return searchMusic(query, isRetry: true);
      }
    }
    return SearchResponse.empty();
  }

  /// Gets the DIRECT stream URL from YouTube using the hardcoded InnerTube extractor.
  Future<String> getDirectStreamUrl(String videoId, {bool isRetry = false}) async {
    try {
      final tokens = await getValidTokens(forceRefresh: isRetry);
      final url = await _extractor.getStreamUrl(videoId, tokens);
      if (url == null) {
        if (!isRetry) {
          debugPrint('ZMR [EXTRACTOR]: Extraction failed, retrying with fresh tokens...');
          return getDirectStreamUrl(videoId, isRetry: true);
        }
        throw Exception('Extraction failed for $videoId');
      }
      return url;
    } catch (e) {
      debugPrint('ZMR [EXTRACTOR] Error: $e');
      if (!isRetry) {
        debugPrint('ZMR [EXTRACTOR]: Exception, retrying with fresh tokens...');
        return getDirectStreamUrl(videoId, isRetry: true);
      }
      rethrow;
    }
  }

  /// Gets a direct Stream and the total size for downloading.
  Future<({Stream<List<int>> stream, int size})?> downloadStream(String videoId) async {
    try {
      final url = await getDirectStreamUrl(videoId);
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.stream),
      );
      
      return (
        stream: (response.data as ResponseBody).stream.map((b) => b.toList()),
        size: int.parse(response.headers.value('content-length') ?? '0')
      );
    } catch (e) {
      debugPrint('ZMR [DOWNLOAD] Error: $e');
      return null;
    }
  }

  /// Gets home feed sections and chips (Quick Picks, Recently Played, etc.)
  Future<HomeFeed> fetchHomeFeed({String? params}) async {
    try {
      await getValidTokens();
      final response = await _innerTube.browse(setLogin: true, params: params); 
      if (response.statusCode == 200) {
        return _parseHomeFeedResponse(response.data);
      }
    } catch (e) {
      debugPrint('ZMR [HOME FEED] Error: $e');
    }
    return HomeFeed.empty();
  }

  HomeFeed _parseHomeFeedResponse(dynamic data) {
    final sections = _parseHomeFeed(data);
    final chips = _parseHomeChips(data);
    return HomeFeed(chips: chips, sections: sections);
  }

  List<HomeChip> _parseHomeChips(dynamic data) {
    final List<HomeChip> chips = [];
    try {
      final chipContainers = _findAllElements(data, 'chipCloudChipRenderer');
      for (var chip in chipContainers) {
        try {
          chips.add(HomeChip.fromMap({'chipCloudChipRenderer': chip}));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('ZMR [CHIPS-PARSE] Error: $e');
    }
    return chips;
  }

  /// RESTORED: Gets trending songs using InnerTube browse.
  Future<List<Song>> getTrendingSongs({int retryCount = 0}) async {
    try {
      final browseIds = ["FEmusic_charts", "FEmusic_trending", "FEmusic_new_releases"];
      if (retryCount >= browseIds.length) return [];
      
      final browseId = browseIds[retryCount];
      final response = await _innerTube.browse(browseId: browseId);

      if (response.statusCode == 200) {
        final songs = _parseBrowseSongs(response.data);
        if (songs.isNotEmpty) return songs;
        return getTrendingSongs(retryCount: retryCount + 1);
      }
    } catch (e) {
      if (retryCount < 2) return getTrendingSongs(retryCount: retryCount + 1);
    }
    return [];
  }

  List<HomeSection> _parseHomeFeed(dynamic data) {
    final List<HomeSection> sections = [];
    try {
      // Find all types of shelves/grids/carousels
      final carouselShelves = _findAllElements(data, 'musicCarouselShelfRenderer');
      final basicShelves = _findAllElements(data, 'musicShelfRenderer');
      final gridShelves = _findAllElements(data, 'musicGridRenderer');
      final cardShelves = _findAllElements(data, 'musicCardShelfRenderer');
      
      final allShelves = [...carouselShelves, ...basicShelves, ...gridShelves, ...cardShelves];
      
      for (var shelf in allShelves) {
        // Try to get title from many possible header locations
        final titleNode = 
            shelf['header']?['musicCarouselShelfBasicHeaderRenderer']?['title'] ??
            shelf['header']?['musicResponsiveListItemFixedColumnRenderer']?['title'] ??
            shelf['header']?['musicShelfBasicHeaderRenderer']?['title'] ??
            shelf['header']?['musicHeaderRenderer']?['title'] ??
            shelf['title'];
        
        final title = _getText(titleNode);
        if (title.isEmpty || title == 'Unknown') continue;
        
        // Avoid duplicate sections (InnerTube sometimes returns same shelf in different containers)
        if (sections.any((s) => s.title == title)) continue;

        final List<dynamic> items = [];
        // Support both 'contents' (carousel/shelf) and 'items' (grid/card)
        final shelfItems = (shelf['contents'] ?? shelf['items']) as List?;
        
        if (shelfItems != null) {
          for (var item in shelfItems) {
            if (item is! Map) continue;
            
            // Extract the actual renderer (sometimes nested)
            final renderer = item['musicTwoRowItemRenderer'] ?? 
                            item['musicResponsiveListItemRenderer'] ?? 
                            item['musicMultiRowListItemRenderer'] ??
                            item['musicNavigationButtonRenderer'] ??
                            item['musicItemThumbnailOverlayRenderer'];
                            
            if (renderer != null) {
               dynamic parsed;
               if (item.containsKey('musicTwoRowItemRenderer')) {
                 parsed = _parseTwoRowItem(renderer);
               } else if (item.containsKey('musicResponsiveListItemRenderer')) {
                 parsed = _parseResponsiveListItem(renderer);
               } else if (item.containsKey('musicMultiRowListItemRenderer')) {
                 parsed = _parseResponsiveListItem(renderer);
               }
               
               if (parsed != null) items.add(parsed);
            } else {
              // Try parsing the item directly if it's already a renderer
              final directParsed = _parseTwoRowItem(item) ?? _parseResponsiveListItem(item);
              if (directParsed != null) items.add(directParsed);
            }
          }
        }
        
        if (items.isNotEmpty) {
          debugPrint('ZMR [HOME-PARSE]: Found section "$title" with ${items.length} items');
          sections.add(HomeSection(
            title: title,
            items: items,
            type: SectionType.carousel,
          ));
        }
      }
    } catch (e) {
      debugPrint('ZMR [HOME-PARSE] Error: $e');
    }
    debugPrint('ZMR [HOME-PARSE]: Total sections found: ${sections.length}');
    return sections;
  }

  dynamic _parseTwoRowItem(dynamic renderer) {
    try {
      final nav = renderer['navigationEndpoint'] ?? 
                 renderer['title']?['runs']?[0]?['navigationEndpoint'];
      
      final title = _getText(renderer['title']);
      final thumbnails = _getThumbnails(renderer);
      final thumbUrl = thumbnails.isNotEmpty ? thumbnails.last : '';

      // Song/Video
      if (nav != null && nav['watchEndpoint'] != null) {
        final id = nav['watchEndpoint']['videoId'];
        final subtitle = _getText(renderer['subtitle']);
        return Song(id: id, title: title, artist: subtitle, duration: '', thumbnailUrl: thumbUrl);
      }
      
      // Secondary check for watchEndpoint in thumbnail overlay
      final overlayWatch = renderer['thumbnailOverlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint'];
      if (overlayWatch != null) {
        final id = overlayWatch['videoId'];
        final subtitle = _getText(renderer['subtitle']);
        
        // Try to get artistId from subtitle runs
        String? artistId;
        final runs = _findAllElements(renderer['subtitle'], 'runs');
        if (runs.isNotEmpty && runs[0] is List) {
          final artistRun = (runs[0] as List).firstWhere(
            (r) => r['navigationEndpoint']?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType'] == 'MUSIC_PAGE_TYPE_ARTIST',
            orElse: () => null
          );
          if (artistRun != null) {
            artistId = artistRun['navigationEndpoint']?['browseEndpoint']?['browseId'];
          }
        }
        
        return Song(id: id, title: title, artist: subtitle, artistId: artistId, duration: '', thumbnailUrl: thumbUrl);
      }

      // Playlist
      final isPlaylist = nav != null && 
          nav['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType'] == 'MUSIC_PAGE_TYPE_PLAYLIST';
          
      if (isPlaylist) {
        final id = nav['browseEndpoint']['browseId'];
        final songCount = _extractSongCount(renderer);
        return ZmrPlaylist(id: id, title: title, thumbnailUrl: thumbUrl, songCount: songCount);
      }

      // Artist
      final isArtist = nav != null && 
          nav['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType'] == 'MUSIC_PAGE_TYPE_ARTIST';

      if (isArtist) {
        final id = nav['browseEndpoint']['browseId'];
        return Artist(id: id, name: title, thumbnailUrl: thumbUrl);
      }
    } catch (_) {}
    return null;
  }

  dynamic _parseResponsiveListItem(dynamic renderer) {
    try {
      final flexCols = renderer['flexColumns'] as List?;
      if (flexCols == null || flexCols.isEmpty) return null;

      final title = _getText(flexCols[0]);
      final thumbnails = _getThumbnails(renderer);
      final thumbUrl = thumbnails.isNotEmpty ? thumbnails.last : '';

      final nav = renderer['navigationEndpoint'];
      final watch = nav?['watchEndpoint'] ?? 
                    renderer['playlistItemData'] ?? // Quick picks sometimes use this
                    renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint'];

      if (watch != null) {
        final id = watch['videoId'];
        if (id == null) return null;
        
        String artist = 'Unknown Artist';
        String? artistId;
        if (flexCols.length > 1) {
          final subtitleNode = flexCols[1];
          artist = _getText(subtitleNode);
          
          // Try to extract specific artist if buried in runs
          final runs = _findAllElements(subtitleNode, 'runs');
          if (runs.isNotEmpty && runs[0] is List) {
             final artistRun = (runs[0] as List).firstWhere(
               (r) => r['navigationEndpoint']?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType'] == 'MUSIC_PAGE_TYPE_ARTIST',
               orElse: () => null
             );
             if (artistRun != null) {
               artist = artistRun['text'];
               artistId = artistRun['navigationEndpoint']?['browseEndpoint']?['browseId'];
             }
          }
        }
        
        return Song(id: id, title: title, artist: artist, artistId: artistId, duration: '', thumbnailUrl: thumbUrl);
      }
      
      // Handle Playlists/Albums in responsive lists (less common in home, but possible)
      final browse = nav?['browseEndpoint'];
      if (browse != null) {
        final id = browse['browseId'];
        final pageType = browse['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType'];
        
        if (pageType == 'MUSIC_PAGE_TYPE_PLAYLIST' || pageType == 'MUSIC_PAGE_TYPE_ALBUM') {
          return ZmrPlaylist(id: id, title: title, thumbnailUrl: thumbUrl, songCount: 0);
        } else if (pageType == 'MUSIC_PAGE_TYPE_ARTIST') {
          return Artist(id: id, name: title, thumbnailUrl: thumbUrl);
        }
      }
    } catch (_) {}
    return null;
  }


  Future<List<Song>> fetchLikedSongs({bool isRetry = false}) async {
    if (_cookies == null) return [];
    final List<Song> allSongs = [];
    try {
      await getValidTokens(forceRefresh: isRetry);
      var response = await _innerTube.browse(browseId: "VLLM", setLogin: true);

      if (response.statusCode == 200) {
        allSongs.addAll(_parseBrowseSongs(response.data));
        
        // Handle continuations to get more than ~25 songs
        String? continuation = _extractContinuation(response.data);
        debugPrint('ZMR [LIKED]: Initial batch fetched ${allSongs.length} songs. Continuation: ${continuation != null}');
        while (continuation != null && allSongs.length < 5000) {
          debugPrint('ZMR [LIKED]: Fetching continuation (current total: ${allSongs.length})...');
          response = await _innerTube.browse(continuation: continuation, setLogin: true);
          if (response.statusCode == 200) {
            final nextSongs = _parseBrowseSongs(response.data);
            if (nextSongs.isEmpty) {
              debugPrint('ZMR [LIKED]: Continuation returned no songs. Stopping.');
              break;
            }
            allSongs.addAll(nextSongs);
            continuation = _extractContinuation(response.data);
            debugPrint('ZMR [LIKED]: Fetched ${nextSongs.length} more. Total: ${allSongs.length}. Next continuation: ${continuation != null}');
          } else {
            debugPrint('ZMR [LIKED]: Continuation request failed with status ${response.statusCode}');
            break;
          }
        }
        debugPrint('ZMR [LIKED]: Final total fetched: ${allSongs.length}');
        return allSongs;
      }
    } catch (e) {
      debugPrint('ZMR [LIKED] Error: $e');
      if (e.toString().contains('AUTH_ERROR')) {
        debugPrint('ZMR [AUTH]: Cookies expired or invalid. Clearing...');
        throw Exception('AUTH_ERROR');
      }
      if (!isRetry) return fetchLikedSongs(isRetry: true);
    }
    return allSongs;
  }

  Future<List<ZmrPlaylist>> fetchPlaylists({bool isRetry = false}) async {
    if (_cookies == null) return [];
    try {
      await getValidTokens(forceRefresh: isRetry);
      final response = await _innerTube.browse(browseId: "FEmusic_liked_playlists", setLogin: true);

      if (response.statusCode == 200) {
        return _parseBrowsePlaylists(response.data);
      } else if (!isRetry) {
        debugPrint('ZMR [PLAYLISTS]: Status ${response.statusCode}, retrying with fresh tokens...');
        return fetchPlaylists(isRetry: true);
      }
    } catch (e) {
      debugPrint('ZMR [PL Discovery]: Playlists failed: $e');
      if (!isRetry) {
        debugPrint('ZMR [PLAYLISTS]: Exception, retrying with fresh tokens...');
        return fetchPlaylists(isRetry: true);
      }
    }
    return [];
  }

  Future<List<Song>> fetchPlaylistSongs(String playlistId, {bool isRetry = false}) async {
    final List<Song> allSongs = [];
    try {
      await getValidTokens(forceRefresh: isRetry);
      
      String actualBrowseId = playlistId;
      if (playlistId == 'LM' || playlistId == 'FEmusic_liked_songs') {
        actualBrowseId = 'VLLM';
      } else if (playlistId.startsWith('PL')) {
        actualBrowseId = 'VL$playlistId';
      }

      debugPrint('ZMR [PL]: Fetching songs for $actualBrowseId...');
      var response = await _innerTube.browse(browseId: actualBrowseId, setLogin: true);
      
      if (response.statusCode == 200) {
        // 1. Identify the primary playlist shelf to avoid "Suggestions"
        final playlistShelf = _findAllElements(response.data, 'musicPlaylistShelfRenderer').firstOrNull;
        final container = playlistShelf ?? response.data;

        final initialSongs = _parseBrowseSongs(container);
        allSongs.addAll(initialSongs);
        
        // 2. ONLY extract continuation from the playlist shelf itself
        String? continuation = _extractContinuation(container);
        debugPrint('ZMR [PL]: Initial batch fetched ${allSongs.length} songs. Continuation: ${continuation != null}');
        
        while (continuation != null && allSongs.length < 5000) {
          debugPrint('ZMR [PL]: Fetching continuation (current total: ${allSongs.length})...');
          response = await _innerTube.browse(continuation: continuation, setLogin: true);
          if (response.statusCode == 200) {
            // Continuations usually return a continuationItemListRenderer or similar
            final nextSongs = _parseBrowseSongs(response.data);
            if (nextSongs.isEmpty) {
              debugPrint('ZMR [PL]: Continuation returned no songs. Stopping.');
              break;
            }
            allSongs.addAll(nextSongs);
            continuation = _extractContinuation(response.data);
            debugPrint('ZMR [PL]: Fetched ${nextSongs.length} more. Total: ${allSongs.length}. Next continuation: ${continuation != null}');
          } else {
            debugPrint('ZMR [PL]: Continuation request failed with status ${response.statusCode}');
            break;
          }
        }
        debugPrint('ZMR [PL]: Final total fetched: ${allSongs.length}');
        return allSongs;
      }
    } catch (e) {
      debugPrint('ZMR [PL Songs] failed: $e');
      if (e.toString().contains('AUTH_ERROR')) throw Exception('AUTH_ERROR');
      if (!isRetry) return fetchPlaylistSongs(playlistId, isRetry: true);
    }
    return allSongs;
  }

  SearchResponse _parseSearch(dynamic data) {
    final List<Song> songs = [];
    final List<Artist> artists = [];
    try {
      final items = _findAllElements(data, 'musicResponsiveListItemRenderer');
      for (var item in items) {
        final parsed = _parseResponsiveListItem(item);
        if (parsed == null) continue;

        if (parsed is Song) {
          if (!songs.any((s) => s.id == parsed.id)) {
            songs.add(parsed);
          }
        } else if (parsed is Artist) {
          if (!artists.any((a) => a.id == parsed.id)) {
            artists.add(parsed);
          }
        }
      }
    } catch (e) {
      debugPrint('ZMR [SEARCH-PARSE] Error: $e');
    }
    return SearchResponse(songs: songs, artists: artists);
  }

  List<Song> _parseBrowseSongs(dynamic data) {
    final List<Song> songs = [];
    try {
      final responsiveItems = _findAllElements(data, 'musicResponsiveListItemRenderer');
      final listItems = _findAllElements(data, 'musicListItemRenderer');
      final twoRowItems = _findAllElements(data, 'musicTwoRowItemRenderer');
      final playlistPanelItems = _findAllElements(data, 'playlistPanelVideoRenderer');
      
      final allItems = [...responsiveItems, ...listItems, ...playlistPanelItems];
      
      for (var item in allItems) {
        final allVideoIds = _findAllElements(item, 'videoId');
        if (allVideoIds.isEmpty) continue;
        final id = allVideoIds[0].toString();
        
        // flexColumns for responsive, or just title/subtitle for listItem
        String title = 'Unknown Song';
        String artist = 'Unknown Artist';
        
        if (item.containsKey('flexColumns')) {
          final flexCols = item['flexColumns'] as List?;
          if (flexCols != null && flexCols.isNotEmpty) {
            title = _getText(flexCols[0]);
            if (flexCols.length > 1) {
              artist = _getText(flexCols[1]);
            }
          }
        } else {
          title = _getText(item['title']);
          artist = _getText(item['subtitle'] ?? item['artistName'] ?? item['longBylineText'] ?? item['shortBylineText']);
        }
        
        final thumbnails = _getThumbnails(item);
        final thumbUrl = thumbnails.isNotEmpty ? thumbnails.last : '';

        // Try to get artistId from runs
        String? artistId;
        dynamic runsNode;
        if (item.containsKey('flexColumns')) {
          final flexCols = item['flexColumns'] as List?;
          if (flexCols != null && flexCols.length > 1) {
            runsNode = flexCols[1];
          }
        } else {
          runsNode = item['subtitle'] ?? item['artistName'] ?? item['longBylineText'] ?? item['shortBylineText'];
        }
        if (runsNode != null) {
          final runs = _findAllElements(runsNode, 'runs');
          if (runs.isNotEmpty && runs[0] is List) {
            final artistRun = (runs[0] as List).firstWhere(
              (r) => r['navigationEndpoint']?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType'] == 'MUSIC_PAGE_TYPE_ARTIST',
              orElse: () => null
            );
            if (artistRun != null) {
              artistId = artistRun['navigationEndpoint']?['browseEndpoint']?['browseId'];
            }
          }
        }

        if (songs.any((s) => s.id == id)) continue;
        songs.add(Song(id: id, title: title, artist: artist, artistId: artistId, duration: '', thumbnailUrl: thumbUrl));
      }

      if (songs.length < 10) { 
        for (var item in twoRowItems) {
          final allVideoIds = _findAllElements(item, 'videoId');
          if (allVideoIds.isEmpty) continue;
          final id = allVideoIds[0].toString();

          final title = _getText(item['title']);
          final artist = _getText(item['subtitle'] ?? item['artistName']);
          final thumbnails = _getThumbnails(item);
          final thumbUrl = thumbnails.isNotEmpty ? thumbnails.last : '';

          if (songs.any((s) => s.id == id)) continue;
          songs.add(Song(id: id, title: title, artist: artist, duration: '', thumbnailUrl: thumbUrl));
        }
      }
      
      debugPrint('ZMR [PARSE]: Extracted ${songs.length} items.');
    } catch (e) {
      debugPrint('ZMR [PARSE] Error: $e');
    }
    return songs;
  }


  // Helper to extract text from deeply nested runs
  String _getText(dynamic node) {
    if (node == null) return 'Unknown';
    try {
      // 1. Check for explicit text field
      if (node is Map && node.containsKey('text') && node['text'] is String) {
        return node['text'];
      }
      
      // 2. Find all 'text' keys inside the node's runs
      // This is the most common InnerTube pattern
      final runs = _findAllElements(node, 'runs');
      if (runs.isNotEmpty) {
        for (var runList in runs) {
          if (runList is List && runList.isNotEmpty) {
            final text = runList[0]['text'];
            if (text != null && text.toString().isNotEmpty) return text.toString();
          }
        }
      }
      
      // 3. Fallback to direct text if available
      final directText = node['text']?['runs']?[0]?['text'] ?? node['simpleText'];
      if (directText != null) return directText.toString();
      
    } catch (_) {}
    return 'Unknown';
  }

  // Helper to extract thumbnails with high-resolution support
  List<String> _getThumbnails(dynamic node) {
    if (node == null) return [];
    try {
      // 1. Direct path search (faster and more accurate)
      dynamic thumbData = node['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                         node['thumbnail']?['thumbnails'] ??
                         node['thumbnails'];
      
      if (thumbData is! List) {
        // 2. Fallback to deep search if direct path fails
        final List<dynamic> deepResults = _findAllElements(node, 'thumbnails');
        for (var result in deepResults) {
          if (result is List && result.isNotEmpty) {
            thumbData = result;
            break;
          }
        }
      }

      if (thumbData is List && thumbData.isNotEmpty) {
        return thumbData.map((t) {
          String url = t['url'].toString();
          
          // Ensure https prefix
          if (url.startsWith('//')) url = 'https:$url';
          
          // Boost resolution if it's a standard YTM thumbnail pattern
          // e.g. =w120-h120-l90-rj -> =w544-h544-l90-rj
          if (url.contains('=w') && url.contains('-h')) {
            url = url.replaceAll(RegExp(r'=w\d+-h\d+'), '=w544-h544');
          } else if (url.contains('s90') || url.contains('s120')) {
            // Replace s90-c with s512-c for better quality
            url = url.replaceAll(RegExp(r's\d+-c'), 's512-c');
          }
          
          return url;
        }).toList();
      }
    } catch (e) {
      debugPrint('ZMR [THUMB-PARSE] Warning: $e');
    }
    return [];
  }

  List<ZmrPlaylist> _parseBrowsePlaylists(dynamic data) {
    final List<ZmrPlaylist> playlists = [];
    try {
      final items = _findAllElements(data, 'musicTwoRowItemRenderer');
      for (var item in items) {
        final id = item['navigationEndpoint']?['browseEndpoint']?['browseId'];
        if (id == null) continue;
        
        final title = _getText(item['title']);
        final thumbnails = _getThumbnails(item);
        final thumbUrl = thumbnails.isNotEmpty ? thumbnails.last : '';
        final songCount = _extractSongCount(item);

        playlists.add(ZmrPlaylist(id: id, title: title, thumbnailUrl: thumbUrl, songCount: songCount));
      }
    } catch (_) {}
    return playlists;
  }

  int _extractSongCount(dynamic renderer) {
    try {
      // Check both subtitle and secondSubtitle fields
      final fields = [renderer['subtitle'], renderer['secondSubtitle']];
      for (var field in fields) {
        if (field == null) continue;
        final runs = _findAllElements(field, 'runs');
        for (var runList in runs) {
          if (runList is List) {
            for (var run in runList) {
              final text = run['text']?.toString() ?? '';
              // Match digits followed by common music-related terms
              final match = RegExp(r'([\d,]+)\s+(songs|tracks|items|videos)').firstMatch(text);
              if (match != null) {
                return int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
              }
            }
          }
        }
      }
    } catch (_) {}
    return 0;
  }

  String? _extractContinuation(dynamic data) {
    try {
      // 1. First search for standard continuation markers
      final tokenKeys = ['continuation', 'token', 'nextContinuationToken'];
      final containerKeys = ['nextContinuationData', 'reloadContinuationData', 'continuationItemRenderer'];
      
      // Look into containers first
      for (var container in containerKeys) {
        final found = _findAllElements(data, container);
        for (var item in found) {
          if (item is Map) {
            for (var tk in tokenKeys) {
              if (item.containsKey(tk) && item[tk] is String && item[tk].length > 30) {
                return item[tk];
              }
            }
          }
        }
      }

      // 2. Look for it as a direct key anywhere
      for (var tk in tokenKeys) {
        final found = _findAllElements(data, tk);
        for (var t in found) {
          if (t is String && t.length > 50) return t;
        }
      }

      // 3. Special case for continuationEndpoint
      final endpoints = _findAllElements(data, 'continuationEndpoint');
      for (var ep in endpoints) {
        final command = ep['continuationCommand'] ?? ep['browseContinuationEndpoint'];
        if (command != null && command['token'] != null && command['token'] is String) {
          return command['token'];
        }
      }
    } catch (_) {}
    return null;
  }

  List<dynamic> _findAllElements(dynamic json, String targetKey) {
    final List<dynamic> results = [];
    void search(dynamic node) {
      if (node == null) return;
      if (node is List) {
        for (var e in node) {
          search(e);
        }
      } else if (node is Map) {
        if (node.containsKey(targetKey)) {
          results.add(node[targetKey]);
        }
        node.forEach((k, v) => search(v));
      }
    }
    search(json);
    return results;
  }

  // --- New Methods Implementation ---

  Future<void> likeSong(String videoId) async {
    await getValidTokens();
    await _innerTube.like(videoId);
  }

  Future<void> unlikeSong(String videoId) async {
    await getValidTokens();
    await _innerTube.unlike(videoId);
  }

  Future<void> subscribeToArtist(String channelId) async {
    await getValidTokens();
    await _innerTube.subscribe(channelId);
  }

  Future<void> unsubscribeFromArtist(String channelId) async {
    await getValidTokens();
    await _innerTube.unsubscribe(channelId);
  }

  Future<List<Artist>> fetchSubscribedArtists({bool isRetry = false}) async {
    if (_cookies == null) return [];
    try {
      await getValidTokens(forceRefresh: isRetry);
      final responses = await Future.wait([
        _innerTube.browse(browseId: "FEmusic_library_corpus_track_artists", setLogin: true),
        _innerTube.browse(browseId: "FEmusic_library_corpus_artists", setLogin: true)
      ]);

      final List<Artist> allArtists = [];

      for (var response in responses) {
        if (response.statusCode == 200) {
          final items = _findAllElements(response.data, 'musicResponsiveListItemRenderer');
          for (var item in items) {
            final allBrowseIds = _findAllElements(item, 'browseId');
            if (allBrowseIds.isEmpty) continue;
            final id = allBrowseIds.first.toString();
            if (!id.startsWith('UC')) continue; // Ensure it's an artist channel
            
            String name = 'Unknown Artist';
            if (item.containsKey('flexColumns')) {
              final flexCols = item['flexColumns'] as List?;
              if (flexCols != null && flexCols.isNotEmpty) {
                name = _getText(flexCols[0]);
              }
            } else {
              name = _getText(item['title']); // fallback
            }
            final thumbnails = _getThumbnails(item);
            final thumbUrl = thumbnails.isNotEmpty ? thumbnails.last : '';
            
            if (!allArtists.any((a) => a.id == id)) {
              allArtists.add(Artist(id: id, name: name, thumbnailUrl: thumbUrl));
            }
          }
        }
      }
      return allArtists;
    } catch (e) {
      if (!isRetry) return fetchSubscribedArtists(isRetry: true);
    }
    return [];
  }

  Future<ArtistDetails> fetchArtistDetails(String artistId) async {
    final List<Song> popularSongs = [];
    final List<ArtistSection> sections = [];
    
    try {
      await getValidTokens();
      final response = await _innerTube.browse(browseId: artistId);
      if (response.statusCode == 200) {
        final data = response.data;
        
        // 1. Find Popular Songs (usually in a musicShelfRenderer)
        final shelves = _findAllElements(data, 'musicShelfRenderer');
        for (var shelf in shelves) {
          final title = _getText(shelf['title']);
          if (title.toLowerCase().contains('song') || title.toLowerCase().contains('track')) {
            popularSongs.addAll(_parseBrowseSongs(shelf));
            
            // Try to fetch EVEN MORE songs if a "See all" endpoint exists
            try {
               final bottomEndpoint = shelf['bottomEndpoint'] ?? 
                                    shelf['title']?['runs']?[0]?['navigationEndpoint'];
               final browseEndpoint = bottomEndpoint?['browseEndpoint'];
               final seeAllBrowseId = browseEndpoint?['browseId'];
               final seeAllParams = browseEndpoint?['params'];
               
               if (seeAllBrowseId != null) {
                 final moreSongsResponse = await _innerTube.browse(
                   browseId: seeAllBrowseId, 
                   params: seeAllParams,
                   setLogin: true,
                 );
                 if (moreSongsResponse.statusCode == 200) {
                   final moreSongs = _parseBrowseSongs(moreSongsResponse.data);
                   for (var s in moreSongs) {
                     if (!popularSongs.any((ps) => ps.id == s.id)) popularSongs.add(s);
                   }
                 }
               }
            } catch (e) {
               debugPrint('ZMR [Artist] Failed to fetch extended songs: $e');
            }
            break; 
          }
        }
        
        // 2. Find Other Sections (Albums, Singles, etc.)
        final carousels = _findAllElements(data, 'musicCarouselShelfRenderer');
        for (var carousel in carousels) {
          final titleNode = carousel['header']?['musicCarouselShelfBasicHeaderRenderer']?['title'];
          final title = _getText(titleNode);
          
          final items = _parseBrowseSongs(carousel);
          if (items.isNotEmpty) {
            // If we found a section explicitly called "Songs" but popularSongs was small, use it
            if (popularSongs.length < 5 && (title.toLowerCase().contains('song') || title.toLowerCase().contains('track'))) {
              for (var s in items) {
                if (!popularSongs.any((ps) => ps.id == s.id)) popularSongs.add(s);
              }
            } else {
              sections.add(ArtistSection(title: title, items: items));
            }
          }
        }
        
        // Fallback if popularSongs is empty
        if (popularSongs.isEmpty && sections.isNotEmpty) {
          popularSongs.addAll(sections.first.items);
        }
      }
    } catch (e) {
      debugPrint('ZMR [ArtistDetails] error: $e');
    }
    
    return ArtistDetails(popularSongs: popularSongs, sections: sections);
  }

  Future<List<Song>> fetchArtistNewReleases(String artistId) async {

    try {
      await getValidTokens();
      final response = await _innerTube.browse(browseId: artistId);
      if (response.statusCode == 200) {
        // Find New Releases carousel or just first songs section
        final carousels = _findAllElements(response.data, 'musicCarouselShelfRenderer');
        for (var carousel in carousels) {
          final headerText = _getText(carousel['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']);
          if (headerText.toLowerCase().contains('release') || headerText.toLowerCase().contains('album') || headerText.toLowerCase().contains('song')) {
            return _parseBrowseSongs(carousel);
          }
        }
        // Fallback to all parsed songs if no explicit section
        return _parseBrowseSongs(response.data).take(10).toList();
      }
    } catch (e) {
      debugPrint('ZMR [Artist] error: $e');
    }
    return [];
  }

  Future<void> removeFromPlaylist(String playlistId, String videoId, String setVideoId) async {
    await getValidTokens();
    await _innerTube.editPlaylist(playlistId, [
      {
        'action': 'ACTION_REMOVE_VIDEO',
        'removedVideoId': videoId,
        'setVideoId': setVideoId,
      }
    ]);
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final response = await _innerTube.getSearchSuggestions(query);
      if (response.statusCode == 200) {
        final List<dynamic> suggestions = _findAllElements(response.data, 'searchSuggestionRenderer');
        return suggestions.map((s) => _getText(s['suggestion'])).toList();
      }
    } catch (e) {
      debugPrint('ZMR [SUGGESTIONS] Error: $e');
    }
    return [];
  }


  Future<List<Song>> getQueue({List<String>? videoIds, String? playlistId}) async {
    try {
      await getValidTokens();
      final response = await _innerTube.getQueue(videoIds: videoIds, playlistId: playlistId);
      if (response.statusCode == 200) {
        return _parseBrowseSongs(response.data);
      }
    } catch (e) {
      debugPrint('ZMR [QUEUE] Error: $e');
    }
    return [];
  }

  Future<List<Song>> fetchRadioSongs(String videoId) async {
    debugPrint('ZMR [RADIO]: Starting fetch for $videoId...');
    try {
      await getValidTokens();
      
      // YouTube Music Radio uses 'RDAMVM' + videoId as a virtual playlist container for recommendations
      final radioPlaylistId = 'RDAMVM$videoId';
      debugPrint('ZMR [RADIO]: Requesting RD playlist $radioPlaylistId...');
      final response = await _innerTube.next(videoId: videoId, playlistId: radioPlaylistId);
      
      if (response.statusCode == 200) {
        final songs = _parseBrowseSongs(response.data);
        if (songs.isNotEmpty) {
          debugPrint('ZMR [RADIO]: Successfully fetched ${songs.length} songs from RD playlist.');
          return songs;
        } else {
          debugPrint('ZMR [RADIO]: RD playlist result empty.');
        }
      } else {
        debugPrint('ZMR [RADIO]: RD response status ${response.statusCode}');
      }
      
      // Fallback: standard watch-next data structure
      debugPrint('ZMR [RADIO]: Falling back to standard next for $videoId...');
      final fallbackResponse = await _innerTube.next(videoId: videoId);
      if (fallbackResponse.statusCode == 200) {
        final fallbackSongs = _parseBrowseSongs(fallbackResponse.data);
        debugPrint('ZMR [RADIO]: Fallback fetched ${fallbackSongs.length} songs.');
        return fallbackSongs;
      } else {
        debugPrint('ZMR [RADIO]: Fallback response status ${fallbackResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('ZMR [RADIO] Error: $e');
    }
    return [];
  }

  void updateCookies(String? cookies) {
    if (cookies == null || cookies.isEmpty) {
      _cookies = null;
      return;
    }
    
    if (cookies.contains('# Netscape HTTP Cookie File')) {
      final lines = cookies.split('\n');
      final Map<String, String> cookieMap = {};
      
      for (var line in lines) {
        if (line.trim().isEmpty || line.startsWith('#')) continue;
        final parts = line.split('\t');
        if (parts.length >= 7) {
          cookieMap[parts[5]] = parts[6];
        }
      }
      
      if (cookieMap.isNotEmpty) {
        _cookies = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
      } else {
        _cookies = null;
      }
    } else {
      // Aggressively remove all whitespace (newlines, tabs, spaces) 
      // Most YouTube cookies are alphanumeric/symbols and shouldn't contain spaces.
      // Spaces often appear due to UI word-wrapping or bad copy-pasting.
      _cookies = cookies.replaceAll(RegExp(r'\s+'), '').trim();
    }
    
    if (_cookies != null && _cookies!.isNotEmpty) {
      _innerTube.updateCookies(_cookies);
      
      // Sanitized log for debugging
      final keys = _cookies!.split(';').map((e) => e.split('=')[0].trim()).join(', ');
      debugPrint('ZMR AUTH: Cookies Processed. Keys found: $keys');
    }
  }

  /// Verifies if the current cookies are valid by attempting to fetch the library.
  Future<bool> testAuth() async {
    if (_cookies == null || _cookies!.isEmpty) return false;
    try {
      final response = await _innerTube.browse(browseId: 'FEmusic_library_corpus');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ZMR AUTH: Test failed: $e');
      return false;
    }
  }

  void dispose() {
    _extractor.dispose();
  }

  /// Likes a video/song on YouTube
  Future<void> likeVideo(String videoId) async {
    try {
      await getValidTokens();
      final response = await _innerTube.like(videoId);
      if (response.statusCode != 200) {
        throw Exception('Failed to like video: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ZMR [LIKE] Error: $e');
      rethrow;
    }
  }

  /// Removes a like from a video/song on YouTube
  Future<void> unlikeVideo(String videoId) async {
    try {
      await getValidTokens();
      final response = await _innerTube.unlike(videoId);
      if (response.statusCode != 200) {
        throw Exception('Failed to unlike video: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ZMR [UNLIKE] Error: $e');
      rethrow;
    }
  }

  /// Adds a song to a playlist
  Future<void> addToPlaylist(String playlistId, String videoId) async {
    try {
      await getValidTokens();
      
      // Strip 'VL' prefix for edit actions if present (YTM lists use VL prefix for browse, but not for edits)
      final cleanPlaylistId = playlistId.startsWith('VL') ? playlistId.substring(2) : playlistId;
      
      final response = await _innerTube.editPlaylist(cleanPlaylistId, [
        {
          'action': 'ACTION_ADD_VIDEO',
          'addedVideoId': videoId,
        }
      ]);
      if (response.statusCode != 200) {
        throw Exception('Failed to add to playlist: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ZMR [ADD_TO_PLAYLIST] Error: $e');
      rethrow;
    }
  }

  /// Creates a new playlist
  Future<String?> createPlaylist(String title, {String? videoId}) async {
    try {
      await getValidTokens();
      // Step 1: Create an EMPTY playlist (Prevents YouTube from auto-filling with suggested tracks)
      final createResponse = await _innerTube.createPlaylist(title);
      
      if (createResponse.statusCode == 200) {
        final playlistId = createResponse.data['playlistId'];
        if (playlistId == null) return null;

        // Step 2: Add our specific song manually
        if (videoId != null) {
          await _innerTube.editPlaylist(playlistId, [
            {
              'action': 'ACTION_ADD_VIDEO',
              'addedVideoId': videoId,
            }
          ]);
        }
        
        return playlistId;
      }
    } catch (e) {
      debugPrint('ZMR [CREATE_PLAYLIST] Error: $e');
      rethrow;
    }
    return null;
  }

  /// Deletes a playlist on YouTube
  Future<void> deletePlaylist(String playlistId) async {
    try {
      await getValidTokens();
      final response = await _innerTube.deletePlaylist(playlistId);
      if (response.statusCode != 200) {
        throw Exception('Failed to delete playlist: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ZMR [DELETE_PLAYLIST] Error: $e');
      rethrow;
    }
  }

  /// Changes the title of a playlist
  Future<void> renamePlaylist(String playlistId, String newTitle) async {
    try {
      await getValidTokens();
      final response = await _innerTube.editPlaylist(playlistId, [
        {
          'action': 'ACTION_SET_PLAYLIST_NAME',
          'playlistName': newTitle,
        }
      ]);
      if (response.statusCode != 200) {
        throw Exception('Failed to rename playlist: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ZMR [RENAME_PLAYLIST] Error: $e');
      rethrow;
    }
  }

  /// Fetches lyrics (timed if available, otherwise static)
  Future<LyricsData?> fetchLyrics(String videoId, {Song? song}) async {
    // 1. Try timed lyrics (Transcript) first
    try {
      final transcriptResponse = await _innerTube.getTranscript(videoId);
      if (transcriptResponse.statusCode == 200) {
        final actions = transcriptResponse.data['actions'];
        if (actions != null && actions.isNotEmpty) {
          final content = actions[0]['updateTranscriptAction']?['content'];
          final body = content?['transcriptRenderer']?['body']?['transcriptBodyRenderer'];
          final cues = body?['cueGroups'];
          
          if (cues != null) {
            final List<LyricsLine> lines = [];
            for (var cueGroup in cues) {
              final cue = cueGroup['transcriptCueGroupRenderer']?['cues']?[0]?['transcriptCueRenderer'];
              if (cue != null) {
                final text = _getText(cue['label']);
                final startMs = int.tryParse(cue['startOffsetMs'] ?? '0') ?? 0;
                lines.add(LyricsLine(timestamp: Duration(milliseconds: startMs), text: text));
              }
            }
            if (lines.isNotEmpty) {
              debugPrint('ZMR [LYRICS]: Success with timed lyrics');
              return LyricsData(lines: lines);
            }
          }
        }
      }
    } catch (e) {
      // Log timed lyrics failure and continue to fallback
      debugPrint('ZMR [LYRICS-TIMED] Error (proceeding to fallback): $e');
    }

    // 2. Fallback to browse-based static lyrics
    try {
      final nextResponse = await _innerTube.next(videoId: videoId, setLogin: true);
      
      // Attempt to find static lyrics directly in the next response shelf
      final directStatic = _parseStaticLyrics(nextResponse.data);
      if (directStatic != null) {
        debugPrint('ZMR [LYRICS-STATIC]: Found lyrics directly in next response');
        final lines = directStatic.split('\n').map((l) => LyricsLine(timestamp: Duration.zero, text: l)).toList();
        return LyricsData(lines: lines, source: 'YouTube Music');
      }

      String? browseId = _findLyricsBrowseId(nextResponse.data);
      
      // Deep fallback: search for anything starting with FEmusic_lyrics if tab search failed
      if (browseId == null) {
        final allLyricsIds = _findAllBrowseIds(nextResponse.data, 'FEmusic_lyrics');
        if (allLyricsIds.isNotEmpty) {
          browseId = allLyricsIds.first;
          debugPrint('ZMR [LYRICS-STATIC]: Found browseId via deep search: $browseId');
        }
      }

      if (browseId != null) {
        final lyricsBrowse = await _innerTube.browse(browseId: browseId, setLogin: true);
        final lyricsText = _parseStaticLyrics(lyricsBrowse.data);
        if (lyricsText != null) {
          final lines = lyricsText.split('\n').map((l) => LyricsLine(timestamp: Duration.zero, text: l)).toList();
          debugPrint('ZMR [LYRICS]: Success with static lyrics');
          return LyricsData(lines: lines, source: 'YouTube Music');
        }
      } 
      
      // ULTRA Fallback: search for any text block with many newlines in it (likely lyrics)
      final allFuzzyStrings = _findAllStrings(nextResponse.data, (s) => s.contains('\n') && s.length > 200);
      if (allFuzzyStrings.isNotEmpty) {
          debugPrint('ZMR [LYRICS-FUZZY]: Found text block via heuristic');
          final lines = allFuzzyStrings.first.split('\n').map((l) => LyricsLine(timestamp: Duration.zero, text: l)).toList();
          return LyricsData(lines: lines, source: 'YouTube Music (Auto)');
      }

      // NUCLEAR FALLBACK: Search for lyrics explicitly
      final songTitle = song?.title;
      final songArtist = song?.artist;
      if (songTitle != null || songArtist != null) {
          debugPrint('ZMR [LYRICS-SEARCH]: Direct lookups failed, searching for lyrics...');
          final query = '${songTitle ?? ""} ${songArtist ?? ""} lyrics'.trim();
          final searchResult = await _innerTube.search(query: query, params: 'EgWKAQIIAWoKEAkQAxAEEAkQBQ%3D%3D'); // Filter for songs
          final searchSongs = _parseBrowseSongs(searchResult.data);
          if (searchSongs.isNotEmpty) {
              final topLyricSong = searchSongs.first;
              debugPrint('ZMR [LYRICS-SEARCH]: Found potential lyric source: ${topLyricSong.id}');
              final searchNext = await _innerTube.next(videoId: topLyricSong.id, setLogin: true);
              final searchStatic = _parseStaticLyrics(searchNext.data);
              if (searchStatic != null) {
                  final lines = searchStatic.split('\n').map((l) => LyricsLine(timestamp: Duration.zero, text: l)).toList();
                  return LyricsData(lines: lines, source: 'YouTube Music (Search)');
              }
          }
      }

      debugPrint('ZMR [LYRICS-STATIC]: No source found even after search fallback');
    } catch (e) {
      debugPrint('ZMR [LYRICS-STATIC] Error: $e');
    }
    
    return null;
  }

  String? _findLyricsBrowseId(dynamic nextData) {
    try {
      // Look for the tabbed renderer which contains "Lyrics"
      final tabs = _findAllElements(nextData, 'tabRenderer');
      for (var tab in tabs) {
        final title = _getText(tab['title']);
        if (title.toLowerCase() == 'lyrics') {
          return tab['endpoint']?['browseEndpoint']?['browseId'];
        }
      }
    } catch (e) {
      debugPrint('ZMR [LYRICS-FIND] Error: $e');
    }
    return null;
  }

  String? _parseStaticLyrics(dynamic browseData) {
    try {
      // Look for any description shelf containing the lyrics text
      final shelves = _findAllElements(browseData, 'musicDescriptionShelfRenderer');
      for (var shelf in shelves) {
        final text = _getText(shelf['description']);
        if (text.isNotEmpty) return text;
      }
      
    } catch (_) {}
    return null;
  }

  /// Deep search for any string that matches a predicate
  List<String> _findAllStrings(dynamic data, bool Function(String) predicate) {
    Set<String> results = {};
    void search(dynamic node) {
      if (node is String) {
        if (predicate(node)) results.add(node);
      } else if (node is List) {
        for (var e in node) {
          search(e);
        }
      } else if (node is Map) {
        node.values.forEach(search);
      }
    }
    search(data);
    return results.toList();
  }

  /// Deep search for any string that looks like a specific browseId prefix
  List<String> _findAllBrowseIds(dynamic data, String prefix) {
    return _findAllStrings(data, (s) => s.startsWith(prefix));
  }
}
