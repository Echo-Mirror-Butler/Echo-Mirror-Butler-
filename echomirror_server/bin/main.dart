import 'package:serverpod/serverpod.dart';
import 'package:echomirror_server/server.dart';
import 'package:serverpod_auth_server/serverpod_auth_server.dart' as auth;

void main(List<String> args) async {
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    authenticationHandler: auth.authenticationHandler,
  );

  await pod.start();
}
