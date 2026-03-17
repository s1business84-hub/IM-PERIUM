import Foundation
import Combine
import SwiftData
import SwiftUI
import Speech
import AVFAudio
import Charts

@Model
final class LogEntry {
    var id: UUID
    var date: Date
    var mood: Int
    var notes: String

    init(id: UUID = UUID(), date: Date = .now, mood: Int = 5, notes: String = "") {
        self.id = id
        self.date = date
        self.mood = mood
        self.notes = notes
    }
}

@Model
final class Insight {
    var id: UUID
    var title: String
    var detail: String
    var score: Double

    init(id: UUID = UUID(), title: String, detail: String = "", score: Double = 0) {
        self.id = id
        self.title = title
        self.detail = detail
        self.score = score
    }
}

struct BehaviorPattern: Identifiable {
    let id = UUID()
    let day: String
    let score: Double
    let state: PatternState

    enum PatternState: String {
        case strong = "Strong"
        case unstable = "Unstable"
        case risk = "Risk"

        var color: Color {
            switch self {
            case .strong:
                return Color(red: 0.10, green: 0.58, blue: 0.45)
            case .unstable:
                return Color(red: 0.89, green: 0.61, blue: 0.14)
            case .risk:
                return Color(red: 0.80, green: 0.26, blue: 0.22)
            }
        }
    }
}

struct BehaviorAction: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

struct MetricHighlight: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let note: String
    let color: Color
}

enum SubscriptionTier: String, CaseIterable {
    case free
    case pro

    var title: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        }
    }

    var price: String {
        switch self {
        case .free:
            return "$0"
        case .pro:
            return "$11.99/mo"
        }
    }

    var accent: Color {
        switch self {
        case .free:
            return Color(red: 0.15, green: 0.47, blue: 0.79)
        case .pro:
            return Color(red: 0.05, green: 0.61, blue: 0.51)
        }
    }
}

private let patternSeries: [BehaviorPattern] = [
    BehaviorPattern(day: "Mon", score: 74, state: .strong),
    BehaviorPattern(day: "Tue", score: 68, state: .strong),
    BehaviorPattern(day: "Wed", score: 52, state: .unstable),
    BehaviorPattern(day: "Thu", score: 47, state: .risk),
    BehaviorPattern(day: "Fri", score: 61, state: .unstable),
    BehaviorPattern(day: "Sat", score: 82, state: .strong),
    BehaviorPattern(day: "Sun", score: 78, state: .strong)
]

private let positiveActions: [BehaviorAction] = [
    BehaviorAction(title: "Morning check-ins are consistent", detail: "You review your plan before noon on 6 of the last 7 days."),
    BehaviorAction(title: "Recovery after misses is improving", detail: "When you slip, you return to baseline in one session instead of drifting for the whole day."),
    BehaviorAction(title: "Weekend structure is stronger", detail: "Saturday and Sunday show the highest completion scores and fewer late changes.")
]

private let riskActions: [BehaviorAction] = [
    BehaviorAction(title: "Late-day decisions break routine", detail: "Most drops happen after 7 PM when tasks are chosen reactively instead of from plan."),
    BehaviorAction(title: "Context switching is the main trigger", detail: "You lose momentum after two or more priority changes in the same block."),
    BehaviorAction(title: "Skipped review leads to noisy next day", detail: "When you end a day without a reset, the following morning starts weaker.")
]

private let changeActions: [BehaviorAction] = [
    BehaviorAction(title: "Lock one shutdown ritual", detail: "End each day with a two-minute review and set the first task for tomorrow."),
    BehaviorAction(title: "Cap late work to one objective", detail: "After 7 PM, allow only one planned action and defer everything else."),
    BehaviorAction(title: "Use trigger-based alerts", detail: "Prompt yourself when three task switches happen inside one hour.")
]

