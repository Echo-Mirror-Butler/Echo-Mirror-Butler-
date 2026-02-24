import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/themes/app_theme.dart';
import 'core/viewmodel/providers/theme_provider.dart';
import 'core/viewmodel/providers/notification_provider.dart';
import 'core/services/serverpod_client_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Serverpod client service with persistent authentication
  await ServerpodClientService.instance.ensureInitialized();

  runApp(const ProviderScope(child: EchoMirrorApp()));
}

class EchoMirrorApp extends ConsumerStatefulWidget {
  const EchoMirrorApp({super.key});

  @override
  ConsumerState<EchoMirrorApp> createState() => _EchoMirrorAppState();
}

class _EchoMirrorAppState extends ConsumerState<EchoMirrorApp> {
  @override
  void initState() {
    super.initState();
    // Initialize notifications on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationInitProvider.future);
    });
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
