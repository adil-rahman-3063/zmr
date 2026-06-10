import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
    return UpdateBannerState();
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
