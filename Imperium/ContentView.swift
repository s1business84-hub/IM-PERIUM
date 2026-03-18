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
            return "$45/mo"
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

enum CheckInMoment: String, CaseIterable, Hashable {
    case morning
    case midday
    case evening
    case closeDown

    var title: String {
        switch self {
        case .morning:
            return "Morning"
        case .midday:
            return "Midday"
        case .evening:
            return "Evening"
        case .closeDown:
            return "Close-Down"
        }
    }

    var icon: String {
        switch self {
        case .morning:
            return "sunrise.fill"
        case .midday:
            return "sun.max.fill"
        case .evening:
            return "sunset.fill"
        case .closeDown:
            return "moon.stars.fill"
        }
    }
}

enum CheckInCategory: String, CaseIterable, Hashable {
    case execution
    case spending
    case debt
    case focus
    case recovery

    var title: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .execution:
            return "flag.fill"
        case .spending:
            return "creditcard.fill"
        case .debt:
            return "chart.line.downtrend.xyaxis"
        case .focus:
            return "scope"
        case .recovery:
            return "heart.text.square.fill"
        }
    }
}

enum CheckInStatus: String, CaseIterable, Hashable {
    case onTrack
    case mixed
    case atRisk

    var title: String {
        switch self {
        case .onTrack:
            return "On Track"
        case .mixed:
            return "Mixed"
        case .atRisk:
            return "At Risk"
        }
    }

    var score: Int {
        switch self {
        case .onTrack:
            return 86
        case .mixed:
            return 63
        case .atRisk:
            return 39
        }
    }

    var color: Color {
        switch self {
        case .onTrack:
            return Color(red: 0.10, green: 0.58, blue: 0.45)
        case .mixed:
            return Color(red: 0.89, green: 0.61, blue: 0.14)
        case .atRisk:
            return Color(red: 0.80, green: 0.26, blue: 0.22)
        }
    }
}

enum EntrySource: String {
    case voice
    case typed
}

struct GuidedPrompt: Identifiable, Hashable {
    let id = UUID()
    let moment: CheckInMoment
    let category: CheckInCategory
    let question: String
    let hint: String
}

struct DailyCheckInEntry: Identifiable {
    let id = UUID()
    let date: Date
    let prompt: GuidedPrompt
    let status: CheckInStatus
    let response: String
    let source: EntrySource
}

struct MetricHighlight: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let note: String
    let color: Color
}

struct CategorySnapshot: Identifiable {
    let id = UUID()
    let category: CheckInCategory
    let averageScore: Int
    let entryCount: Int
    let summary: String
}

struct BehaviorPattern: Identifiable {
    let id = UUID()
    let day: String
    let score: Double
    let color: Color
}

struct BehaviorAction: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

struct PromptFreeAction: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let category: CheckInCategory
    let status: CheckInStatus
    let response: String
}

struct AutoInsight: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
}

final class DailyCheckInStore: ObservableObject {
    @Published var entries: [DailyCheckInEntry]
    @Published var selectedPromptIndex = 0

    private var pendingVoicePrompt: GuidedPrompt?
    private var pendingVoiceStatus: CheckInStatus = .mixed

    init(entries: [DailyCheckInEntry] = DailyCheckInStore.seedEntries()) {
        self.entries = entries
    }

    var todayPrompts: [GuidedPrompt] {
        let riskTitle = riskiestCategory?.title.lowercased() ?? "spending"
        return [
            GuidedPrompt(
                moment: .morning,
                category: .execution,
                question: "What is the one outcome that matters most this morning, and what could derail it?",
                hint: "Your stronger days start when the first task is decided early."
            ),
            GuidedPrompt(
                moment: .midday,
                category: .spending,
                question: "Any spending decisions yet? What have you bought, delayed, or talked yourself into today?",
                hint: "This week the highest pressure is around \(riskTitle)."
            ),
            GuidedPrompt(
                moment: .evening,
                category: .debt,
                question: "Any interest accumulation, debt pressure, or repeated spending building up today?",
                hint: "Call out where money is compounding against you before it becomes a weekly problem."
            ),
            GuidedPrompt(
                moment: .closeDown,
                category: .recovery,
                question: "Where did you go off-plan today, what still feels right, and what changes tomorrow?",
                hint: "Close the day with one adjustment instead of vague reflection."
            )
        ]
    }

