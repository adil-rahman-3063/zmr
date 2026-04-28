import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'core/supabase_config.dart';
import 'providers/theme_provider.dart';
import 'providers/music_provider.dart';
import 'providers/auth_provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/player_page.dart';
import 'widgets/mini_player.dart';
import 'widgets/frosted_nav_bar.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'services/audio_handler.dart';
import 'package:just_audio/just_audio.dart';

late AudioHandler zmrAudioHandler;
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup Audio Session for consistent playback across devices
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  await session.setActive(true);

  // Initialize Audio Service for background playback
  debugPrint('ZMR [BOOT]: Initializing AudioService...');
  try {
    zmrAudioHandler = await AudioService.init(
      builder: () {
        final player = AudioPlayer(
          userAgent: "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36",
        );
        return ZmrAudioHandler(player);
      },
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.zmr.channel.audio',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationIcon: 'mipmap/launcher_icon',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: Color(0xFF121212),
      ),
    );
    debugPrint('ZMR [BOOT]: AudioService initialized successfully.');
  } catch (e) {
    debugPrint('ZMR [BOOT] CRITICAL: AudioService failed to initialize: $e');
    // Fallback or handle error - though AudioService is usually required for this app's architecture now
  }
  
  final prefs = await SharedPreferences.getInstance();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider);
    final navKey = ref.read(navigatorKeyProvider);
    final dynamicColors = ref.watch(dynamicColorSchemeProvider).value;

    // Force navigation back to root on sign out
    ref.listen<User?>(currentUserProvider, (previous, next) {
      if (next == null && previous != null) {
        navKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
      }
    });

    final defaultDarkTheme = AppTheme.darkTheme;
    final theme = themeMode == ThemeMode.light ? AppTheme.lightTheme : (
        dynamicColors != null 
          ? defaultDarkTheme.copyWith(colorScheme: dynamicColors)
          : defaultDarkTheme
    );

    return MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      title: 'ZMR Music',
      theme: AppTheme.lightTheme,
      darkTheme: theme,
      themeMode: themeMode,
      home: user != null ? const HomePage() : const LoginPage(),
      builder: (context, child) {
        return HeroControllerScope.none(
          child: Navigator(
            key: rootNavigatorKey,
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => _ZmrAppShell(child: child!),
            ),
          ),
        );
      },
    );
  }
}

class _ZmrAppShell extends ConsumerWidget {
  final Widget child;
  const _ZmrAppShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isFullPlayerVisible = ref.watch(isFullPlayerVisibleProvider);
    final currentSong = ref.watch(currentSongProvider);
    
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // Main Content
          child,
          
          // Navigation & Mini Player (Stacked Cards layer)
          if (user != null)
            _StackedBottomShell(currentSong: currentSong),

          // Full Player (Sliding layer)
          if (user != null && currentSong != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutQuart,
              top: isFullPlayerVisible ? 0 : size.height,
              left: 0,
              right: 0,
              height: size.height,
              child: IgnorePointer(
                ignoring: !isFullPlayerVisible,
                child: HeroControllerScope.none(
                  child: Navigator(
                    onGenerateRoute: (settings) => MaterialPageRoute(
                      builder: (context) => const PlayerPage(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StackedBottomShell extends ConsumerStatefulWidget {
  final dynamic currentSong;
  const _StackedBottomShell({required this.currentSong});

  @override
  ConsumerState<_StackedBottomShell> createState() => _StackedBottomShellState();
}

class _StackedBottomShellState extends ConsumerState<_StackedBottomShell> with TickerProviderStateMixin {
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final activeIndex = ref.watch(shellCardIndexProvider);
    
    if (widget.currentSong == null) {
      return const Positioned(
        left: 24,
        right: 24,
        bottom: 24,
        height: 76,
        child: FrostedNavBar(),
      );
    }

    return Positioned(
      left: 20,
      right: 20,
      bottom: 24,
      height: 120, // Taller area for drag travel
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _isDragging = true;
            // Only allow upward dragging for the top card
            _dragOffset += details.primaryDelta!;
            if (_dragOffset > 0) _dragOffset = 0; // Prevent dragging down
          });
        },
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          setState(() => _isDragging = false);

          if (_dragOffset < -40 || velocity < -500) {
            // Re-shuffle!
            final newIndex = activeIndex == 0 ? 1 : 0;
            ref.read(shellCardIndexProvider.notifier).setIndex(newIndex);
            
            // Onboard: stop showing hint after first successful swipe
            ref.read(swipeHintShownProvider.notifier).markAsShown();
          }
          
          setState(() => _dragOffset = 0);
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Background Card
            _buildAnimatedCard(
              key: const ValueKey('bg_card'),
              child: activeIndex == 0 ? const FrostedNavBar() : const GlobalMiniPlayer(),
              isActive: false,
              isFront: false,
            ),
            // Foreground Card
            _buildAnimatedCard(
              key: const ValueKey('fg_card'),
              child: activeIndex == 0 ? const GlobalMiniPlayer() : const FrostedNavBar(),
              isActive: true,
              isFront: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({
    required Key key,
    required Widget child,
    required bool isActive,
    required bool isFront,
  }) {
    return AnimatedPositioned(
      key: key,
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      left: isFront ? 0 : 8,
      right: isFront ? 0 : 8,
      bottom: isFront ? (isActive ? -_dragOffset : 0) : (isActive ? 0 : 16),
      height: 76,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 400),
        scale: isFront ? 1.0 : 0.95,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isFront ? 1.0 : 0.5,
          child: IgnorePointer(
            ignoring: !isFront,
            child: child,
          ),
        ),
      ),
    );
  }
}
