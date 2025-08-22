<div align="center">
  <img src="screenshots/moodflow_banner.png" alt="MoodFlow Banner" style="width:100%; max-height:500px; object-fit:cover; border-radius:12px;">
</div>

# MoodFlow 🌟
<img src="screenshots/moodflow_icon.png" alt="MoodFlow Icon" width="128">

A comprehensive mood tracking application built with Flutter, designed to help users monitor their emotional wellbeing throughout the day with intelligent insights and goal tracking.

## 📱 Features

### Core Functionality
- **Multi-Segment Daily Tracking** - Track your mood during morning, midday, and evening periods
- **Visual Mood Rating** - Intuitive 1-10 scale with emoji feedback and smooth animations
- **Rich Note-Taking** - Add detailed notes and thoughts for each mood entry
- **Historical View** - Browse and edit past mood entries with monthly navigation
- **Trend Analysis** - Visualize mood patterns with interactive charts and heatmaps

### Smart Features
- **Intelligent Notifications** - Context-aware reminders for mood logging
- **Goal Setting & Tracking** - Set personalized mood goals with progress monitoring
- **Time-Based Access** - Morning, midday, and evening logging unlocks throughout the day
- **Statistics Dashboard** - Comprehensive insights including streaks, averages, and patterns
- **Dark/Light Mode** - Adaptive themes with custom gradient backgrounds

### AI Analysis ✨ *(New)*
- AI-Powered Insights - Leverage OpenAI to receive intelligent summaries and mood analysis
- Custom API Key - Add your own OpenAI key for private usage
- Future Updates:
    - Choose which AI model you’d like to use
    - Select from different AI providers (not just OpenAI)
- Production Plan:
    - Option to use your own API key
    - Or pay to use MoodFlow’s managed app key

### User Experience
- **Blur Transitions** - Smooth, professional navigation animations
- **Responsive Design** - Optimized for all screen sizes and orientations
- **Offline Support** - Local data storage with SharedPreferences
- **Manual Entry** - Add historical mood data for missed days

## 🛠️ Technology Stack

- **Framework**: Flutter 3.8.1+
- **Language**: Dart
- **Local Storage**: SharedPreferences
- **Notifications**: Flutter Local Notifications
- **Date/Time**: Intl package for internationalization
- **Permissions**: Permission Handler
- **Architecture**: Service-oriented with separation of concerns

## 📦 Installation
<img src="screenshots/moodflow_icon.png" alt="MoodFlow Icon" width="64">

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Android Studio / VS Code
- Android SDK (for Android development)
- Xcode (for iOS development, macOS only)

### Setup
1. Clone the repository:
```bash
git clone https://github.com/yourusername/moodflow.git
cd moodflow
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Platform-Specific Setup

#### Android
- Minimum SDK: 21 (Android 5.0)
- Target SDK: Latest
- Notification permissions are handled automatically

#### iOS
- Minimum iOS: 12.0
- Notification permissions requested on first launch
- Background app refresh recommended for notifications

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/                  # UI screens
│   ├── main_menu_screen.dart
│   ├── mood_log_screen.dart
│   ├── mood_history_screen.dart
│   ├── mood_trends_screen.dart
│   ├── goals_screen.dart
│   ├── ai_analysis_screen.dart
│   ├── settings_screen.dart
│   └── [additional files]
├── services/                 # Business logic
│   ├── ai/                 # AI services
│   ├── animation/           # Animation services
│   ├── data/               # Data management
│   ├── backup/              # Backup services
│   ├── import/               # Import services
│   ├── notifications/           # Notification services
│   └── ui/                 # UI utilities
├── widgets/                 # Reusable components
│   ├── animated_mood_slider.dart
│   ├── mood_line_chart.dart
│   ├── mood_heatmap.dart
│   ├── goal_card.dart
│   └── [additional files]
└── [additional files]
```

## 🎯 Usage

### Daily Mood Tracking
1. **Morning** (Available from 12:00 AM): Log your starting mood and thoughts
2. **Midday** (Available from 12:00 PM): Check in during your day
3. **Evening** (Available from 6:00 PM): Reflect on your day's emotional journey

*(Users can customize access and notification times in the settings)*

### Setting Goals
- Navigate to the Goals screen
- Choose from preset goal types or create custom goals
- Track progress with visual indicators
- Receive notifications for goal milestones

### Viewing Trends
- Access comprehensive charts and statistics
- View mood patterns over different time periods
- Identify your peak emotional times of day
- Track logging streaks and consistency

