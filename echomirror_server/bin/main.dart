import 'package:serverpod/serverpod.dart';
import 'package:echomirror_server/server.dart';
import 'package:serverpod_auth_idp/serverpod_auth_idp.dart' as auth;

void main(List<String> args) async {
  // Initialize Serverpod
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    authenticationHandler: auth.authenticationHandler,
  );

  // Start the server
  await pod.start();
}
