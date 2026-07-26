import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/themes/app_theme.dart';
import 'core/viewmodel/providers/theme_provider.dart';
import 'core/viewmodel/providers/notification_provider.dart';
import 'core/services/supabase_client_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/mood_sync_service.dart';
import 'core/services/sentry_service.dart';
import 'features/auth/viewmodel/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry before anything else so it captures bootstrap errors
  const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  await SentryService.init(environment: environment);

  // Initialize Supabase client service before app start.
  await SupabaseClientService.instance.ensureInitialized();

  runApp(const ProviderScope(child: EchoMirrorApp()));
}

class EchoMirrorApp extends ConsumerStatefulWidget {
  const EchoMirrorApp({super.key});

  @override
  ConsumerState<EchoMirrorApp> createState() => _EchoMirrorAppState();
}

class _EchoMirrorAppState extends ConsumerState<EchoMirrorApp> {
  final _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    // Initialize notifications on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationInitProvider.future);

      // Start the offline mood log queue (auto-syncs on reconnect)
      ref.read(moodSyncInitProvider.future);

      // Initialize deep link handling
      final router = ref.read(routerProvider);
      _deepLinkService.initialize(
        onNavigate: (route) {
          router.go(route);
        },
      );

      // Set Sentry user ID if available
      final user = ref.read(authProvider).user;
      if (user != null) {
        SentryService.setUserId(user.id);
      }
    });
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    // Watch notification init (but don't block UI)
    ref.watch(notificationInitProvider);

    return MaterialApp.router(
      title: 'EchoMirror Butler',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
