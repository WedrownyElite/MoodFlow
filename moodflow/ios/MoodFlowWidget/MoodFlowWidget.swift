import WidgetKit
import SwiftUI

struct MoodFlowWidget: Widget {
    let kind: String = "MoodFlowWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MoodFlowWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MoodFlow")
        .description("Quick mood tracking with emoji selection")
        .supportedFamilies([.systemMedium])
    }
}

struct MoodFlowWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Text("MoodFlow")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(entry.currentSegment)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Current segment question
            Text(entry.segmentQuestion)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
            
            // 5 Emoji mood buttons
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { moodIndex in
                    Button(intent: MoodSelectionIntent(moodIndex: moodIndex, segment: entry.currentSegmentIndex)) {
                        Text(getMoodEmoji(for: moodIndex))
                            .font(.title2)
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(entry.selectedMood == moodIndex ? 
                                          Color.blue.opacity(0.3) : Color.white.opacity(0.2))
                                    .overlay(
                                        Circle()
                                            .stroke(entry.selectedMood == moodIndex ? 
                                                   Color.blue : Color.clear, lineWidth: 2)
                                    )
                            )
                            .scaleEffect(entry.selectedMood == moodIndex ? 1.1 : 1.0)
                            .opacity(entry.canLogCurrent ? 1.0 : 0.5)
                    }
                    .disabled(!entry.canLogCurrent)
                }
            }
            
            // Status text
            Text(entry.canLogCurrent ? "Tap an emoji to log your mood" : "This time slot isn't available yet")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, 2)
            
            // Open app button
            Button(intent: OpenAppIntent(segment: entry.currentSegmentIndex)) {
                Text("Open MoodFlow App")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private func getMoodEmoji(for mood: Int) -> String {
        switch mood {
        case 1: return "😢"
        case 2: return "🙁"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😊"
        default: return "😐"
        }
    }
}

// MARK: - Widget Data Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            currentSegment: "Morning",
            currentSegmentIndex: 0,
            segmentQuestion: "How's your morning going?",
            canLogCurrent: true,
            selectedMood: -1
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(
            date: Date(),
            currentSegment: "Morning",
            currentSegmentIndex: 0,
            segmentQuestion: "How's your morning going?",
            canLogCurrent: true,
            selectedMood: -1
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Get data from UserDefaults (shared with Flutter app)
        let userDefaults = UserDefaults(suiteName: "group.com.oddologyinc.moodflow")
        
        let currentSegmentIndex = userDefaults?.integer(forKey: "current_segment_index") ?? 0
        let canLogCurrent = userDefaults?.bool(forKey: "can_log_current") ?? true
        let selectedMood = userDefaults?.integer(forKey: "selected_mood_\(currentSegmentIndex)") ?? -1
        
        let segmentNames = ["Morning", "Midday", "Evening"]
        let segmentQuestions = [
            "How's your morning going?",
            "How's your midday going?",
            "How's your evening going?"
        ]
        
        let currentSegment = segmentNames[min(currentSegmentIndex, 2)]
        let segmentQuestion = segmentQuestions[min(currentSegmentIndex, 2)]
        
        let entry = SimpleEntry(
            date: Date(),
            currentSegment: currentSegment,
            currentSegmentIndex: currentSegmentIndex,
            segmentQuestion: segmentQuestion,
            canLogCurrent: canLogCurrent,
            selectedMood: selectedMood == -1 ? nil : selectedMood
        )
        
        // Create timeline that updates every 30 minutes
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let currentSegment: String
    let currentSegmentIndex: Int
    let segmentQuestion: String
    let canLogCurrent: Bool
    let selectedMood: Int?
}

// MARK: - App Intents for iOS 17+ Interactive Widgets

@available(iOS 17.0, *)
struct MoodSelectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Select Mood"
    static let description = IntentDescription("Log your mood without opening the app")
    
    @Parameter(title: "Mood Index")
    var moodIndex: Int
    
    @Parameter(title: "Segment")
    var segment: Int
    
    func perform() async throws -> some IntentResult {
        // Save mood selection to UserDefaults
        let userDefaults = UserDefaults(suiteName: "group.com.oddologyinc.moodflow")
        
        // Convert mood index to rating
        let rating: Double = {
            switch moodIndex {
            case 1: return 2.0  // 😢
            case 2: return 4.0  // 🙁
            case 3: return 6.0  // 😐
            case 4: return 8.0  // 🙂
            case 5: return 10.0 // 😊
            default: return 6.0
            }
        }()
        
        userDefaults?.set(moodIndex, forKey: "selected_mood_\(segment)")
        userDefaults?.set(rating, forKey: "widget_mood_rating_\(segment)")
        userDefaults?.set(segment, forKey: "widget_mood_segment")
        userDefaults?.set(Date().timeIntervalSince1970, forKey: "widget_mood_timestamp")
        userDefaults?.set(true, forKey: "widget_mood_pending")
        
        // Reload widget timeline
        WidgetCenter.shared.reloadTimelines(ofKind: "MoodFlowWidget")
        
        return .result()
    }
}

@available(iOS 17.0, *)
struct OpenAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open MoodFlow"
    static let description = IntentDescription("Open the MoodFlow app to log detailed mood")
    
    @Parameter(title: "Segment")
    var segment: Int
    
    func perform() async throws -> some IntentResult {
        // This will open the app with deep linking
        let urlString = "moodflow://mood-log?segment=\(segment)&from_widget=true"
        
        if let url = URL(string: urlString) {
            _ = await UIApplication.shared.open(url)
        }
        
        return .result()
    }
}