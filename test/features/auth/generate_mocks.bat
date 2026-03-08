@echo off
REM Script to generate mock classes for AuthRepository tests

echo Generating mock classes for AuthRepository tests...
echo.

REM Navigate to project root (3 levels up from test/features/auth)
cd ..\..\..

REM Run build_runner to generate mocks
flutter pub run build_runner build --delete-conflicting-outputs

echo.
echo Mock generation complete!
echo You can now run the tests with: flutter test test/features/auth/auth_repository_test.dart
