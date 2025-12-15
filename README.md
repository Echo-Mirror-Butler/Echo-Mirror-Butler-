# 🌟 EchoMirror Butler

<div align="center">

**Your Personal Growth Assistant with AI-Powered Insights**

*Transform your daily habits, track your mood, and receive personalized predictions powered by Google Gemini AI*

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Serverpod](https://img.shields.io/badge/Serverpod-3.0+-FF6B6B?logo=serverpod&logoColor=white)](https://serverpod.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-2.6+-FF6B6B?logo=riverpod&logoColor=white)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## 📱 About EchoMirror Butler

**EchoMirror Butler** is a beautifully designed Flutter application that helps you track your daily life, understand patterns in your behavior, and receive AI-powered insights to guide your personal growth journey. Think of it as your personal butler for self-improvement—always there to help you reflect, learn, and grow.

### 🎯 Core Philosophy

We believe that small, consistent actions lead to meaningful change. EchoMirror Butler helps you:
- **Reflect** on your daily experiences through mood and habit tracking
- **Understand** patterns in your behavior with AI-powered analysis
- **Grow** with personalized predictions and actionable suggestions
- **Connect** with your future self through motivational letters

---

## ✨ Key Features

### 📝 Daily Logging
- **Mood Tracking**: Rate your day on a 1-5 scale
- **Habit Tracking**: Log daily habits and routines
- **Notes**: Capture thoughts, reflections, and memorable moments
- **Calendar View**: Visual calendar to see your logging history at a glance
- **Date Selection**: Log entries for any date (past or present)

### 🤖 AI-Powered Insights (Powered by Google Gemini)
- **1-Month Predictions**: Get realistic forecasts about your future outcomes based on your patterns
- **Habit Suggestions**: Receive 1-3 actionable, fun habit tweaks personalized to your data
- **Future Letters**: Read motivational letters from "future you" written in first person (100-150 words)
- **Pattern Detection**: AI analyzes mood trends, habit consistency, and notes themes
- **Automatic Generation**: Insights are generated automatically after you log 3+ entries

### 📊 Dashboard & Analytics
- **Visual Statistics**: See your logging patterns at a glance
- **Mood Analytics**: Track mood trends over time
- **Insight Categories**: Organized insights by type (predictions, habits, moods, general)
- **Refresh Controls**: Pull to refresh or use refresh buttons
- **Beautiful Cards**: Elegant UI with gradient cards and smooth animations

### 🔐 Authentication & Security
- **Secure Login**: Email/password authentication via Serverpod
- **User Sessions**: Persistent sessions with JWT tokens
- **Protected Routes**: Route guards ensure authenticated access
- **User Profiles**: Personal data tied to your account

### 🎨 Beautiful UI/UX
- **Material Design 3**: Modern, clean interface
- **Google Fonts**: Elegant typography (Playfair Display for headings, Roboto for body)
- **FontAwesome Icons**: Rich iconography throughout
- **Light/Dark Mode**: Full theme support with smooth transitions
- **Gradient Cards**: Beautiful gradient backgrounds and shadows
- **Smooth Animations**: Polished interactions and transitions

### 🏗️ Robust Architecture
- **MVVM Pattern**: Clean separation of concerns
- **Feature-Based Structure**: Modular, scalable codebase
- **Riverpod State Management**: Reactive, type-safe state management
- **Serverpod Backend**: Scalable server architecture with PostgreSQL
- **Error Handling**: Graceful error handling with user-friendly messages

---

## 🛠️ Tech Stack

### Frontend (Flutter)
- **Flutter** 3.10+ - Cross-platform framework
- **Riverpod** 2.6+ - State management
- **GoRouter** 14.2+ - Navigation and routing
- **Google Fonts** - Typography
- **FontAwesome** - Icons
- **FL Chart** - Data visualization
- **Table Calendar** - Calendar widget

### Backend (Serverpod)
- **Serverpod** 3.0+ - Dart server framework
- **PostgreSQL** - Database
- **Redis** - Caching
- **JWT** - Authentication
- **Google Generative AI** - Gemini AI integration

### AI Integration
- **Google Gemini 1.5 Flash** - Fast, cost-effective AI model
- **Structured JSON Output** - Reliable parsing
- **Mock Data Fallback** - Works offline without API key

---

## 📸 Screenshots

> *Screenshots coming soon!*

### Planned Screenshots:
- 📱 Login Screen
- 📅 Daily Logging Interface
- 📊 Dashboard with AI Insights
- 💌 Future Letter Card
- 🔮 Prediction Card
- 💡 Suggestions List
- 📈 Mood Analytics

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** 3.10 or higher
- **Dart SDK** 3.10 or higher
- **Serverpod CLI** installed
- **Docker** (for local database)
- **PostgreSQL** (via Docker)
- **Redis** (via Docker)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd echomirror
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Serverpod server**
   ```bash
   cd ../echomirror_server/echomirror_server_server
   dart pub get
   ```

4. **Start the database**
   ```bash
   docker compose up --build --detach
   ```

5. **Apply database migrations**
   ```bash
   dart run bin/main.dart --apply-migrations
   ```

6. **Start the server**
   ```bash
   dart run bin/main.dart
   ```

7. **Run the Flutter app**
   ```bash
   cd ../../echomirror
   flutter run
   ```

### Configuration

1. **Update Server URL** (if needed)
   - Edit `lib/core/constants/api_constants.dart`
   - Default: `http://localhost:8080` (local)
   - Production: Your Serverpod Cloud URL

2. **Add Gemini API Key** (Optional - for AI features)
   - Go to Serverpod Cloud dashboard
   - Add secret: `GEMINI_API_KEY`
   - App works without it (uses mock data)

---

## 📖 Usage Guide

### First Time Setup

1. **Create an Account**
   - Launch the app
   - Sign up with your email
   - Verify your email (if required)
   - Log in

2. **Start Logging**
   - Navigate to the Logging screen
   - Tap the "+" button to create your first entry
   - Select a date, rate your mood, add habits, and write notes
   - Save your entry

3. **View Insights**
   - After logging 3+ entries, go to Dashboard
   - AI insights will appear automatically
   - Tap "Refresh Insight" to generate new insights

### Daily Workflow

1. **Morning**: Review yesterday's insights and predictions
2. **Throughout the Day**: Log habits as you complete them
3. **Evening**: Create a log entry with mood, habits, and notes
4. **Weekly**: Review patterns and suggestions in Dashboard

### Understanding Insights

- **Predictions**: Based on your recent patterns, what might happen in 1 month?
- **Suggestions**: Actionable habit tweaks to improve your routine
- **Future Letters**: Motivational messages from "future you" based on your progress

---

## 🏛️ Architecture

EchoMirror Butler follows a strict **MVVM (Model-View-ViewModel)** architecture pattern with feature-based organization.

### Project Structure

```
lib/
├── core/                    # Shared utilities
│   ├── constants/          # App constants
│   ├── themes/             # Theme configuration
│   ├── utils/              # Utility functions
│   ├── routing/             # Navigation
│   └── viewmodel/          # Global providers
│
├── features/               # Feature modules
│   ├── auth/               # Authentication
│   ├── logging/            # Daily logging
│   ├── dashboard/          # Insights & analytics
│   ├── ai/                 # AI insights
│   └── settings/           # User settings
│
└── main.dart               # App entry point
```

### Key Patterns

- **MVVM**: Separation of data, view, and business logic
- **Repository Pattern**: Abstract data access layer
- **Provider Pattern**: Riverpod for state management
- **Feature Modules**: Self-contained, modular features

For detailed architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 🤖 AI Integration

EchoMirror Butler uses **Google Gemini AI** to generate personalized insights:

### How It Works

1. **Data Collection**: You log daily entries (mood, habits, notes)
2. **Pattern Analysis**: AI analyzes your recent logs (last 7-14 days)
3. **Insight Generation**: AI generates predictions, suggestions, and letters
4. **Display**: Insights appear in beautiful cards on your Dashboard

### AI Features

- ✅ **Pattern Detection**: Identifies trends in mood, habits, and notes
- ✅ **Predictions**: Realistic 1-month outcome forecasts
- ✅ **Suggestions**: Actionable habit improvements
- ✅ **Future Letters**: Empathetic motivational messages

### Privacy & Offline Mode

- **Works Offline**: App functions fully without API key (uses mock data)
- **Secure**: API key stored in Serverpod Cloud secrets
- **Private**: Your data never leaves your server
- **Graceful Fallback**: Errors never break the app

For AI setup instructions, see [GEMINI_INTEGRATION.md](GEMINI_INTEGRATION.md).

---

## 🧪 Development

### Running Tests

```bash
flutter test
```

### Code Analysis

```bash
flutter analyze
```

### Format Code

```bash
flutter format .
```

### Generate Code

```bash
# For Riverpod code generation
flutter pub run build_runner build

# For Serverpod code generation
cd ../echomirror_server/echomirror_server_server
serverpod generate
```

---

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture documentation
- **[GEMINI_INTEGRATION.md](GEMINI_INTEGRATION.md)** - AI integration setup guide
- **[SERVERPOD_SETUP.md](SERVERPOD_SETUP.md)** - Serverpod server setup

---

## 🎨 Design Philosophy

EchoMirror Butler is designed with these principles:

- **Elegance**: Beautiful, modern UI that feels premium
- **Simplicity**: Easy to use, no clutter
- **Empathy**: Warm, encouraging tone throughout
- **Consistency**: Cohesive design language
- **Accessibility**: Usable by everyone

### Color Palette

- **Primary**: Indigo (`#6366F1`) - Trust, stability
- **Secondary**: Purple (`#8B5CF6`) - Creativity, wisdom
- **Accent**: Pink (`#EC4899`) - Energy, optimism
- **Success**: Green (`#10B981`) - Growth, progress
- **Error**: Red (`#EF4444`) - Clear feedback

### Typography

- **Headings**: Playfair Display (elegant serif)
- **Body**: Roboto (clean sans-serif)
- **Icons**: FontAwesome (comprehensive icon set)

---

## 🛣️ Roadmap

### Current Features ✅
- [x] User authentication
- [x] Daily logging (mood, habits, notes)
- [x] Calendar view
- [x] Dashboard with insights
- [x] AI-powered predictions
- [x] AI-generated suggestions
- [x] Future letters from AI
- [x] Mood analytics
- [x] Beautiful UI/UX

### Planned Features 🚧
- [ ] Habit streaks tracking
- [ ] Export data (CSV/JSON)
- [ ] Push notifications for reminders
- [ ] Social sharing of insights
- [ ] Custom habit templates
- [ ] Advanced mood analytics with charts
- [ ] Insight history and comparison
- [ ] Multi-language support

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow the existing code style
- Write meaningful commit messages
- Add tests for new features
- Update documentation as needed
- Follow MVVM architecture pattern

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Flutter Team** - Amazing framework
- **Serverpod** - Powerful backend solution
- **Google Gemini** - AI capabilities
- **Riverpod** - Excellent state management
- **FontAwesome** - Beautiful icons
- **Google Fonts** - Typography

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/echomirror/issues)
- **Documentation**: See [ARCHITECTURE.md](ARCHITECTURE.md)
- **Questions**: Open a discussion on GitHub

---

## ⭐ Show Your Support

If you find EchoMirror Butler helpful, please give it a ⭐ on GitHub!

---

<div align="center">

**Built with ❤️ using Flutter & Serverpod**

*Your journey to personal growth starts with a single log entry.*

</div>
