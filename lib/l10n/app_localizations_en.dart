// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'EchoMirror Butler';

  @override
  String get appTagline => 'Your Personal Growth Assistant';

  @override
  String get home => 'Home';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get logging => 'Logging';

  @override
  String get settings => 'Settings';

  @override
  String get login => 'Login';

  @override
  String get signUp => 'Sign Up';

  @override
  String get logout => 'Logout';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorNetwork => 'Network error. Please check your connection.';

  @override
  String get errorAuth => 'Authentication failed. Please try again.';

  @override
  String get successLogin => 'Login successful';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get logMood => 'Log Today\'s Mood';

  @override
  String get streak => 'Streak';

  @override
  String get currentStreak => 'Current Streak';

  @override
  String get days => 'days';

  @override
  String get moodChart => 'Mood Chart';

  @override
  String get insights => 'Insights';

  @override
  String get echoBalance => 'ECHO Balance';

  @override
  String get noMoodsYet => 'No moods logged yet. Start your journey!';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get viewAll => 'View All';

  @override
  String get friendsActivity => 'Friends Activity';

  @override
  String get habits => 'Habits';

  @override
  String get trackHabit => 'Track Habit';

  @override
  String get yourFirstTask => 'Your first task';

  @override
  String get tapToLogFirstEntry =>
      'Tap \"Log Today\'s Mood\" to make your first entry. Your future self will thank you!';

  @override
  String get logMoodTitle => 'Log Mood';

  @override
  String get howAreYouFeeling => 'How are you feeling?';

  @override
  String get moodPrompt => 'What\'s on your mind today?';

  @override
  String get moodPlaceholder => 'Describe your mood in a few words...';

  @override
  String get habitsPrompt => 'Which habits did you practice today?';

  @override
  String get habitsPlaceholder => 'e.g. meditation, exercise, reading';

  @override
  String get addHabit => 'Add habit';

  @override
  String get saveEntry => 'Save Entry';

  @override
  String get entrySaved => 'Your mood has been logged!';

  @override
  String get selectMood => 'Select your mood';

  @override
  String get editEntry => 'Edit Entry';

  @override
  String get deleteEntry => 'Delete Entry';

  @override
  String get deleteConfirm => 'Are you sure you want to delete this entry?';

  @override
  String get voiceInput => 'Voice Input';

  @override
  String get calendar => 'Calendar';

  @override
  String get detailTitle => 'Mood Detail';

  @override
  String get noEntries => 'No entries yet';

  @override
  String get walletTitle => 'ECHO Wallet';

  @override
  String get balance => 'Balance';

  @override
  String get createWallet => 'Create Wallet';

  @override
  String get sendEcho => 'Send ECHO';

  @override
  String get send => 'Send';

  @override
  String get receive => 'Receive';

  @override
  String get transactionHistory => 'Transaction History';

  @override
  String get noTransactions => 'No transactions yet.';

  @override
  String get amount => 'Amount';

  @override
  String get recipient => 'Recipient';

  @override
  String get message => 'Message (optional)';

  @override
  String get messagePlaceholder => 'Keep shining.';

  @override
  String get maxChars => 'max 140 chars';

  @override
  String get walletCreated => 'Wallet created successfully!';

  @override
  String get echoSent => 'ECHO sent successfully!';

  @override
  String get connectWallet => 'Connect External Wallet';

  @override
  String get publicKey => 'Public Key';

  @override
  String get copyAddress => 'Copy Address';

  @override
  String get copied => 'Copied';

  @override
  String get refresh => 'Refresh';

  @override
  String get downloadCSV => 'Download CSV';

  @override
  String get testnetWarning =>
      'You are on Testnet — ECHO and XLM here have no real-world value.';

  @override
  String get amountExceedsBalance => 'Amount exceeds your balance.';

  @override
  String get cannotSendToSelf => 'You cannot send ECHO to yourself.';

  @override
  String get freighter => 'Freighter (browser extension)';

  @override
  String get connectFreighter => 'Connect Freighter';

  @override
  String get connecting => 'Connecting...';

  @override
  String get removeWallet => 'Remove wallet';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSubtitle => 'Customize your app experience';

  @override
  String get theme => 'Theme';

  @override
  String get lightMode => 'Light';

  @override
  String get darkMode => 'Dark';

  @override
  String get systemMode => 'System';

  @override
  String get notifications => 'Reminders';

  @override
  String get notificationsSubtitle => 'Stay on track with daily reflections';

  @override
  String get dailyReminder => 'Daily Mood Reminder';

  @override
  String get reminderTime => 'Reminder time';

  @override
  String get reminderEnabled => 'Reminders enabled';

  @override
  String get reminderDisabled => 'Reminders disabled';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacySubtitle => 'Control your visibility to followers';

  @override
  String get account => 'Account';

  @override
  String get accountSubtitle => 'Manage your account settings';

  @override
  String get changePassword => 'Change Password';

  @override
  String get signOut => 'Sign Out';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get language => 'Language';

  @override
  String get welcome => 'Welcome to EchoMirror';

  @override
  String get welcomeDescription =>
      'Your personal growth companion. Log your moods, track habits, and connect with others on a similar journey.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get step1Title => 'Log Your Mood';

  @override
  String get step1Description =>
      'Check in daily and track how you\'re feeling. Build self-awareness over time.';

  @override
  String get step2Title => 'Earn Rewards';

  @override
  String get step2Description =>
      'Build streaks and earn ECHO tokens as rewards for your consistency.';

  @override
  String get step3Title => 'Connect & Share';

  @override
  String get step3Description =>
      'Share anonymous mood pins on the Global Mirror and support others.';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get globalMirrorTitle => 'Global Mirror';

  @override
  String get activeMoods => 'Active Moods';

  @override
  String get worldwide => 'worldwide';

  @override
  String get moodLegend => 'Mood Legend';

  @override
  String get positive => 'Positive';

  @override
  String get calm => 'Calm';

  @override
  String get neutral => 'Neutral';

  @override
  String get negative => 'Negative';

  @override
  String get anxious => 'Anxious';

  @override
  String get shareMood => 'Share a mood to see it here!';

  @override
  String get streamConnected => 'Stream connected';

  @override
  String get showingFirst => 'Showing first 50 pins';

  @override
  String get switchTo2D => 'Switch to 2D Map';

  @override
  String get switchTo3D => 'Switch to 3D Globe';

  @override
  String get privacyInfo => 'Privacy Info';

  @override
  String get moodNotifications => 'Mood Support Notifications';

  @override
  String get exploreHintTitle => 'Explore the Global Mirror';

  @override
  String get exploreHintBody =>
      'Pan to move around the globe • Pinch to zoom • Tap a mood pin to see how others are feeling';

  @override
  String get tapToDismiss => 'Tap anywhere to dismiss';
}
