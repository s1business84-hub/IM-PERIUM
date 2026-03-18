import Foundation

struct VoiceCommandRouter {
    func route(transcript raw: String, to viewModel: AppViewModel) {
        let text = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if text.contains("open settings") || text == "settings" {
            viewModel.currentTab = .settings
            viewModel.showBanner("Command recognized: Open Settings")
        } else if text.contains("open log") || text == "log" {
            viewModel.currentTab = .log
            viewModel.showBanner("Command recognized: Open Log")
        } else if text.contains("run analysis") || text.contains("analysis") {
            viewModel.currentTab = .analysis
            viewModel.showBanner("Command recognized: Open Tracking")
        } else if text.contains("show dashboard") || text.contains("dashboard") || text.contains("overview") {
            viewModel.currentTab = .dashboard
            viewModel.showBanner("Command recognized: Show Overview")
        } else if text.contains("landing") || text.contains("home") || text.contains("open landing") {
            viewModel.currentTab = .home
            viewModel.showBanner("Command recognized: Open Landing")
        } else if text.contains("clear transcript") || text.contains("clear") {
            viewModel.showBanner("Transcript cleared")
        } else {
            // Unrecognized: no banner to avoid noise, or show a subtle hint if desired
        }
    }
}
