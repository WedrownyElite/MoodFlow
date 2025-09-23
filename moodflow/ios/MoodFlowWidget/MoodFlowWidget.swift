import WidgetKit
import SwiftUI

struct MoodFlowWidget: Widget {
    let kind: String = "MoodFlowWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MoodFlowWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MoodFlow")
        .description("Quick mood check-ins throughout your day")
        .supportedFamilies([.systemMedium])
    }
}

struct MoodFlowWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
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
            
            // Progress bar
            ProgressView(value: Double(entry.completionPercentage) / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .frame(height: 8)
            
            // Quick mood buttons
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { mood in
                    Button(action: {
                        // Handle mood tap
                    }) {
                        Image(systemName: moodIcon(for: mood))
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.white.opacity(0.2)))
                    }
                }
            }
            
            // Status
            Text(entry.canLogCurrent ? "Tap a mood to log quickly" : "Current time slot not available")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private func moodIcon(for mood: Int) -> String {
        switch mood {
        case 1: return "face.dashed"
        case 2: return "face.frowning"
        case 3: return "face.expressionless"
        case 4: return "face.smiling"
        case 5: return "face.grinning"
        default: return "face.expressionless"
        }
    }
}