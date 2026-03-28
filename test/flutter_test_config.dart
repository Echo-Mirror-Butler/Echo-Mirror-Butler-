import 'dart:async';

import 'package:echomirror/core/services/supabase_client_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientService.ensureInitializedForTesting();
  await testMain();
}
