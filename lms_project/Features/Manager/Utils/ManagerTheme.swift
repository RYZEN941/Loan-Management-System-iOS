//
//  ManagerTheme.swift
//  lms_project
//

import SwiftUI

enum ManagerTheme {
    enum Colors {
        static func background(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#111622") : Theme.Colors.background
        }

        static func surface(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#1A2130") : Theme.Colors.surface
        }

        static func surfaceSecondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#232C3E") : Theme.Colors.surfaceSecondary
        }

        static func border(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#313C52") : Theme.Colors.border
        }

        static func primary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#7C92E8") : Theme.Colors.primary
        }

        static func secondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#9EAFEF") : Theme.Colors.secondary
        }

        static func textPrimary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#E5EBF8") : .primary
        }

        static func textSecondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#AEB9CF") : .secondary
        }

        static func textTertiary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#8B97B1") : Color.secondary.opacity(0.7)
        }
    }
}