### AI Analysis
- Currently, requires your own OpenAI API Key
- Specify date ranges to analyze
- Key Insights (Trends for negative and positive moods)
- Recommendations based on given factors (NOT PROFESSIONAL)

## 🔧 Configuration

### Notifications
Customize notification preferences in Settings:
- Morning, midday, and evening reminders
- End-of-day completion notifications
- Goal progress updates
- Streak celebration alerts

### Themes
- **Light Mode**: Clean, bright interface
- **Dark Mode**: Easy on the eyes for evening use
- **Custom Gradients**: Dynamic backgrounds based on mood data

## 🧪 Testing

Run tests with:
```bash
flutter test
```

For integration tests:
```bash
flutter test integration_test
```

## 📊 Data & Privacy

- **Local Storage**: Data stored locally on device using SharedPreferences
- **Cloud Sync**: Your data can be saved through the iCloud and Google Cloud
- **No Analytics**: No user tracking or data collection
- **Export/Import**: Manual backup through device storage access available

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/<feature-name>`)
3. Commit your changes (`git commit -m 'Added a feature hehe'`)
4. Push to the branch (`git push origin feature/<feature-name>`)
5. Open a Pull Request

### Development Guidelines
- Follow Dart/Flutter best practices
- Maintain consistent code formatting
- Add tests for new features
- Update documentation as needed

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🐛 Bug Reports & Feature Requests

Please use the [GitHub Issues](https://github.com/wedrownyelite/moodflow/issues) page to:
- Report bugs with detailed reproduction steps
- Request new features with clear use cases
- Discuss improvements and suggestions

## 📞 Support

For support and questions:
- 📧 Email: oddologyinc@gmail.com
- 💬 Discussions: Use GitHub Discussions for community support

## 🗺️ Roadmap

### Upcoming Features
- [X] Data export/import functionality
- [ ] Mood correlation with weather/activities
- [X] Advanced AI statistical analysis
- [ ] Widget support for home screen
- [X] Backup and sync options
- [ ] Accessibility improvements

### Long-term Goals
- [ ] Machine learning mood predictions
- [ ] Integration with health apps
- [ ] Multi-language support
- [ ] Web companion app
- [ ] Community features (optional)

## 📸 Screenshots

### Main App Flow
| Home Screen | Mood Logging | Dark Mode |
|-------------|--------------|-----------|
| ![Home](screenshots/home.jpg) | ![Logging](screenshots/logging.jpg) | ![Dark Mode](screenshots/dark.jpg) |

### Trends & Analytics
| Trends Overview | Detailed Analytics |
|-----------------|-------------------|
| ![Trends Overview](screenshots/trends1.jpg) | ![Detailed Analytics](screenshots/trends2.jpg) |

### AI Analysis
| AI Analysis | Disclaimer |
|-------------|------------|
| ![AI Analysis](screenshots/aianalyze.jpg) | ![Disclaimer](screenshots/aianalyzedisclaimer.jpg) |

### AI Analysis Results
| Result 1 | Result 2 |
|----------|----------|
| ![Result 1](screenshots/airesult1.jpg) | ![Result 2](screenshots/airesult2.jpg) |

### Backup & Export
| Export | Cloud Backup | Restore |
|--------|--------------|---------|
| ![Export](screenshots/export.jpg) | ![Cloud Backup](screenshots/cloudbackup.jpg) | ![Restore](screenshots/restore.jpg) |


### Goals & Progress
| Goals Dashboard | Goal Details |
|-----------------|--------------|
| ![Goals 1](screenshots/goals1.jpg) | ![Goals 2](screenshots/goals2.jpg) |

### Settings & Customization
| Themes & Basic Notifications | Backup Options | Advanced Notifications |
|------------------------------|----------------|------------------------|
| ![Settings 1](screenshots/settings1.jpg) | ![Settings Backup](screenshots/settingsbackup.jpg) | ![Settings 3](screenshots/settings2.jpg) |



*Extensive notification customization with granular control over reminders, timing, and preferences*

## 🙏 Acknowledgments

- Flutter team for the amazing framework

---

<div align="center">
  <p>Made with ❤️ and Flutter</p>
  <p>
    <a href="#top">Back to Top</a> •
    <a href="https://github.com/wedrownyelite/moodflow/issues">Report Bug</a> •
    <a href="https://github.com/wedrownyelite/moodflow/issues">Request Feature</a>
  </p>
</div>