private let overviewMetrics: [MetricHighlight] = [
    MetricHighlight(title: "Pattern Score", value: "74%", note: "Up 9% this week", color: Color(red: 0.10, green: 0.58, blue: 0.45)),
    MetricHighlight(title: "Recovery Rate", value: "81%", note: "Faster bounce-back", color: Color(red: 0.15, green: 0.47, blue: 0.79)),
    MetricHighlight(title: "Risk Window", value: "7-9 PM", note: "Highest drift period", color: Color(red: 0.89, green: 0.61, blue: 0.14))
]

struct StartLandingView: View {
    let tier: SubscriptionTier
    let onEnterApp: () -> Void
    let onOpenTracking: () -> Void
    let onOpenLog: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                highlights
                patternSummary
                planCard
            }
            .padding(20)
        }
        .background(AppBackdrop())
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Imperium")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("See the pattern before it becomes the problem.")
                        .font(.title3.weight(.semibold))
                    Text("Behaviour tracking for execution, consistency, recovery, and the exact moments your routine breaks.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TierBadge(tier: tier)
            }

            Button(action: onEnterApp) {
                Label("Enter App", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 12) {
                Button(action: onOpenTracking) {
                    Label("View Behaviour Tracking", systemImage: "waveform.path.ecg.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onOpenLog) {
                    Label("Open Log", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button(action: onUpgrade) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier == .pro ? "Manage Pro" : "Upgrade to Pro")
                            .font(.headline)
                        Text(tier == .pro ? "Advanced pattern reviews are enabled." : "Unlock deeper tracking, pattern history, and guided interventions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.93, blue: 0.82),
                    Color(red: 0.84, green: 0.93, blue: 0.89),
                    Color.white.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color(red: 0.89, green: 0.61, blue: 0.14).opacity(0.18))
                .frame(width: 120, height: 120)
                .offset(x: 28, y: -28)
        }
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "This Week", subtitle: "The highest-signal behavioural summary")
            ForEach(overviewMetrics) { metric in
                InsightCard(title: metric.title, value: metric.value, note: metric.note, color: metric.color)
            }
        }
    }

    private var patternSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pattern Snapshot", subtitle: "Where the system sees stability and drift")
            SurfaceCard {
                Chart(patternSeries) { item in
                    LineMark(
                        x: .value("Day", item.day),
                        y: .value("Score", item.score)
                    )
                    .foregroundStyle(Color(red: 0.12, green: 0.41, blue: 0.67))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", item.day),
                        y: .value("Score", item.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.41, blue: 0.67).opacity(0.28),
                                Color(red: 0.12, green: 0.41, blue: 0.67).opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Day", item.day),
                        y: .value("Score", item.score)
                    )
                    .foregroundStyle(item.state.color)
                }
                .frame(height: 190)

                Text("Saturday and Sunday are stable. Thursday is the recurring failure point and should be treated as an intervention day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Plan Access", subtitle: "Free and Pro tiers")
            SubscriptionPanel(currentTier: tier) { _ in
                onUpgrade()
            }
        }
    }
}

struct DailyLogView: View {
    @State private var date = Date()
    @State private var category = "Focus"
    @State private var intensity: Double = 72
    @State private var notes: String = ""
    @State private var entries: [BehaviorLog] = [
        BehaviorLog(date: .now, category: "Focus", score: 82, notes: "Strong start, one distraction after lunch."),
        BehaviorLog(date: .now.addingTimeInterval(-86_400), category: "Routine", score: 59, notes: "Skipped evening review and drifted."),
        BehaviorLog(date: .now.addingTimeInterval(-172_800), category: "Energy", score: 76, notes: "Recovered quickly after context switch.")
    ]

