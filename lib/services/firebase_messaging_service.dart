import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

// Represents the state of an incoming update notification
class UpdateBannerState {
  final bool show;
  final String version;
  final String updateUrl;

  UpdateBannerState({this.show = false, this.version = '', this.updateUrl = ''});
}

class FirebaseMessagingService extends Notifier<UpdateBannerState> {
  @override
  UpdateBannerState build() {
    _initFCM();
    _initRemoteConfig();
    return UpdateBannerState();
  }

  bool isVersionOutdated(String installedVersion, String latestVersion) {
    try {
      final installedClean = installedVersion.split('+')[0];
      final latestClean = latestVersion.split('+')[0];

      final installedParts = installedClean.split('.');
      final latestParts = latestClean.split('.');

      for (int i = 0; i < 3; i++) {
        final installedNum = i < installedParts.length ? (int.tryParse(installedParts[i]) ?? 0) : 0;
        final latestNum = i < latestParts.length ? (int.tryParse(latestParts[i]) ?? 0) : 0;

        if (latestNum > installedNum) return true;
        if (latestNum < installedNum) return false;
      }
    } catch (e) {
      debugPrint('ZMR [VERSION]: Error comparing versions: $e');
    }
    return false;
  }

  Future<void> _initRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    try {
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: Duration.zero, // Fetch every open
      ));

      await remoteConfig.setDefaults(const {
        'latest_version': '3.1.4',
        'update_url': 'https://github.com/AdilRahman-3063/zmr/releases',
      });

      try {
        await remoteConfig.fetchAndActivate();
      } catch (fetchError) {
        debugPrint('ZMR [RemoteConfig] Fetch failed (using cached/defaults): $fetchError');
      }

      final latestVersion = remoteConfig.getString('latest_version');
      final updateUrl = remoteConfig.getString('update_url');

      final packageInfo = await PackageInfo.fromPlatform();
      debugPrint('ZMR [RemoteConfig]: Installed version: ${packageInfo.version}, Latest remote version: $latestVersion');

      if (isVersionOutdated(packageInfo.version, latestVersion)) {
        state = UpdateBannerState(show: true, version: latestVersion, updateUrl: updateUrl);
      }
    } catch (e) {
      debugPrint('ZMR [RemoteConfig] Error: $e');
    }
  }

  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;
    
    // Request permission (mostly for iOS)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('ZMR [FCM]: Received foreground message: ${message.data}');
      _handleMessage(message);
    });

    // Handle messages when the app is opened from the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('ZMR [FCM]: Opened from background message: ${message.data}');
      _handleMessage(message);
    });

    // Handle initial message if the app was opened from a terminated state
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  }

  void _handleMessage(RemoteMessage message) {
    // Check if the notification payload contains an "update" directive
    if (message.data['type'] == 'update') {
      final version = message.data['version'] ?? 'New Version';
      final url = message.data['url'] ?? '';
      
      // Update state to trigger banner
      state = UpdateBannerState(show: true, version: version, updateUrl: url);
    }
  }

  void dismissBanner() {
    state = UpdateBannerState(show: false);
  }
}

final firebaseMessagingProvider = NotifierProvider<FirebaseMessagingService, UpdateBannerState>(
  FirebaseMessagingService.new,
);

// Global background handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('ZMR [FCM]: Handling a background message ${message.messageId}');
}
