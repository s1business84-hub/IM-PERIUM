import Foundation
import Combine
import SwiftUI

enum AppTab: Hashable {
    case home
    case dashboard
    case log
    case analysis
    case settings
}

final class AppViewModel: ObservableObject {
    @Published var currentTab: AppTab = .home
    @Published var banner: String? = nil

    func showBanner(_ text: String, duration: TimeInterval = 2.0) {
        banner = text
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            // Only clear if unchanged to avoid racing newer banners
            if self.banner == text { self.banner = nil }
        }
    }
}
