# 🌟 EchoMirror Butler

<div align="center">

**A Social Wellness App Powered by Stellar, AI, and Real-Time Video**

*Track your mood, compete with friends, gift Stellar crypto during live sessions, and grow together*

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Database-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Stellar](https://img.shields.io/badge/Stellar-Blockchain-7C3AED?logo=stellar&logoColor=white)](https://stellar.org)
[![Agora](https://img.shields.io/badge/Agora-Video%20Calls-099DFD?logo=agora&logoColor=white)](https://www.agora.io)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Coverage](https://codecov.io/gh/Echo-Mirror-Butler/Echo-Mirror-Butler-/branch/development/graph/badge.svg)](https://codecov.io/gh/Echo-Mirror-Butler/Echo-Mirror-Butler-)

</div>

---

## 📱 About EchoMirror Butler

**EchoMirror Butler** is a social wellness app built on the **Stellar blockchain** where users can gift each other Stellar crypto, engage in competitions and games designed to help manage stress, and connect through real-time video sessions powered by Agora. During live call sessions, users can send Stellar token gifts directly to one another — making support feel tangible.

The app also tracks your mood, logs daily habits, and uses Google Gemini AI to generate personalized insights, predictions, and suggestions based on your patterns.

### 🎯 Core Philosophy

We believe wellness is better together. EchoMirror Butler helps you:
- **Gift** — Send Stellar crypto to friends during live video sessions as a way to show support
- **Compete** — Join stress-relief games and competitions with other users
- **Reflect** — Track your mood, habits, and daily experiences
- **Grow** — Get AI-powered predictions and actionable suggestions based on your patterns
- **Connect** — Join real-time video sessions with the people who matter

---

## ✨ Key Features

### 💸 Stellar Blockchain Gifting
- **In-App Gifting**: Send and receive Stellar (XLM) tokens directly within the app
- **Live Session Gifts**: Gift crypto to other users during real-time video calls
- **Gift History**: Track all sent and received gifts with status and timestamps
- **Testnet Support**: Built and tested against the Stellar testnet for safe development

### 🎮 Competitions & Stress Relief
- **Interactive Games**: Engage in competitions and activities designed to reduce stress
- **Social Challenges**: Compete with friends and other users on wellness goals
- **Leaderboards**: Track your progress against the community

### 📹 Real-Time Video Sessions (Agora)
- **Live Calls**: Connect with other users through real-time video powered by Agora
- **Scheduled Sessions**: Book and manage upcoming video sessions
- **In-Call Gifting**: Send Stellar crypto gifts while on a live call

### 📝 Daily Logging
- **Mood Tracking**: Rate your day on a 1-5 scale
- **Habit Tracking**: Log daily habits and routines
- **Notes**: Capture thoughts, reflections, and memorable moments
- **Calendar View**: Visual calendar to see your logging history at a glance

### 🤖 AI-Powered Insights (Google Gemini)
- **1-Month Predictions**: Forecasts based on your mood and habit patterns
- **Habit Suggestions**: Personalized, actionable habit tweaks
- **Future Letters**: Motivational messages from "future you"
- **Pattern Detection**: AI analyzes mood trends, habit consistency, and note themes

### 🔐 Authentication & Security
- **Secure Login**: Email/password authentication via Supabase Auth
- **User Sessions**: Persistent sessions managed by Supabase
- **User Sessions**: Persistent sessions with JWT tokens
- **Protected Routes**: Route guards ensure authenticated access

---

## 🛠️ Tech Stack

### Frontend (Flutter)
- **Flutter** 3.10+ - Cross-platform framework
- **Riverpod** 2.6+ - State management
- **GoRouter** 14.2+ - Navigation and routing
- **Agora RTC** - Real-time video calls
- **Stellar SDK** - Blockchain transactions
- **FL Chart** - Data visualization
- **Table Calendar** - Calendar widget

### Backend (Supabase + Node.js)
- **Supabase** - Backend as a Service (PostgreSQL + Auth + Storage + Edge Functions)
- **PostgreSQL** - Database (managed by Supabase)
- **Supabase Auth** - Authentication with JWT
- **Supabase Edge Functions** - Serverless functions for AI and custom logic
- **Node.js 20+** - Custom server routes (Stellar integration)
- **Google Generative AI** - Gemini AI integration via Edge Functions
- **Resend** - Email delivery

### Blockchain (Stellar)
- **Stellar SDK** - Wallet creation, token transfers, and transaction signing
- **Stellar Testnet** - Safe development and testing environment
- **XLM Tokens** - Native Stellar currency for in-app gifting

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

- **Flutter SDK** 3.10 or higher ([install guide](https://docs.flutter.dev/get-started/install))
- **Dart SDK** 3.10 or higher (bundled with Flutter)
- **Xcode** 15+ (for iOS builds on macOS)
- **CocoaPods** (for iOS plugins — install via `brew install cocoapods`)
- **A Supabase project** (free tier works — [supabase.com](https://supabase.com))
- **Node.js 20+** (only needed if working on Edge Functions)

---

### 1. Clone & install dependencies

```bash
git clone https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-.git
cd Echo-Mirror-Butler-
flutter pub get
```

---

### 2. Set up your Supabase project

1. Go to [supabase.com](https://supabase.com) and create a free project (or ask the project lead to be added to the existing one).
2. In your Supabase dashboard, navigate to **Project Settings → API**.
3. Copy two values:
   - **Project URL** — looks like `https://xxxxxxxxxxxx.supabase.co`
   - **anon / public key** — a long JWT string

> **Never commit these values to git.** They are passed at runtime via `--dart-define`.

---

### 3. Store your credentials locally

Add the following to your `~/.zshrc` (or `~/.bashrc` on Linux):

```bash
export SUPABASE_URL="https://your-project-id.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key-here"
```

Then reload your shell:

```bash
source ~/.zshrc
```

---

### 4. Run the app

**Terminal:**
```bash
flutter run -d "iPhone 16 Pro" \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

**VS Code (recommended):**

A `.vscode/launch.json` is already set up. It reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from your environment automatically. Just press **F5** after step 3.

> **iOS note:** If you see a CocoaPods warning on first run, run `pod install --project-directory=ios` then try again.

---

### 5. Optional: AI features (Gemini)

AI insights require a Google Gemini API key set as a Supabase Edge Function secret. Without it the app falls back to mock data — everything else works normally.

```bash
supabase secrets set GEMINI_API_KEY=your_gemini_key
```

---

### 6. Optional: Stellar testnet gifting

The gifting feature runs against the Stellar testnet — no real funds involved. No extra setup is needed to use it; wallet creation and testnet funding happen automatically in-app.

If you are working on the **backend/server** routes, copy the example env file and fill in your testnet keypairs:

```bash
cp backend/.env.example backend/.env
# edit backend/.env with your STELLAR_ISSUER_* and STELLAR_DISTRIBUTOR_* keys
```

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


---

## 💸 Stellar Integration & Gifting

EchoMirror Butler is built on the **Stellar blockchain**, using it as the backbone for all in-app gifting and token transfers. Users create Stellar wallets within the app and can send XLM (Stellar's native token) to each other as a way to show support, celebrate milestones, or just brighten someone's day.

### How Gifting Works

1. **Wallet Creation** — When a user signs up, a Stellar keypair is generated and linked to their account. The app stores the public key for receiving gifts and securely manages the secret key for signing transactions.
2. **Sending Gifts** — Users can gift XLM to any other user in the app. The sender selects a recipient, enters an amount, and the app builds and submits a Stellar payment transaction on their behalf.
3. **Live Session Gifting** — During real-time video calls (powered by Agora), users can send Stellar gifts to the person they're on a call with — making the connection feel more personal and rewarding.
4. **Gift History** — Every transaction is tracked in-app with status chips (pending, completed, failed), timestamps, and sender/receiver details. Users can pull to refresh and see their full gift history.

### Stellar Testnet

All development and testing is done against the **Stellar Testnet**, so no real funds are involved during development. The app uses the Stellar Friendbot to fund testnet wallets automatically. Moving to mainnet is a configuration change — the transaction logic stays the same.

### Tech Details

- **Stellar SDK for Flutter** — Handles keypair generation, transaction building, and submission
- **Horizon API** — Queries account balances, transaction history, and network status
- **XDR Encoding** — Transactions are encoded and signed client-side before submission
- **Supabase Backend** — Edge Functions coordinate gift records and map Stellar transactions to user accounts

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
- **Secure**: API key stored as a secret in Supabase
- **Private**: Your data never leaves your server
- **Graceful Fallback**: Errors never break the app

For AI setup instructions, refer to your Supabase dashboard or use `supabase secrets set` to add the `GEMINI_API_KEY` secret.

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
```

---

## 📚 Documentation

For documentation and setup guides, please refer to the codebase comments and configuration files.

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
- [x] User authentication (email/password via Supabase Auth)
- [x] Daily logging (mood, habits, notes)
- [x] AI-powered insights and predictions (Google Gemini)
- [x] Real-time video sessions (Agora)
- [x] Stellar wallet integration and testnet gifting
- [x] Gift history tracking
- [x] Mood analytics and dashboard
- [x] Change password flow
- [x] CI pipeline with formatting, analysis, and tests
- [x] In-call Stellar gifting during video sessions

### Planned Features 🚧
- [ ] Competitions and stress-relief games
- [ ] Leaderboards and social challenges
- [ ] Stellar mainnet support
- [ ] Push notifications for session reminders
- [ ] Advanced mood analytics with charts
- [ ] Multi-language support

---

## 🤝 Contributing

Contributions are welcome! Please read the [CONTRIBUTING.md](CONTRIBUTING.md) guide before opening a PR — it covers branching strategy, PR checklist, commit format, code style, and local Supabase setup.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Flutter Team** - Amazing framework
- **Supabase** - Powerful Backend-as-a-Service
- **Stellar Development Foundation** - Blockchain infrastructure
- **Agora** - Real-time video SDK
- **Google Gemini** - AI capabilities
- **Riverpod** - Excellent state management

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/echomirror/issues)
- **Questions**: Open a discussion on GitHub

---

## ⭐ Show Your Support

If you find EchoMirror Butler helpful, please give it a ⭐ on GitHub!

---

<div align="center">

**Built with ❤️ using Flutter, Supabase & Stellar**

*Wellness is better together — gift, compete, reflect, and grow.*

</div>