    private let categories = ["Focus", "Routine", "Energy", "Execution", "Recovery"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Daily Tracking", subtitle: "Log the moment that helped or hurt your pattern")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Current Average")
                                .font(.headline)
                            Spacer()
                            Text("\(averageScore)%")
                                .font(.title2.bold())
                        }

                        ProgressView(value: averageScoreValue)
                            .tint(Color(red: 0.10, green: 0.58, blue: 0.45))

                        Text("Use logs to capture what happened, why it happened, and what changed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        DatePicker("Date", selection: $date, displayedComponents: .date)

                        Picker("Signal", selection: $category) {
                            ForEach(categories, id: \.self) { item in
                                Text(item).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Pattern Score")
                                Spacer()
                                Text("\(Int(intensity))")
                                    .fontWeight(.semibold)
                            }

                            Slider(value: $intensity, in: 0...100, step: 1)
                                .tint(Color(red: 0.12, green: 0.41, blue: 0.67))
                        }

                        TextField("What happened and why?", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)

                        Button {
                            let entry = BehaviorLog(date: date, category: category, score: Int(intensity), notes: notes)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                entries.insert(entry, at: 0)
                            }
                            date = .now
                            category = categories[0]
                            intensity = 72
                            notes = ""
                        } label: {
                            Label("Save Tracking Entry", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Recent Entries", subtitle: "Newest first")
                    ForEach(entries) { entry in
                        SurfaceCard {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.category)
                                        .font(.headline)
                                    Text(entry.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(entry.notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(entry.score)%")
                                    .font(.title3.bold())
                                    .foregroundStyle(entry.score >= 70 ? Color(red: 0.10, green: 0.58, blue: 0.45) : Color(red: 0.80, green: 0.26, blue: 0.22))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppBackdrop())
    }

    private var averageScore: Int {
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0) { $0 + $1.score }
        return total / entries.count
    }

    private var averageScoreValue: Double {
        Double(averageScore) / 100
    }
}

struct InsightsDashboardView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Overview", subtitle: "Your behavioural system at a glance")
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Behaviour Quality")
                            .font(.headline)

                        Chart(patternSeries) { item in
                            BarMark(
                                x: .value("Day", item.day),
                                y: .value("Score", item.score)
                            )
                            .foregroundStyle(item.state.color.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .frame(height: 180)

                        Text("The midweek drop is no longer random. It clusters around higher context switching and weaker shutdown habits.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("What This Means")
                            .font(.headline)

                        Text("You are not failing across the whole week. The breakdown is concentrated in a specific window, which makes it fixable.")
                            .foregroundStyle(.secondary)

                        Divider()

                        Text("Priority")
                            .font(.headline)

                        Text("Stabilize Wednesday and Thursday evenings before trying to optimize the rest of the system.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .background(AppBackdrop())
    }
}

struct BehavioralInsightsView: View {
    let tier: SubscriptionTier
    let onUpgrade: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Behavioural Insights", subtitle: "Tracking patterns, showing what is right, what is wrong, and what to change")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Tracking Status")
                                .font(.headline)
                            Spacer()
                            Label(tier == .pro ? "Live Pattern Review" : "Weekly Tracking", systemImage: tier == .pro ? "bolt.fill" : "calendar")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(tier.accent)
                        }

                        Text("Your behaviour is tracked against consistency, recovery speed, and breakdown windows so the app can show where execution drifts.")
                            .foregroundStyle(.secondary)

                        Chart(patternSeries) { item in
                            LineMark(
                                x: .value("Day", item.day),
                                y: .value("Score", item.score)
                            )
                            .foregroundStyle(Color(red: 0.12, green: 0.41, blue: 0.67))
                            .interpolationMethod(.catmullRom)

                            RuleMark(y: .value("Target", 70))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                        .frame(height: 170)
                    }
                }

                insightColumn(title: "What You're Doing Right", color: Color(red: 0.10, green: 0.58, blue: 0.45), actions: positiveActions)
                insightColumn(title: "Where You're Going Wrong", color: Color(red: 0.80, green: 0.26, blue: 0.22), actions: riskActions)
                insightColumn(title: "What To Change Next", color: Color(red: 0.89, green: 0.61, blue: 0.14), actions: changeActions)

                if tier == .free {
                    SubscriptionPanel(currentTier: tier) { _ in
                        onUpgrade()
                    }
                }
            }
            .padding(20)
        }
        .background(AppBackdrop())
    }

    private func insightColumn(title: String, color: Color, actions: [BehaviorAction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, subtitle: "")
            ForEach(actions) { action in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Circle()
                                .fill(color)
                                .frame(width: 12, height: 12)
                                .padding(.top, 4)
                            Text(action.title)
                                .font(.headline)
                        }

                        Text(action.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @Binding var tier: SubscriptionTier
    let onOpenLanding: () -> Void

    @State private var notificationsOn = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Settings", subtitle: "Controls and access")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Enable Tracking Reminders", isOn: $notificationsOn)

                        Button("Show Start Landing Page") {
                            onOpenLanding()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                SubscriptionPanel(currentTier: tier) { selectedTier in
                    tier = selectedTier
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                        LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        Text("Imperium is focused on tracking, reflection, and behaviour change. It does not move money or connect to external accounts.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .background(AppBackdrop())
    }
}

private struct SubscriptionPanel: View {
    let currentTier: SubscriptionTier
    let onSelect: (SubscriptionTier) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                Button {
                    onSelect(tier)
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(tier.title)
                                    .font(.headline)
                                Text(tier.price)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(tier.accent)
                            }

                            Text(description(for: tier))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: currentTier == tier ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(currentTier == tier ? tier.accent : .secondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(currentTier == tier ? 0.94 : 0.72))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(tier.accent.opacity(currentTier == tier ? 0.75 : 0.18), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func description(for tier: SubscriptionTier) -> String {
        switch tier {
        case .free:
            return "Daily tracking, weekly behaviour summary, and core insight cards."
        case .pro:
            return "Advanced pattern history, deeper failure analysis, and guided change recommendations."
        }
    }
}

private struct TierBadge: View {
    let tier: SubscriptionTier

    var body: some View {
        Text(tier.title)
            .font(.footnote.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tier.accent.opacity(0.16), in: Capsule())
            .foregroundStyle(tier.accent)
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.bold())

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct InsightCard: View {
    let title: String
    let value: String
    let note: String
    let color: Color

    var body: some View {
        SurfaceCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(color)
            }
        }
    }
}

private struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
    }
}

