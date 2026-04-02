import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/supabase_config.dart';
import 'music_provider.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? Supabase.instance.client.auth.currentUser;
});

// Provides access to the YouTube headers stored after sign-in
class YoutubeAuthNotifier extends Notifier<Map<String, String>?> {
  static const _key = 'yt_auth_headers';

  @override
  Map<String, String>? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final str = prefs.getString(_key);
    if (str != null) {
      try {
        return Map<String, String>.from(jsonDecode(str));
      } catch (_) {}
    }
    return null;
  }

  void setHeaders(Map<String, String>? headers) {
    state = headers;
    final prefs = ref.read(sharedPreferencesProvider);
    if (headers == null) {
      prefs.remove(_key);
    } else {
      prefs.setString(_key, jsonEncode(headers));
    }
  }
}

final youtubeAuthHeadersProvider = NotifierProvider<YoutubeAuthNotifier, Map<String, String>?>(YoutubeAuthNotifier.new);

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;
  final Ref ref;

  AuthService(this.ref);

  // Singleton instance
  final _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      if (kIsWeb) {
        await _googleSignIn.initialize(
          clientId: SupabaseConfig.googleWebClientId,
        );
      } else {
        await _googleSignIn.initialize(
          serverClientId: SupabaseConfig.googleWebClientId,
        );
      }
      _initialized = true;
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    await _ensureInitialized();
    
    // 1. Authenticate user
    // In 7.2.0, use scopeHint to request specific scopes during auth
    final googleUser = await _googleSignIn.authenticate(
      scopeHint: ['https://www.googleapis.com/auth/youtube.readonly'],
    );


    // 2. Get ID Token from authentication
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw 'No Google ID Token found.';
    }

    // 3. Store auth headers for YouTube Service
    // VERIFIED 7.2.0 API: Use authorizationClient to get headers for specific scopes
    final headers = await googleUser.authorizationClient.authorizationHeaders([
      'https://www.googleapis.com/auth/youtube.readonly',
    ]);
    
    ref.read(youtubeAuthHeadersProvider.notifier).setHeaders(headers);

    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    ref.read(youtubeAuthHeadersProvider.notifier).setHeaders(null);
    await _client.auth.signOut();
  }
}

final authServiceProvider = Provider((ref) => AuthService(ref));
