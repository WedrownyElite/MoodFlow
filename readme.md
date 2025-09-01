<div align="center">
  <img src="screenshots/moodflow_banner.png" alt="MoodFlow Banner" style="width:100%; max-height:500px; object-fit:cover; border-radius:12px;">
</div>

# MoodFlow 🌟

<img src="screenshots/moodflow_icon.png" alt="MoodFlow Icon" width="128">

[![Release](https://img.shields.io/github/v/release/wedrownyelite/MoodFlow)](https://github.com/wedrownyelite/MoodFlow/releases/latest)
[![License: MoodFlow](https://img.shields.io/badge/License-MoodFlow-blue.svg)](LICENSE)
[![Issues](https://img.shields.io/github/issues/wedrownyelite/MoodFlow)](https://github.com/wedrownyelite/MoodFlow/issues)
[![Flutter](https://img.shields.io/badge/Flutter-3.8.1-blue)](https://flutter.dev)

## 📝 License

This project is licensed under the **MoodFlow License**.

**TL;DR:**
- ✅ Free for personal, educational, and research use
- ✅ Modification and redistribution allowed with attribution and inclusion of this license
- ❌ Commercial use prohibited
- ❌ Rebranding or publishing as a different app prohibited

See the full [LICENSE](LICENSE) file for complete terms.

# 🌟 Track. Understand. Improve. 🌟
MoodFlow is a **smart mood tracking app** that helps you:


* 🌅 Track your mood throughout the day (morning, midday, evening)
* 📊 Visualize trends with charts & insights
* 🤖 Get personalized advice with the AI Coach
* 🌤️ Plan your day with mood forecasting

## 📥 Get MoodFlow Now

[![Download APK](https://img.shields.io/badge/Download-APK-brightgreen)](https://github.com/wedrownyelite/MoodFlow/releases/latest)

## 🤔 Why MoodFlow?

* Quickly identify emotional patterns
* Plan your day using AI-powered insights
* Track lifestyle factors affecting your mood
* No ads, no hidden tracking — fully private

## 📱 Features

### Core Functionality

* 🌞 **Morning, Midday, Evening Tracking** – Track moods in multiple segments
* 😃 **Visual Mood Rating** – Emoji-based 1–10 slider
* 📝 **Notes & Journaling** – Record thoughts and reflections
* 📈 **Trends & Analytics** – Charts, heatmaps, and streaks

### Smart Features

* 🔔 **Intelligent Notifications** – Context-aware reminders for mood logging
* 🎯 **Goal Setting & Tracking** – Personalized goals with progress monitoring
* ⏰ **Time-Based Access** – Morning, midday, evening logging unlocks
* 📊 **Statistics Dashboard** – Comprehensive insights including streaks and averages
* 🌗 **Dark/Light Mode** – Adaptive themes with gradient backgrounds

### AI Analysis ✨

| Feature             | Description                                                        |
| ------------------- | ------------------------------------------------------------------ |
| AI-Powered Insights | Leverage OpenAI to receive intelligent summaries and mood analysis |
| Custom API Key      | Add your own OpenAI key for private usage                          |
| Production Plan     | Use your own key or MoodFlow’s managed key                         |
| Future Updates      | Choose AI models and providers                                     |

### Correlations & Insights 🔎

* ☀️ **Weather Integration** – Auto-fetch weather data
* 💤 **Sleep Tracking** – Monitor sleep quality and duration
* 🏃 **Activity Monitoring** – Track exercise and social activities
* 💼 **Lifestyle Factors** – Log work stress, custom tags, notes
* 📈 **Smart Analytics** – Discover correlations between factors and mood
* 📅 **Pattern Recognition** – Weekly trends, time-of-day patterns

### Forecast & AI Coach 🌤️🧑‍🏫 *(New)*

| Feature       | Description                                                     |
| ------------- | --------------------------------------------------------------- |
| Mood Forecast | Predict tomorrow’s probable mood & planning tips                |
| AI Coach      | Chat with AI using your mood logs, sleep, weather & stress data |
| Customization | Control max response length and choose shared data              |

> 💡 **Tip:** Use AI Coach to reflect on patterns and plan a better day!

### User Experience

* 🎨 **Blur Transitions** – Smooth navigation animations
* 📱 **Responsive Design** – Optimized for all screen sizes
* 💾 **Offline Support** – Local data storage
* ✍️ **Manual Entry** – Add historical mood data

## 🛠️ Technology Stack

* **Framework**: Flutter 3.8.1+
* **Language**: Dart
* **Local Storage**: SharedPreferences
* **Notifications**: Flutter Local Notifications
* **Date/Time**: Intl package
* **Permissions**: Permission Handler
* **Architecture**: Service-oriented

<details>
<summary>📦 Installation & Setup</summary>

### Prerequisites

* Flutter SDK 3.8.1+
* Dart SDK
* Android Studio / VS Code
* Android SDK (for Android)
* Xcode (for iOS)

### Setup

```bash
git clone https://github.com/wedrownyelite/MoodFlow.git
cd moodflow
flutter pub get
flutter run
```

#### Android

* Minimum SDK: 21
* Target SDK: Latest

#### iOS

* Minimum iOS: 12.0
* Background refresh recommended

</details>

<details>
<summary>🏗️ Project Structure</summary>

```
lib/
├── main.dart
├── screens/
├── services/
├── widgets/
└── [additional files]
```

</details>

## 🎯 Usage

<details>
<summary>Daily Mood Tracking</summary>

1. Morning: Log starting mood
2. Midday: Check-in
3. Evening: Reflect on your day

</details>

<details>
<summary>Setting Goals</summary>
- Navigate to Goals screen
- Choose preset or custom goals
- Track progress with notifications
</details>

<details>
<summary>Viewing Trends</summary>
- Charts and statistics
- Mood patterns over time
- Peak emotional times and streaks
</details>

<details>
<summary>AI Analysis</summary>
- Requires OpenAI API Key
- Specify date ranges
- Get trends and recommendations
</details>

## 🔧 Configuration

<details>
<summary>Notifications & Themes</summary>
- Custom reminders and alerts
- Light/Dark Mode with gradients
</details>

## 📊 Data & Privacy

* 💾 Local Storage (SharedPreferences)
* ☁️ Optional Cloud Sync (iCloud/Google Cloud)
* ❌ No analytics tracking
* 🔄 Export/Import available

## 📸 Screenshots

### Main App Flow

| Home                          | Mood Logging                        | Dark Mode                          |
| ----------------------------- | ----------------------------------- | ---------------------------------- |
| ![Home](screenshots/home.jpg) | ![Logging](screenshots/logging.jpg) | ![Dark Mode](screenshots/dark.jpg) |

### Daily Factors

| Sleep                                        | Weather                                          | Activity                                           | Work Stress                                         |
| -------------------------------------------- | ------------------------------------------------ | -------------------------------------------------- | --------------------------------------------------- |
| ![Sleep](screenshots/dailyfactors_sleep.jpg) | ![Weather](screenshots/dailyfactors_weather.jpg) | ![Activity](screenshots/dailyfactors_activity.jpg) | ![Work Stress](screenshots/dailyfactors_stress.jpg) |

### Insights & AI Coach

| Insights Overview                                       | Mood Forecast                                       | Correlation Patterns                                   | Insights Summary                                      | AI Coach                                      |
| ------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------ | ----------------------------------------------------- | --------------------------------------------- |
| ![Insights Overview](screenshots/insights_overview.jpg) | ![Mood Forecast](screenshots/insights_forecast.jpg) | ![Correlations](screenshots/insights_correlations.jpg) | ![Insights Summary](screenshots/insights_summary.jpg) | ![AI Coach](screenshots/insights_aicoach.jpg) |

### Trends & Analytics

| Overview                           | Detailed                             |
| ---------------------------------- | ------------------------------------ |
| ![Trends](screenshots/trends1.jpg) | ![Detailed](screenshots/trends2.jpg) |

### AI Analysis

| Analysis                                  | Disclaimer                                         |
| ----------------------------------------- | -------------------------------------------------- |
| ![AI Analysis](screenshots/aianalyze.jpg) | ![Disclaimer](screenshots/aianalyzedisclaimer.jpg) |

### Backup & Export

| Export                            | Cloud Backup                                 | Restore                             |
| --------------------------------- | -------------------------------------------- | ----------------------------------- |
| ![Export](screenshots/export.jpg) | ![Cloud Backup](screenshots/cloudbackup.jpg) | ![Restore](screenshots/restore.jpg) |

### Goals & Progress

| Dashboard                        | Details                            |
| -------------------------------- | ---------------------------------- |
| ![Goals](screenshots/goals1.jpg) | ![Details](screenshots/goals2.jpg) |

### Settings & Customization

| Themes                               | Backup                                    | Notifications                          |
| ------------------------------------ | ----------------------------------------- | -------------------------------------- |
| ![Themes](screenshots/settings1.jpg) | ![Backup](screenshots/settingsbackup.jpg) | ![Advanced](screenshots/settings2.jpg) |

## 🙏 Acknowledgments

* Flutter team for the amazing framework

---

<div align="center">
<p>Made with ❤️ and Flutter</p>
<p>
<a href="#top">Back to Top</a> • <a href="https://github.com/wedrownyelite/moodflow/issues">Report Bug</a> • <a href="https://github.com/wedrownyelite/moodflow/issues">Request Feature</a>
</p>
</div>
