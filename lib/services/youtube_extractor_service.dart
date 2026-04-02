import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'youtube_service.dart';
import '../core/youtube_config.dart';

class YouTubeExtractorService {
  final Dio _dio = Dio();
  final JavascriptRuntime _jsRuntime = getJavascriptRuntime();
  
  // Cache for player JS content
  static final Map<String, String> _playerJsCache = {};
  
  // Client definitions matching the working service
  static final Map<String, Map<String, String>> _clients = {
    'TVHTML5_EMBEDDED': {
      'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
      'clientVersion': '2.0',
      'clientId': '85',
      'userAgent': 'Mozilla/5.0 (PlayStation; PlayStation 4/12.02) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15',
    },
    'WEB_REMIX': {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20260213.01.00',
      'clientId': '67',
      'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
    },
    'ANDROID_VR': {
      'clientName': 'ANDROID_VR',
      'clientVersion': '1.61.48',
      'clientId': '28',
      'userAgent': 'com.google.android.apps.youtube.vr.oculus/1.61.48 (Linux; U; Android 12; en_US; Oculus Quest 3; Build/SQ3A.220605.009.A1; Cronet/132.0.6808.3)',
    },
    'TVHTML5': {
      'clientName': 'TVHTML5',
      'clientVersion': '7.20260213.00.00',
      'clientId': '7',
      'userAgent': 'Mozilla/5.0(SMART-TV; Linux; Tizen 4.0.0.2) AppleWebkit/605.1.15 (KHTML, like Gecko) SamsungBrowser/9.2 TV Safari/605.1.15',
    },
    'ANDROID': {
      'clientName': 'ANDROID',
      'clientVersion': '21.03.38',
      'clientId': '3',
      'userAgent': 'com.google.android.youtube/21.03.38 (Linux; U; Android 14) gzip',
    }
  };

  final List<String> _fallbackSequence = [
    'TVHTML5_EMBEDDED',
    'WEB_REMIX',
    'ANDROID_VR',
    'TVHTML5',
    'ANDROID'
  ];