    var todayEntries: [DailyCheckInEntry] {
        entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
    }

    var weeklyEntries: [DailyCheckInEntry] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return entries }
        return entries.filter { $0.date >= start }
    }

    var answeredPromptCount: Int {
        todayEntries.count
    }

    var hasPendingVoiceCapture: Bool {
        pendingVoicePrompt != nil
    }

    var currentPrompt: GuidedPrompt {
        let prompts = todayPrompts
        let index = min(selectedPromptIndex, max(prompts.count - 1, 0))
        return prompts[index]
    }

    var summaryHighlights: [MetricHighlight] {
        [
            MetricHighlight(
                title: "Answered Today",
                value: "\(answeredPromptCount)/\(todayPrompts.count)",
                note: answeredPromptCount == todayPrompts.count ? "All daily prompts covered" : "Keep answering through the day",
                color: Color(red: 0.15, green: 0.47, blue: 0.79)
            ),
            MetricHighlight(
                title: "Weekly Pattern Score",
                value: "\(weeklyAverageScore)%",
                note: weakMomentSummary,
                color: Color(red: 0.10, green: 0.58, blue: 0.45)
            ),
            MetricHighlight(
                title: "Overspend Risk",
                value: riskiestCategory?.title ?? "Stable",
                note: "Most pressure this week is in \(riskiestCategory?.title.lowercased() ?? "execution")",
                color: Color(red: 0.89, green: 0.61, blue: 0.14)
            )
        ]
    }

    var categorySnapshots: [CategorySnapshot] {
        CheckInCategory.allCases.compactMap { category in
            let categoryEntries = weeklyEntries.filter { $0.prompt.category == category }
            guard !categoryEntries.isEmpty else { return nil }
            let average = categoryEntries.map(\.status.score).reduce(0, +) / categoryEntries.count
            let latest = categoryEntries.sorted(by: { $0.date > $1.date }).first?.response ?? "No detail captured."
            return CategorySnapshot(
                category: category,
                averageScore: average,
                entryCount: categoryEntries.count,
                summary: latest
            )
        }
        .sorted { $0.averageScore < $1.averageScore }
    }

    var patternSeries: [BehaviorPattern] {
        let calendar = Calendar.current
        let weekdaySymbols = calendar.shortWeekdaySymbols
        let grouped = Dictionary(grouping: weeklyEntries) { entry in
            calendar.component(.weekday, from: entry.date)
        }

        return weekdaySymbols.enumerated().map { index, name in
            let key = index + 1
            let dayEntries = grouped[key, default: []]
            let average = dayEntries.isEmpty ? 0 : dayEntries.map(\.status.score).reduce(0, +) / dayEntries.count
            let color: Color
            switch average {
            case 75...:
                color = CheckInStatus.onTrack.color
            case 50..<75:
                color = CheckInStatus.mixed.color
            default:
                color = CheckInStatus.atRisk.color
            }
            return BehaviorPattern(day: name, score: Double(average), color: color)
        }
    }

    var positiveActions: [BehaviorAction] {
        let stableCategories = categorySnapshots.filter { $0.averageScore >= 70 }
        let first = stableCategories.first?.category.title ?? "Execution"
        return [
            BehaviorAction(title: "\(first) is holding up", detail: "Your strongest category is \(first.lowercased()), which means part of the system is already repeatable."),
            BehaviorAction(title: "Voice capture reduces friction", detail: "Answers can be spoken instead of manually logged, so the app keeps collecting context through the day."),
            BehaviorAction(title: "Daily prompts are timed", detail: "Morning, midday, evening, and close-down questions create a consistent rhythm every day.")
        ]
    }

    var riskActions: [BehaviorAction] {
        let weakCategory = riskiestCategory?.title ?? "Spending"
        return [
            BehaviorAction(title: "\(weakCategory) is dragging the week", detail: "This category has the lowest average score and is where most at-risk answers are clustering."),
            BehaviorAction(title: "Midday decisions are noisy", detail: "The day gets less structured once reactive spending or changing priorities shows up."),
            BehaviorAction(title: "Close-down reflection is missing", detail: "Days with no end-of-day answer are more likely to start weak the next morning.")
        ]
    }

    var changeActions: [BehaviorAction] {
        [
            BehaviorAction(title: "Answer every prompt in under 30 seconds", detail: "Keep the check-in lightweight so the data stays daily instead of becoming another task."),
            BehaviorAction(title: "Use voice mode for high-friction moments", detail: "When you are moving fast, speak the answer and let the app capture the entry."),
            BehaviorAction(title: "Correct the weakest category first", detail: "Start with \(riskiestCategory?.title.lowercased() ?? "spending") before optimizing the rest of the system.")
        ]
    }

    var dailySummaryText: String {
        guard !todayEntries.isEmpty else {
            return "No answers logged yet today. Start with the morning question and keep each response short."
        }

        let onTrackCount = todayEntries.filter { $0.status == .onTrack }.count
        let atRiskCount = todayEntries.filter { $0.status == .atRisk }.count
        let categories = Set(todayEntries.map { $0.prompt.category.title }).sorted().joined(separator: ", ")
        return "Today you answered \(todayEntries.count) prompts across \(categories). \(onTrackCount) are on track and \(atRiskCount) are at risk."
    }

    var promptFreeActions: [PromptFreeAction] {
        [
            PromptFreeAction(
                title: "No extra spend",
                detail: "Capture a clean spending decision without typing.",
                category: .spending,
                status: .onTrack,
                response: "No extra spending today. I stayed with the plan."
            ),
            PromptFreeAction(
                title: "Impulse spend",
                detail: "Log a fast spending slip in one tap.",
                category: .spending,
                status: .atRisk,
                response: "Impulse spending showed up today and needs review tonight."
            ),
            PromptFreeAction(
                title: "Interest pressure",
                detail: "Mark debt or interest build-up immediately.",
                category: .debt,
                status: .atRisk,
                response: "Interest pressure is building and needs action this week."
            ),
            PromptFreeAction(
                title: "Locked in",
                detail: "Capture strong execution without filling a prompt.",
                category: .execution,
                status: .onTrack,
                response: "Execution stayed tight and I followed the planned task flow."
            )
        ]
    }

    var autoInsights: [AutoInsight] {
        [
            AutoInsight(
                title: "Passive spending watch",
                detail: "Spending answers are showing more pressure than execution this week.",
                icon: "creditcard.trianglebadge.exclamationmark"
            ),
            AutoInsight(
                title: "Close-down weakness detected",
                detail: weakMomentSummary,
                icon: "moon.zzz.fill"
            ),
            AutoInsight(
                title: "Fast capture is working",
                detail: "Voice and one-tap entries are reducing manual logging friction.",
                icon: "waveform.badge.mic"
            )
        ]
    }

    var riskiestCategory: CheckInCategory? {
        categorySnapshots.first?.category
    }

    var weakMomentSummary: String {
        let closeDownEntries = weeklyEntries.filter { $0.prompt.moment == .closeDown }
        guard !closeDownEntries.isEmpty else { return "Need more close-down check-ins" }
        let average = closeDownEntries.map(\.status.score).reduce(0, +) / closeDownEntries.count
        return average < 60 ? "Close-down is your weakest moment" : "Close-down is holding steady"
    }

    var weeklyAverageScore: Int {
        guard !weeklyEntries.isEmpty else { return 0 }
        return weeklyEntries.map(\.status.score).reduce(0, +) / weeklyEntries.count
    }

    func entryForToday(prompt: GuidedPrompt) -> DailyCheckInEntry? {
        todayEntries.first { $0.prompt.moment == prompt.moment }
    }

    func saveResponse(for prompt: GuidedPrompt, status: CheckInStatus, response: String, source: EntrySource) {
        entries.removeAll {
            Calendar.current.isDateInToday($0.date) && $0.prompt.moment == prompt.moment
        }
        entries.append(
            DailyCheckInEntry(
                date: .now,
                prompt: prompt,
                status: status,
                response: response.isEmpty ? "No detail captured." : response,
                source: source
            )
        )
        advancePrompt()
    }

    func savePromptFreeAction(_ action: PromptFreeAction) {
        let prompt = GuidedPrompt(
            moment: inferredMoment,
            category: action.category,
            question: action.title,
            hint: action.detail
        )
        entries.append(
            DailyCheckInEntry(
                date: .now,
                prompt: prompt,
                status: action.status,
                response: action.response,
                source: .typed
            )
        )
    }

    func advancePrompt() {
        if selectedPromptIndex < todayPrompts.count - 1 {
            selectedPromptIndex += 1
        }
    }

    func prepareVoiceCapture(for prompt: GuidedPrompt, status: CheckInStatus) {
        pendingVoicePrompt = prompt
        pendingVoiceStatus = status
    }

    func capturePendingVoiceResponse(_ transcript: String) -> Bool {
        guard let prompt = pendingVoicePrompt else { return false }
        saveResponse(for: prompt, status: pendingVoiceStatus, response: transcript, source: .voice)
        pendingVoicePrompt = nil
        return true
    }

    func cancelVoiceCapture() {
        pendingVoicePrompt = nil
    }

    private var inferredMoment: CheckInMoment {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case ..<11:
            return .morning
        case 11..<16:
            return .midday
        case 16..<21:
            return .evening
        default:
            return .closeDown
        }
    }

    private static func seedEntries() -> [DailyCheckInEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        func day(_ offset: Int, hour: Int, minute: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        let prompts = [
            GuidedPrompt(moment: .morning, category: .execution, question: "Morning", hint: ""),
            GuidedPrompt(moment: .midday, category: .spending, question: "Midday", hint: ""),
            GuidedPrompt(moment: .evening, category: .debt, question: "Evening", hint: ""),
            GuidedPrompt(moment: .closeDown, category: .recovery, question: "Close", hint: "")
        ]

        return [
            DailyCheckInEntry(date: day(-2, hour: 8), prompt: prompts[0], status: .onTrack, response: "Clear morning target. No drift before noon.", source: .typed),
            DailyCheckInEntry(date: day(-2, hour: 13), prompt: prompts[1], status: .mixed, response: "Bought lunch out and one impulse coffee after a long call.", source: .voice),
            DailyCheckInEntry(date: day(-2, hour: 18), prompt: prompts[2], status: .atRisk, response: "Let card interest sit another day and ordered delivery twice.", source: .voice),
            DailyCheckInEntry(date: day(-2, hour: 22), prompt: prompts[3], status: .mixed, response: "Skipped shutdown routine and started tomorrow without a first task.", source: .typed),
            DailyCheckInEntry(date: day(-1, hour: 8), prompt: prompts[0], status: .onTrack, response: "Locked first objective before messages.", source: .typed),
            DailyCheckInEntry(date: day(-1, hour: 13), prompt: prompts[1], status: .onTrack, response: "No extra spending, stayed with planned lunch.", source: .typed),
            DailyCheckInEntry(date: day(-1, hour: 18), prompt: prompts[2], status: .mixed, response: "Interest pressure still there but no new spend today.", source: .voice),
            DailyCheckInEntry(date: day(-1, hour: 22), prompt: prompts[3], status: .onTrack, response: "Closed the day well and set tomorrow's first task.", source: .typed),
            DailyCheckInEntry(date: day(0, hour: 8), prompt: prompts[0], status: .mixed, response: "Main goal is clear, but meetings may fragment the morning.", source: .voice),
            DailyCheckInEntry(date: day(0, hour: 13), prompt: prompts[1], status: .atRisk, response: "Spent on convenience because the day got rushed.", source: .voice)
        ]
    }
}

