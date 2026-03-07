import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/supabase_config.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? Supabase.instance.client.auth.currentUser;
});

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  final _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      if (kIsWeb) {
        // Web MUST have a Client ID at initialization
        await _googleSignIn.initialize(
          clientId: SupabaseConfig.googleWebClientId,
        );
      } else {
        // Mobile (Android/iOS) typically gets it from native config, 
        // but passing it here can prevent issues with some plugin versions.
        await _googleSignIn.initialize();
      }
      _initialized = true;
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    await _ensureInitialized();
    
    // 1. Authenticate user
    final googleUser = await _googleSignIn.authenticate();

    // 2. Get tokens. idToken is still available in authentication getter usually.
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    // 3. Get accessToken (Separated in v7.x)
    final googleAuthClient = await googleUser.authorizationClient.authorizeScopes([]); 
    final accessToken = googleAuthClient.accessToken;

    if (idToken == null) {
      throw 'No Google ID Token found.';
    }

    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _client.auth.signOut();
  }
}

final authServiceProvider = Provider((ref) => AuthService());
