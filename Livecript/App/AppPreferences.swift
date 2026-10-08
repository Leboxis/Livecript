import SwiftUI
import Observation

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { switch self { case .system: "Système"; case .light: "Clair"; case .dark: "Sombre" } }
    var scheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
}
@MainActor @Observable final class AppPreferences {
    var theme: AppTheme { didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") } }
    var mode: RecognitionMode { didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode") } }
    var localeIdentifier: String { didSet { UserDefaults.standard.set(localeIdentifier, forKey: "locale") } }
    init() {
        theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "system") ?? .system
        mode = RecognitionMode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "standard") ?? .standard
        localeIdentifier = UserDefaults.standard.string(forKey: "locale") ?? "fr-FR"
    }
}