enum OverviewTab: String, CaseIterable {
    case daily = "Daily Summary"
    case category = "Category Wise"
    case weekly = "Weekly Pattern"
}

enum TrackingTab: String, CaseIterable {
    case prompts = "Prompt Flow"
    case daily = "Daily Summary"
    case category = "Category Wise"
}

struct StartLandingView: View {
    let tier: SubscriptionTier
    @ObservedObject var store: DailyCheckInStore
    let onEnterApp: () -> Void
    let onOpenTracking: () -> Void
    let onOpenLog: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                highlights
                promptFreePanel
                autoInsightsPanel
                voiceSummary
                planCard
            }
            .padding(20)
        }
        .background(AppBackdrop())
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Imperium")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("Own the day before it owns you.")
                        .font(.title3.weight(.semibold))
                    Text("Voice capture, quick actions, and automatic summaries keep Imperium learning with almost no friction.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TierBadge(tier: tier)
            }

            Button(action: onEnterApp) {
                Label("Open Dashboard", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 12) {
                Button(action: onOpenLog) {
                    Label("Start Daily Check-In", systemImage: "mic.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onOpenTracking) {
                    Label("Open Tracking", systemImage: "waveform.path.ecg.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.93, blue: 0.82),
                    Color(red: 0.84, green: 0.93, blue: 0.89),
                    AppTheme.heroHighlight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Live Summary", subtitle: "Built from daily check-in answers")
            ForEach(store.summaryHighlights) { item in
                InsightCard(title: item.title, value: item.value, note: item.note, color: item.color)
            }
        }
    }

    private var voiceSummary: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Voice-First Flow")
                    .font(.headline)
                Text("Tap voice mode on a prompt, speak your answer, and the app turns that into today’s daily summary and category summary automatically.")
                    .foregroundStyle(.secondary)
                Text(store.dailySummaryText)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var promptFreePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Prompt-Free Capture", subtitle: "One tap when you do not want a full check-in")
            ForEach(store.promptFreeActions) { action in
                SurfaceCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: action.category.icon)
                            .foregroundStyle(action.status.color)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(action.title)
                                .font(.headline)
                            Text(action.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var autoInsightsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Automatic Signals", subtitle: "What the app can infer without asking")
            ForEach(store.autoInsights) { insight in
                SurfaceCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.icon)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(insight.title)
                                .font(.headline)
                            Text(insight.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Plan Access", subtitle: "Free and Pro")
            SubscriptionPanel(currentTier: tier) { _ in
                onUpgrade()
            }
        }
    }
}

struct DailyLogView: View {
    @ObservedObject var store: DailyCheckInStore
    let tier: SubscriptionTier
    let isVoiceRecording: Bool
    let isVoiceAuthorized: Bool
    let transcript: String
    let voiceStatusMessage: String?
    let onVoiceToggle: (GuidedPrompt, CheckInStatus) -> Void

    @State private var selectedStatus: CheckInStatus = .mixed
    @State private var typedAnswer = ""

    var body: some View {
        let prompt = store.currentPrompt
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Daily Check-In", subtitle: "Answer guided questions instead of manually logging everything")

                quickCaptureRow

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(prompt.moment.title, systemImage: prompt.moment.icon)
                                .font(.headline)
                            Spacer()
                            Text(prompt.category.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text(prompt.question)
                            .font(.title3.weight(.semibold))

                        Text(prompt.hint)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Status", selection: $selectedStatus) {
                            ForEach(CheckInStatus.allCases, id: \.self) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField("Type a short answer if you do not want to speak it", text: $typedAnswer, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...5)

                        HStack(spacing: 12) {
                            Button {
                                let answer = typedAnswer.isEmpty ? "Quick check-in captured with no extra detail." : typedAnswer
                                store.saveResponse(for: prompt, status: selectedStatus, response: answer, source: .typed)
                                typedAnswer = ""
                            } label: {
                                Label("Save Typed Answer", systemImage: "square.and.arrow.down.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                onVoiceToggle(prompt, selectedStatus)
                            } label: {
                                Label(isVoiceRecording ? "Stop Voice Mode" : "Start Voice Mode", systemImage: isVoiceRecording ? "waveform.circle.fill" : "mic.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        if let voiceStatusMessage {
                            Text(voiceStatusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if !transcript.isEmpty {
                            Text("Last voice transcript: \(transcript)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                promptSchedule
                todayEntriesCard
                if tier == .free {
                    SubscriptionPanel(currentTier: tier) { _ in }
                }
            }
            .padding(20)
        }
        .background(AppBackdrop())
    }

    private var quickCaptureRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Capture", subtitle: "Prompt-free buttons for the most common events")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.promptFreeActions) { action in
                        Button {
                            store.savePromptFreeAction(action)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(action.title)
                                    .font(.headline)
                                Text(action.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .frame(width: 180, alignment: .leading)
                            .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var promptSchedule: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Prompt Flow", subtitle: "These repeat every day")
            ForEach(Array(store.todayPrompts.enumerated()), id: \.offset) { index, prompt in
                let entry = store.entryForToday(prompt: prompt)
                SurfaceCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: prompt.moment.icon)
                            .foregroundStyle(entry?.status.color ?? .secondary)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(prompt.moment.title)
                                .font(.headline)
                            Text(prompt.question)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(entry?.status.title ?? "Pending")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(entry?.status.color ?? .secondary)
                        }
                        Spacer()
                        if store.selectedPromptIndex == index {
                            Text("Now")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.pillFill, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var todayEntriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Answers", subtitle: "Full daily summary input")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.dailySummaryText)
                        .font(.subheadline)
                    ForEach(store.todayEntries.reversed()) { entry in
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.prompt.moment.title)
                                    .font(.headline)
                                Spacer()
                                Text(entry.status.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(entry.status.color)
                            }
                            Text(entry.response)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(entry.source == .voice ? "Captured via voice mode" : "Captured via typed answer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct InsightsDashboardView: View {
    @ObservedObject var store: DailyCheckInStore
    @State private var selectedTab: OverviewTab = .daily

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Overview", subtitle: "Daily summary, category wise summary, and weekly pattern")

                Picker("Overview Tab", selection: $selectedTab) {
                    ForEach(OverviewTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .daily:
                    dailySummaryView
                case .category:
                    categoryView
                case .weekly:
                    weeklyPatternView
                }
            }
            .padding(20)
        }
        .background(AppBackdrop())
    }

    private var dailySummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(store.summaryHighlights) { item in
                InsightCard(title: item.title, value: item.value, note: item.note, color: item.color)
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Full Daily Summary")
                        .font(.headline)
                    Text(store.dailySummaryText)
                        .foregroundStyle(.secondary)
                    ForEach(store.todayEntries) { entry in
                        Divider()
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(entry.prompt.moment.title) • \(entry.prompt.category.title)")
                                    .font(.headline)
                                Text(entry.response)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(entry.status.score)%")
                                .font(.title3.bold())
                                .foregroundStyle(entry.status.color)
                        }
                    }
                }
            }
        }
    }

    private var categoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(store.categorySnapshots) { snapshot in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(snapshot.category.title, systemImage: snapshot.category.icon)
                                .font(.headline)
                            Spacer()
                            Text("\(snapshot.averageScore)%")
                                .font(.title3.bold())
                                .foregroundStyle(snapshot.averageScore >= 70 ? CheckInStatus.onTrack.color : snapshot.averageScore >= 50 ? CheckInStatus.mixed.color : CheckInStatus.atRisk.color)
                        }
                        Text("Entries this week: \(snapshot.entryCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(snapshot.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var weeklyPatternView: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Weekly Pattern")
                    .font(.headline)
                Chart(store.patternSeries) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Score", item.score)
                    )
                    .foregroundStyle(item.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .frame(height: 220)
                Text(store.weakMomentSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BehavioralInsightsView: View {
    let tier: SubscriptionTier
    @ObservedObject var store: DailyCheckInStore
    let onUpgrade: () -> Void

    @State private var selectedTab: TrackingTab = .prompts

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Tracking", subtitle: "Prompt flow, full daily summary, and category wise tracking")

                Picker("Tracking Tab", selection: $selectedTab) {
                    ForEach(TrackingTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .prompts:
                    promptTrackingView
                case .daily:
                    coachingSummaryView
                case .category:
                    categoryTrackingView
                }

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

    private var promptTrackingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Tracking Status")
                            .font(.headline)
                        Spacer()
                        Label(tier == .pro ? "Pro Review Active" : "Core Tracking", systemImage: tier == .pro ? "bolt.fill" : "calendar")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tier.accent)
                    }

                    Chart(store.patternSeries) { item in
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
                    .frame(height: 180)
                }
            }

            ForEach(store.todayPrompts) { prompt in
                let entry = store.entryForToday(prompt: prompt)
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(prompt.moment.title)
                                .font(.headline)
                            Spacer()
                            Text(entry?.status.title ?? "Pending")
                                .foregroundStyle(entry?.status.color ?? .secondary)
                        }
                        Text(prompt.question)
                            .font(.subheadline)
                        Text(entry?.response ?? "No answer yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var coachingSummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            insightColumn(title: "What You're Doing Right", color: CheckInStatus.onTrack.color, actions: store.positiveActions)
            insightColumn(title: "Where You're Going Wrong", color: CheckInStatus.atRisk.color, actions: store.riskActions)
            insightColumn(title: "What To Change", color: CheckInStatus.mixed.color, actions: store.changeActions)
        }
    }

    private var categoryTrackingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(store.categorySnapshots) { snapshot in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(snapshot.category.title)
                                .font(.headline)
                            Spacer()
                            Text("\(snapshot.averageScore)%")
                                .font(.title3.bold())
                        }
                        Text("Category-wise summary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(snapshot.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
                        Toggle("Enable Daily Check-In Reminders", isOn: $notificationsOn)
                        Button("Show Landing") {
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
                        Text("Imperium gathers daily behavioural data through prompts and voice answers, then turns that into daily and category-wise summaries.")
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
                            .fill(AppTheme.cardFill(selected: currentTier == tier))
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
            return "Voice prompts, daily summary, category wise summary, and core tracking."
        case .pro:
            return "Advanced coaching, deeper pattern reviews, and premium intervention insights."
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
            .background(AppTheme.surfaceFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.surfaceStroke, lineWidth: 1)
            )
    }
}

private struct AppBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark ? AppTheme.darkBackdrop : AppTheme.lightBackdrop,
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

private enum AppTheme {
    static let surfaceFill = platformBackground.opacity(0.86)
    static let surfaceStroke = Color.primary.opacity(0.08)
    static let pillFill = Color.primary.opacity(0.08)
    static let heroHighlight = platformBackground.opacity(0.92)

    static let lightBackdrop: [Color] = [
        Color(red: 0.97, green: 0.92, blue: 0.84),
        Color(red: 0.88, green: 0.94, blue: 0.92),
        Color(red: 0.91, green: 0.94, blue: 0.98)
    ]

    static let darkBackdrop: [Color] = [
        Color(red: 0.10, green: 0.12, blue: 0.16),
        Color(red: 0.08, green: 0.18, blue: 0.20),
        Color(red: 0.12, green: 0.14, blue: 0.22)
    ]

    static func cardFill(selected: Bool) -> Color {
        let base = platformBackground
        return selected ? base.opacity(0.95) : base.opacity(0.76)
    }

    #if os(macOS)
    static let platformBackground = Color(nsColor: .windowBackgroundColor)
    #else
    static let platformBackground = Color(uiColor: .secondarySystemBackground)
    #endif
}

struct ContentView: View {
    @AppStorage("subscriptionTier") private var storedTier: String = SubscriptionTier.free.rawValue
    @State private var isShowingLanding = true
    @State private var voiceStatusMessage: String?
    @StateObject private var voice = VoiceController()
    @StateObject private var app = AppViewModel()
    @StateObject private var store = DailyCheckInStore()

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
                    store: store,
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
                        DailyLogView(
                            store: store,
                            tier: selectedTierBinding.wrappedValue,
                            isVoiceRecording: voice.isRecording,
                            isVoiceAuthorized: voice.isAuthorized,
                            transcript: voice.transcript,
                            voiceStatusMessage: voiceStatusMessage,
                            onVoiceToggle: toggleVoiceForPrompt
                        )
                        .navigationTitle("Check-In")
                    }
                    .tabItem { Label("Check-In", systemImage: "mic.badge.plus") }
                    .tag(AppTab.log)

                    NavigationStack {
                        InsightsDashboardView(store: store)
                            .navigationTitle("Overview")
                    }
                    .tabItem { Label("Overview", systemImage: "chart.bar.xaxis") }
                    .tag(AppTab.dashboard)

                    NavigationStack {
                        BehavioralInsightsView(
                            tier: selectedTierBinding.wrappedValue,
                            store: store,
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
                    Text(voice.isRecording ? "Listening for answer..." : voice.transcript)
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
                        store.cancelVoiceCapture()
                        voiceStatusMessage = "Voice mode stopped."
                        voice.stop()
                    } else {
                        voiceStatusMessage = "Requesting voice access..."
                        try? voice.start()
                    }
                } label: {
                    Label(voice.isRecording ? "Stop" : "Listen", systemImage: voice.isRecording ? "mic.circle.fill" : "mic.circle")
                }
                .disabled(!voice.isAuthorized)
                .help("Use the dedicated voice mode button in Check-In to save spoken answers to prompts.")
            }
        }
        .onAppear {
            voice.requestAuthorization()
        }
        .onChange(of: voice.isAuthorized) { _, newValue in
            if newValue {
                voiceStatusMessage = "Voice mode is ready."
                if store.hasPendingVoiceCapture, !voice.isRecording {
                    try? voice.start()
                }
            } else if store.hasPendingVoiceCapture {
                voiceStatusMessage = "Voice access is unavailable. Enable microphone and speech recognition permissions."
            }
        }
        .onChange(of: voice.isRecording) { _, newValue in
            if newValue == false {
                if !voice.transcript.isEmpty, store.capturePendingVoiceResponse(voice.transcript) {
                    voiceStatusMessage = "Voice answer saved."
                    app.showBanner("Voice answer saved")
                } else if !voice.transcript.isEmpty {
                    voiceStatusMessage = nil
                    router.route(transcript: voice.transcript, to: app)
                } else {
                    voiceStatusMessage = "Voice mode stopped."
                    store.cancelVoiceCapture()
                }
            } else {
                voiceStatusMessage = "Listening for your answer..."
            }
        }
        .onChange(of: voice.transcript) { _, newValue in
            if voice.isRecording, newValue.count > 12, !store.hasPendingVoiceCapture {
                router.route(transcript: newValue, to: app)
            }
        }
        .onChange(of: app.currentTab) { _, newValue in
            isShowingLanding = (newValue == .home)
        }
    }

    private func toggleVoiceForPrompt(_ prompt: GuidedPrompt, status: CheckInStatus) {
        if voice.isRecording {
            voiceStatusMessage = "Voice mode stopped."
            voice.stop()
        } else {
            store.prepareVoiceCapture(for: prompt, status: status)
            guard voice.isAuthorized else {
                voiceStatusMessage = "Requesting microphone and speech access..."
                voice.requestAuthorization()
                return
            }
            voiceStatusMessage = "Listening for your answer..."
            try? voice.start()
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
            #if os(iOS) || os(tvOS) || os(visionOS)
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = (status == .authorized) && granted
                }
            }
            #else
            DispatchQueue.main.async {
                self.isAuthorized = (status == .authorized)
            }
            #endif
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

#Preview {
    ContentView()
}