private struct AppBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.92, blue: 0.84),
                    Color(red: 0.88, green: 0.94, blue: 0.92),
                    Color(red: 0.91, green: 0.94, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.95, green: 0.72, blue: 0.20).opacity(0.18))
                .frame(width: 240, height: 240)
                .offset(x: -130, y: -280)
                .blur(radius: 10)

            Circle()
                .fill(Color(red: 0.12, green: 0.41, blue: 0.67).opacity(0.12))
                .frame(width: 300, height: 300)
                .offset(x: 150, y: 260)
                .blur(radius: 12)
        }
    }
}

struct ContentView: View {
    @AppStorage("subscriptionTier") private var storedTier: String = SubscriptionTier.free.rawValue
    @State private var isShowingLanding = true
    @StateObject private var voice = VoiceController()
    @StateObject private var app = AppViewModel()

    private let accent = Color(red: 0.12, green: 0.41, blue: 0.67)
    private let router = VoiceCommandRouter()

    private var selectedTierBinding: Binding<SubscriptionTier> {
        Binding(
            get: { SubscriptionTier(rawValue: storedTier) ?? .free },
            set: { storedTier = $0.rawValue }
        )
    }

    var body: some View {
        Group {
            if isShowingLanding {
                StartLandingView(
                    tier: selectedTierBinding.wrappedValue,
                    onEnterApp: {
                        app.currentTab = .dashboard
                        isShowingLanding = false
                    },
                    onOpenTracking: {
                        app.currentTab = .analysis
                        isShowingLanding = false
                    },
                    onOpenLog: {
                        app.currentTab = .log
                        isShowingLanding = false
                    },
                    onUpgrade: { selectedTierBinding.wrappedValue = .pro }
                )
            } else {
                TabView(selection: $app.currentTab) {
                    NavigationStack {
                        DailyLogView()
                            .navigationTitle("Log")
                    }
                    .tabItem { Label("Log", systemImage: "square.and.pencil") }
                    .tag(AppTab.log)

                    NavigationStack {
                        InsightsDashboardView()
                            .navigationTitle("Overview")
                    }
                    .tabItem { Label("Overview", systemImage: "chart.bar.xaxis") }
                    .tag(AppTab.dashboard)

                    NavigationStack {
                        BehavioralInsightsView(
                            tier: selectedTierBinding.wrappedValue,
                            onUpgrade: { selectedTierBinding.wrappedValue = .pro }
                        )
                        .navigationTitle("Tracking")
                    }
                    .tabItem { Label("Tracking", systemImage: "waveform.path.ecg.rectangle") }
                    .badge(selectedTierBinding.wrappedValue == .free ? "Pro" : nil)
                    .tag(AppTab.analysis)

                    NavigationStack {
                        SettingsView(
                            tier: selectedTierBinding,
                            onOpenLanding: {
                                app.currentTab = .home
                                isShowingLanding = true
                            }
                        )
                        .navigationTitle("Settings")
                    }
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(AppTab.settings)
                }
            }
        }
        .tint(accent)
        .overlay(alignment: .top) {
            if let message = app.banner {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThickMaterial, in: Capsule())
                    .padding(.top, 12)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if voice.isRecording || !voice.transcript.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                    Text(voice.transcript.isEmpty ? "Listening..." : voice.transcript)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    if voice.isRecording {
                        voice.stop()
                    } else {
                        try? voice.start()
                    }
                } label: {
                    Label(voice.isRecording ? "Stop" : "Listen", systemImage: voice.isRecording ? "mic.circle.fill" : "mic.circle")
                }
                .disabled(!voice.isAuthorized)
                .help("Enable speech recognition permissions to use voice navigation.")
            }
        }
        .onAppear {
            voice.requestAuthorization()
        }
        .onChange(of: voice.isRecording) { _, newValue in
            if newValue == false && !voice.transcript.isEmpty {
                router.route(transcript: voice.transcript, to: app)
            }
        }
        .onChange(of: voice.transcript) { _, newValue in
            if voice.isRecording, newValue.count > 12 {
                router.route(transcript: newValue, to: app)
            }
        }
        .onChange(of: app.currentTab) { _, newValue in
            isShowingLanding = (newValue == .home)
        }
    }
}

