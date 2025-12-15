import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/themes/app_theme.dart';
import 'core/viewmodel/providers/theme_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: EchoMirrorApp(),
    ),
  );
}

class EchoMirrorApp extends ConsumerWidget {
  const EchoMirrorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

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
