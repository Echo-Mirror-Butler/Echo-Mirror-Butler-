import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'EchoMirror Butler'**
  String get appName;

  /// Tagline shown on the splash/onboarding screen
  ///
  /// In en, this message translates to:
  /// **'Your Personal Growth Assistant'**
  String get appTagline;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @logging.
  ///
  /// In en, this message translates to:
  /// **'Logging'**
  String get logging;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get errorAuth;

  /// No description provided for @successLogin.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get successLogin;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @logMood.
  ///
  /// In en, this message translates to:
  /// **'Log Today\'s Mood'**
  String get logMood;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @currentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get currentStreak;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @moodChart.
  ///
  /// In en, this message translates to:
  /// **'Mood Chart'**
  String get moodChart;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @echoBalance.
  ///
  /// In en, this message translates to:
  /// **'ECHO Balance'**
  String get echoBalance;

  /// No description provided for @noMoodsYet.
  ///
  /// In en, this message translates to:
  /// **'No moods logged yet. Start your journey!'**
  String get noMoodsYet;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @friendsActivity.
  ///
  /// In en, this message translates to:
  /// **'Friends Activity'**
  String get friendsActivity;

  /// No description provided for @habits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get habits;

  /// No description provided for @trackHabit.
  ///
  /// In en, this message translates to:
  /// **'Track Habit'**
  String get trackHabit;

  /// No description provided for @yourFirstTask.
  ///
  /// In en, this message translates to:
  /// **'Your first task'**
  String get yourFirstTask;

  /// No description provided for @tapToLogFirstEntry.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Log Today\'s Mood\" to make your first entry. Your future self will thank you!'**
  String get tapToLogFirstEntry;

  /// No description provided for @logMoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Mood'**
  String get logMoodTitle;

  /// No description provided for @howAreYouFeeling.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling?'**
  String get howAreYouFeeling;

  /// No description provided for @moodPrompt.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind today?'**
  String get moodPrompt;

  /// No description provided for @moodPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Describe your mood in a few words...'**
  String get moodPlaceholder;

  /// No description provided for @habitsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Which habits did you practice today?'**
  String get habitsPrompt;

  /// No description provided for @habitsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. meditation, exercise, reading'**
  String get habitsPlaceholder;

  /// No description provided for @addHabit.
  ///
  /// In en, this message translates to:
  /// **'Add habit'**
  String get addHabit;

  /// No description provided for @saveEntry.
  ///
  /// In en, this message translates to:
  /// **'Save Entry'**
  String get saveEntry;

  /// No description provided for @entrySaved.
  ///
  /// In en, this message translates to:
  /// **'Your mood has been logged!'**
  String get entrySaved;

  /// No description provided for @selectMood.
  ///
  /// In en, this message translates to:
  /// **'Select your mood'**
  String get selectMood;

  /// No description provided for @editEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit Entry'**
  String get editEntry;

  /// No description provided for @deleteEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete Entry'**
  String get deleteEntry;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this entry?'**
  String get deleteConfirm;

  /// No description provided for @voiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice Input'**
  String get voiceInput;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @detailTitle.
  ///
  /// In en, this message translates to:
  /// **'Mood Detail'**
  String get detailTitle;

  /// No description provided for @noEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get noEntries;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'ECHO Wallet'**
  String get walletTitle;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @createWallet.
  ///
  /// In en, this message translates to:
  /// **'Create Wallet'**
  String get createWallet;

  /// No description provided for @sendEcho.
  ///
  /// In en, this message translates to:
  /// **'Send ECHO'**
  String get sendEcho;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get noTransactions;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipient;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get message;

  /// No description provided for @messagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Keep shining.'**
  String get messagePlaceholder;

  /// No description provided for @maxChars.
  ///
  /// In en, this message translates to:
  /// **'max 140 chars'**
  String get maxChars;

  /// No description provided for @walletCreated.
  ///
  /// In en, this message translates to:
  /// **'Wallet created successfully!'**
  String get walletCreated;

  /// No description provided for @echoSent.
  ///
  /// In en, this message translates to:
  /// **'ECHO sent successfully!'**
  String get echoSent;

  /// No description provided for @connectWallet.
  ///
  /// In en, this message translates to:
  /// **'Connect External Wallet'**
  String get connectWallet;

  /// No description provided for @publicKey.
  ///
  /// In en, this message translates to:
  /// **'Public Key'**
  String get publicKey;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy Address'**
  String get copyAddress;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @downloadCSV.
  ///
  /// In en, this message translates to:
  /// **'Download CSV'**
  String get downloadCSV;

  /// No description provided for @testnetWarning.
  ///
  /// In en, this message translates to:
  /// **'You are on Testnet — ECHO and XLM here have no real-world value.'**
  String get testnetWarning;

  /// No description provided for @amountExceedsBalance.
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds your balance.'**
  String get amountExceedsBalance;

  /// No description provided for @cannotSendToSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot send ECHO to yourself.'**
  String get cannotSendToSelf;

  /// No description provided for @freighter.
  ///
  /// In en, this message translates to:
  /// **'Freighter (browser extension)'**
  String get freighter;

  /// No description provided for @connectFreighter.
  ///
  /// In en, this message translates to:
  /// **'Connect Freighter'**
  String get connectFreighter;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @removeWallet.
  ///
  /// In en, this message translates to:
  /// **'Remove wallet'**
  String get removeWallet;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize your app experience'**
  String get appearanceSubtitle;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @systemMode.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemMode;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notifications;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stay on track with daily reflections'**
  String get notificationsSubtitle;

  /// No description provided for @dailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily Mood Reminder'**
  String get dailyReminder;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// No description provided for @reminderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Reminders enabled'**
  String get reminderEnabled;

  /// No description provided for @reminderDisabled.
  ///
  /// In en, this message translates to:
  /// **'Reminders disabled'**
  String get reminderDisabled;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Control your visibility to followers'**
  String get privacySubtitle;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @accountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account settings'**
  String get accountSubtitle;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to EchoMirror'**
  String get welcome;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Your personal growth companion. Log your moods, track habits, and connect with others on a similar journey.'**
  String get welcomeDescription;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @step1Title.
  ///
  /// In en, this message translates to:
  /// **'Log Your Mood'**
  String get step1Title;

  /// No description provided for @step1Description.
  ///
  /// In en, this message translates to:
  /// **'Check in daily and track how you\'re feeling. Build self-awareness over time.'**
  String get step1Description;

  /// No description provided for @step2Title.
  ///
  /// In en, this message translates to:
  /// **'Earn Rewards'**
  String get step2Title;

  /// No description provided for @step2Description.
  ///
  /// In en, this message translates to:
  /// **'Build streaks and earn ECHO tokens as rewards for your consistency.'**
  String get step2Description;

  /// No description provided for @step3Title.
  ///
  /// In en, this message translates to:
  /// **'Connect & Share'**
  String get step3Title;

  /// No description provided for @step3Description.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous mood pins on the Global Mirror and support others.'**
  String get step3Description;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @globalMirrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Global Mirror'**
  String get globalMirrorTitle;

  /// No description provided for @activeMoods.
  ///
  /// In en, this message translates to:
  /// **'Active Moods'**
  String get activeMoods;

  /// No description provided for @worldwide.
  ///
  /// In en, this message translates to:
  /// **'worldwide'**
  String get worldwide;

  /// No description provided for @moodLegend.
  ///
  /// In en, this message translates to:
  /// **'Mood Legend'**
  String get moodLegend;

  /// No description provided for @positive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get positive;

  /// No description provided for @calm.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get calm;

  /// No description provided for @neutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get neutral;

  /// No description provided for @negative.
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get negative;

  /// No description provided for @anxious.
  ///
  /// In en, this message translates to:
  /// **'Anxious'**
  String get anxious;

  /// No description provided for @shareMood.
  ///
  /// In en, this message translates to:
  /// **'Share a mood to see it here!'**
  String get shareMood;

  /// No description provided for @streamConnected.
  ///
  /// In en, this message translates to:
  /// **'Stream connected'**
  String get streamConnected;

  /// No description provided for @showingFirst.
  ///
  /// In en, this message translates to:
  /// **'Showing first 50 pins'**
  String get showingFirst;

  /// No description provided for @switchTo2D.
  ///
  /// In en, this message translates to:
  /// **'Switch to 2D Map'**
  String get switchTo2D;

  /// No description provided for @switchTo3D.
  ///
  /// In en, this message translates to:
  /// **'Switch to 3D Globe'**
  String get switchTo3D;

  /// No description provided for @privacyInfo.
  ///
  /// In en, this message translates to:
  /// **'Privacy Info'**
  String get privacyInfo;

  /// No description provided for @moodNotifications.
  ///
  /// In en, this message translates to:
  /// **'Mood Support Notifications'**
  String get moodNotifications;

  /// No description provided for @exploreHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore the Global Mirror'**
  String get exploreHintTitle;

  /// No description provided for @exploreHintBody.
  ///
  /// In en, this message translates to:
  /// **'Pan to move around the globe • Pinch to zoom • Tap a mood pin to see how others are feeling'**
  String get exploreHintBody;

  /// No description provided for @tapToDismiss.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to dismiss'**
  String get tapToDismiss;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
