import 'package:flutter/widgets.dart';
import 'package:echomirror/l10n/app_localizations.dart';

/// Extension to easily access AppLocalizations from BuildContext
extension LocalizationExtension on BuildContext {
  /// Get the current AppLocalizations instance
  /// Usage: context.l10n.appName
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