final class VoiceController: ObservableObject {
    @Published var isAuthorized = false
    @Published var isRecording = false
    @Published var transcript: String = ""

    private func hasRequiredPrivacyStrings() -> Bool {
        #if canImport(Speech)
        let hasSpeech = Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") != nil
        #if os(iOS) || os(tvOS) || os(visionOS)
        let hasMic = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil
        #else
        let hasMic = true
        #endif
        return hasSpeech && hasMic
        #else
        return false
        #endif
    }

    #if canImport(Speech)
    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    #endif

    func requestAuthorization() {
        #if canImport(Speech)
        guard hasRequiredPrivacyStrings() else {
            DispatchQueue.main.async { self.isAuthorized = false }
            return
        }
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.isAuthorized = (status == .authorized)
            }
        }
        #else
        isAuthorized = false
        #endif
    }

    func start() throws {
        #if canImport(Speech)
        guard hasRequiredPrivacyStrings() else { return }
        guard !isRecording else { return }
        try configureSessionIfNeeded()
        transcript = ""
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        let inputNode = audioEngine.inputNode
        request.shouldReportPartialResults = true
        task = recognizer?.recognitionTask(with: request) { result, error in
            if let result {
                DispatchQueue.main.async { self.transcript = result.bestTranscription.formattedString }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stop()
            }
        }
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.request?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        DispatchQueue.main.async { self.isRecording = true }
        #endif
    }

    func stop() {
        #if canImport(Speech)
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        #endif
        DispatchQueue.main.async { self.isRecording = false }
    }

    #if canImport(Speech)
    private func configureSessionIfNeeded() throws {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }
    #endif
}

struct BehaviorLog: Identifiable {
    let id = UUID()
    let date: Date
    let category: String
    let score: Int
    let notes: String
}

#Preview {
    ContentView()
}
