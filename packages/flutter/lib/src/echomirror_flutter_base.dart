/// Base class for EchoMirror Flutter functionality.
abstract class EchoMirrorFlutterBase {
  /// Returns the version of the package.
  static String get version => '0.1.0';

  /// Greets the user with the given [name].
  static String greet(String name) => 'Hello, $name! Welcome to EchoMirror.';
}