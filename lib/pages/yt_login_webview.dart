import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cookie_manager_flutter/webview_cookie_manager.dart';
import '../providers/music_provider.dart';
import '../services/youtube_service.dart';
import 'home_page.dart';

import '../main.dart';

class YtLoginWebview extends ConsumerStatefulWidget {
  const YtLoginWebview({super.key});

  @override
  ConsumerState<YtLoginWebview> createState() => _YtLoginWebviewState();
}

class _YtLoginWebviewState extends ConsumerState<YtLoginWebview> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shellVisibilityOverrideProvider.notifier).setState(false);
    });
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36")
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }

            if (url.startsWith('https://music.youtube.com') && !_isLoggingIn) {
              _isLoggingIn = true;
              await _handleLogin(url);
            }
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              debugPrint('ZMR [WEBVIEW]: Preventing navigation to non-http/https URL: $url');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://accounts.google.com/ServiceLogin?continue=https%3A%2F%2Fmusic.youtube.com'));
  }

  @override
  void dispose() {
    // Restore shell visibility when leaving this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.context.mounted) {
        ref.read(shellVisibilityOverrideProvider.notifier).setState(true);
      }
    });
    super.dispose();
  }

  Future<void> _handleLogin(String url) async {
    try {
      // Get ALL cookies (including HttpOnly) using the native cookie manager
      final cookieManager = WebviewCookieManager();
      final gotCookies = await cookieManager.getCookies(url);
      final cookies = gotCookies.map((c) => '${c.name}=${c.value}').join('; ');
      
      debugPrint('ZMR [LOGIN]: Found ${gotCookies.length} cookies.');
      await _processLoginData(cookies, url);
    } catch (e) {
      debugPrint('ZMR [LOGIN] Error: $e');
      
      // Fallback: If native cookie manager fails (e.g. MissingPluginException), try JS document.cookie
      try {
        final jsCookies = await _controller.runJavaScriptReturningResult('document.cookie') as String;
        if (jsCookies.isNotEmpty && jsCookies != '""') {
           debugPrint('ZMR [LOGIN]: Fallback to JS cookies successful.');
           await _processLoginData(jsCookies, url);
           return;
        }
      } catch (innerE) {
        debugPrint('ZMR [LOGIN]: Fallback also failed: $innerE');
      }

      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  Future<void> _processLoginData(String cookies, String url) async {
    try {
      // Get Visitor Data and DataSync ID from window.yt.config_
      final visitorDataObj = await _controller.runJavaScriptReturningResult('window.yt.config_ ? window.yt.config_.VISITOR_DATA : null');
      final dataSyncIdRawObj = await _controller.runJavaScriptReturningResult('window.yt.config_ ? window.yt.config_.DATASYNC_ID : null');
      
      final visitorData = visitorDataObj.toString();
      final dataSyncIdRaw = dataSyncIdRawObj.toString();

      String cleanVisitorData;
      String cleanDataSyncId;

      if (visitorData == 'null' || dataSyncIdRaw == 'null') {
        debugPrint('ZMR [LOGIN]: Tokens not yet available. Waiting a bit...');
        await Future.delayed(const Duration(seconds: 2));
        final retryVisitorDataObj = await _controller.runJavaScriptReturningResult('window.yt.config_ ? window.yt.config_.VISITOR_DATA : null');
        final retryDataSyncIdRawObj = await _controller.runJavaScriptReturningResult('window.yt.config_ ? window.yt.config_.DATASYNC_ID : null');
        
        if (retryVisitorDataObj.toString() == 'null') {
          debugPrint('ZMR [LOGIN]: Tokens still not available after retry.');
          if (mounted) setState(() => _isLoggingIn = false);
          return;
        }
        cleanVisitorData = retryVisitorDataObj.toString().replaceAll('"', '');
        cleanDataSyncId = retryDataSyncIdRawObj.toString().replaceAll('"', '').split('||')[0];
      } else {
        cleanVisitorData = visitorData.replaceAll('"', '');
        cleanDataSyncId = dataSyncIdRaw.replaceAll('"', '').split('||')[0];
      }
      
      final cleanCookies = cookies.replaceAll('"', '');

      if (cleanCookies.contains('SAPISID') || cleanCookies.contains('__Secure-3PAPISID')) {
        debugPrint('ZMR [LOGIN]: Captured cookies and tokens.');
        ref.read(youtubeCookieProvider.notifier).setCookies(cleanCookies);
        
        final ytService = ref.read(youtubeServiceProvider);
        final tokens = TokenPair(
          visitorData: cleanVisitorData,
          poToken: '',
          dataSyncId: cleanDataSyncId,
        );
        ytService.setTokens(tokens);

        try {
          final accountInfo = await ytService.getAccountInfo().timeout(const Duration(seconds: 10));
          if (accountInfo != null) {
            debugPrint('ZMR [LOGIN]: Validated. Logged in as ${accountInfo['name']}');
          }
        } catch (e) {
          debugPrint('ZMR [LOGIN]: Validation error/timeout: $e. Proceeding anyway.');
        }

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        }
      } else {
        if (mounted) setState(() => _isLoggingIn = false);
      }
    } catch (e) {
      debugPrint('ZMR [PROCESS DATA] Error: $e');
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to YouTube Music'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoggingIn)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Validating Login...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
