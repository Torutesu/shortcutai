//
//  AppLanguage.swift
//  typo
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case japanese

    static let storageKey = "shortcutai_app_language"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .english:
            return Locale(identifier: "en")
        case .japanese:
            return Locale(identifier: "ja")
        }
    }

    var displayKey: String {
        switch self {
        case .system:
            return "System"
        case .english:
            return "English"
        case .japanese:
            return "Japanese"
        }
    }

    static var current: AppLanguage {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        return AppLanguage(rawValue: stored ?? "") ?? .system
    }
}