  Future<String?> getStreamUrl(String videoId, TokenPair tokens) async {
    debugPrint('ZMR [EXTRACTOR]: Extracting $videoId...');

    for (var clientKey in _fallbackSequence) {
      try {
        final client = _clients[clientKey]!;
        debugPrint('ZMR [EXTRACTOR]: Trying $clientKey...');
        
        final playerResponse = await _callInnerTubePlayer(videoId, client, tokens);
        if (playerResponse == null || playerResponse['playabilityStatus']?['status'] != 'OK') {
          debugPrint('ZMR [EXTRACTOR]: $clientKey status: ${playerResponse?['playabilityStatus']?['status'] ?? 'FAILED'}');
          continue;
        }

        final streamingData = playerResponse['streamingData'];
        if (streamingData == null) continue;

        final formats = [
          ...(streamingData['adaptiveFormats'] ?? []),
          ...(streamingData['formats'] ?? [])
        ].where((f) => (f['mimeType'] as String).startsWith('audio')).toList();
        
        formats.sort((a, b) => (b['bitrate'] ?? 0).compareTo(a['bitrate'] ?? 0));
        debugPrint('ZMR [EXTRACTOR]: $clientKey found ${formats.length} formats');

        String? playerJs;
        Map<String, String?>? sigInfo;
        Map<String, String?>? nFuncInfo;

        for (var format in formats) {
          String? streamUrl = format['url'];

          // Handle Ciphered URL
          if (streamUrl == null && format['signatureCipher'] != null) {
            final params = Uri.splitQueryString(format['signatureCipher']);
            final s = params['s'];
            final sp = params['sp'] ?? 'sig';
            final baseUrl = params['url'];

            if (playerJs == null && playerResponse['assets']?['js'] != null) {
              playerJs = await _getPlayerJs('https://www.youtube.com${playerResponse['assets']['js']}');
              if (playerJs != null) {
                sigInfo = _extractSigFunc(playerJs);
                nFuncInfo = _extractNFunc(playerJs);
              }
            }

            if (s != null && baseUrl != null && playerJs != null && sigInfo != null) {
              final sig = _decipherSignature(s, playerJs, sigInfo);
              if (sig != null) {
                streamUrl = '$baseUrl&$sp=${Uri.encodeComponent(sig)}';
              }
            }
          }

          if (streamUrl != null) {
            // Apply N-Transform
            final nMatch = RegExp(r'[?&]n=([^&]+)').firstMatch(streamUrl);
            if (nMatch != null) {
              final nValue = Uri.decodeComponent(nMatch.group(1)!);
              if (playerJs == null && playerResponse['assets']?['js'] != null) {
                playerJs = await _getPlayerJs('https://www.youtube.com${playerResponse['assets']['js']}');
                if (playerJs != null) nFuncInfo = _extractNFunc(playerJs);
              }
              if (playerJs != null && nFuncInfo != null) {
                final transformedN = _transformNParam(nValue, playerJs, nFuncInfo);
                if (transformedN != null) {
                  streamUrl = streamUrl.replaceFirst(RegExp(r'([?&])n=[^&]+'), '${nMatch.group(1)}n=${Uri.encodeComponent(transformedN)}');
                }
              }
            }

            // Append PO Token
            if (tokens.poToken.isNotEmpty && (clientKey.contains('WEB') || clientKey.contains('TV'))) {
              final separator = streamUrl.contains('?') ? '&' : '?';
              streamUrl += '${separator}pot=${Uri.encodeComponent(tokens.poToken)}';
            }

            // Validate stream (similar to index.ts)
            if (await _validateStream(streamUrl)) {
              debugPrint('ZMR [EXTRACTOR]: SUCCESS with $clientKey');
              return streamUrl;
            }
          }
        }
      } catch (e) {
        debugPrint('ZMR [EXTRACTOR]: Error in loop: $e');
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _callInnerTubePlayer(String videoId, Map<String, String> client, TokenPair tokens) async {
    final Map<String, dynamic> context = {
      'client': {
        'clientName': client['clientName'],
        'clientVersion': client['clientVersion'],
        'clientId': client['clientId'],
        'visitorData': tokens.visitorData,
        'hl': 'en',
        'gl': 'US'
      }
    };

    if (client['clientName']!.contains('SIMPLY_EMBEDDED')) {
      context['thirdParty'] = {
        'embedUrl': 'https://www.youtube.com/watch?v=$videoId'
      };
    }

    final Map<String, dynamic> body = {
      'context': context,
      'videoId': videoId
    };

    if (tokens.poToken.isNotEmpty) {
      body['serviceIntegrityDimensions'] = {
        'poToken': tokens.poToken
      };
    }

    try {
      final response = await _dio.post(
        'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
        data: jsonEncode(body),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': client['userAgent'],
            'X-Goog-Visitor-Id': tokens.visitorData,
          }
        )
      );
      return response.data;
    } catch (e) {
      debugPrint('ZMR [EXTRACTOR]: InnerTube call failed: $e');
      return null;
    }
  }

  Future<String?> _getPlayerJs(String url) async {
    if (_playerJsCache.containsKey(url)) return _playerJsCache[url];
    try {
      final res = await _dio.get(url);
      _playerJsCache[url] = res.data;
      return res.data;
    } catch (e) {
      return null;
    }
  }

  Map<String, String?>? _extractSigFunc(String js) {
    final patterns = [
      RegExp(r'&&\s*\(\s*[a-zA-Z0-9$]+\s*=\s*([a-zA-Z0-9$]+)\s*\(\s*(\d+)\s*,\s*decodeURIComponent\s*\(\s*[a-zA-Z0-9$]+\s*\)'),
      RegExp(r'\b[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*encodeURIComponent\(([a-zA-Z0-9$]+)\('),
      RegExp(r'\bm=([a-zA-Z0-9$]{2,})\(decodeURIComponent\(h\.s\)\)')
    ];
    for (var p in patterns) {
      final match = p.firstMatch(js);
      if (match != null) {
        return {'name': match.group(1), 'arg': match.groupCount >= 2 ? match.group(2) : null};
      }
    }
    return null;
  }

  Map<String, String?>? _extractNFunc(String js) {
    final patterns = [
      RegExp(r'\.get\("n"\)\)&&\(b=([a-zA-Z0-9$]+)(?:\[(\d+)\])?\(([a-zA-Z0-9])\)'),
      RegExp(r'\.get\("n"\)\)\s*&&\s*\(([a-zA-Z0-9$]+)\s*=\s*([a-zA-Z0-9$]+)(?:\[(\d+)\])?\(\1\)')
    ];
    for (var p in patterns) {
      final match = p.firstMatch(js);
      if (match != null) {
        final name = match.groupCount >= 3 ? match.group(2) : match.group(1);
        final idx = match.groupCount >= 3 ? match.group(3) : (match.groupCount >= 2 ? match.group(2) : null);
        return {'name': name, 'idx': idx};
      }
    }
    return null;
  }

  String? _decipherSignature(String sig, String js, Map<String, String?> funcInfo) {
    try {
      final name = funcInfo['name'];
      final arg = funcInfo['arg'];
      final code = '''
        var window = {};
        var _yt_player = {};
        $js
        function extract() {
          if (typeof $name === 'function') {
            return $name(${arg != null ? '$arg,' : ''} "$sig");
          }
          return null;
        }
        extract();
      ''';
      final result = _jsRuntime.evaluate(code);
      return result.stringResult;
    } catch (e) {
      return null;
    }
  }

  String? _transformNParam(String n, String js, Map<String, String?> nFuncInfo) {
    try {
      final name = nFuncInfo['name'];
      final idx = nFuncInfo['idx'];
      final expr = idx != null ? '$name[$idx]' : name;
      final code = '''
        var window = {};
        var _yt_player = {};
        $js
        function extract() {
          if (typeof $expr === 'function') {
            return $expr("$n");
          }
          return null;
        }
        extract();
      ''';
      final result = _jsRuntime.evaluate(code);
      return result.stringResult;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _validateStream(String url) async {
    try {
      final response = await _dio.head(url, options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        },
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5)
      ));
      return response.statusCode == 200 || response.statusCode == 206;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _jsRuntime.dispose();
  }
}
