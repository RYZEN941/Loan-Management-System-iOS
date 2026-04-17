//
//  Theme.swift
//  lms_project
//

import SwiftUI

// MARK: - Theme

enum Theme {
    
    // MARK: - Colors
    
    enum Colors {
        // Primary
        static let primary = Color(hex: "0066FF")
        static let primaryDark = Color(hex: "0052CC")
        static let primaryLight = Color(hex: "E6F0FF")
        
        // Semantic
        static let critical = Color(hex: "DC3545")
        static let warning = Color(hex: "F5A623")
        static let success = Color(hex: "28A745")
        static let neutral = Color(hex: "6B7280")
        
        // Surfaces
        static let background = Color(hex: "F8F9FA")
        static let surface = Color.white
        static let surfaceSecondary = Color(hex: "F1F3F5")
        static let border = Color(hex: "E5E7EB")
        
        // Dark mode surfaces
        static let backgroundDark = Color(hex: "1C1C1E")
        static let surfaceDark = Color(hex: "2C2C2E")
        static let surfaceSecondaryDark = Color(hex: "3A3A3C")
        static let borderDark = Color(hex: "48484A")
        
        // Adaptive colors
        static func adaptiveBackground(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? backgroundDark : background
        }
        
        static func adaptiveSurface(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? surfaceDark : surface
        }
        
        static func adaptiveSurfaceSecondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? surfaceSecondaryDark : surfaceSecondary
        }
        
        static func adaptiveBorder(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? borderDark : border
        }
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let pill: CGFloat = 100
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let titleLarge = Font.system(size: 28, weight: .bold)
        static let title = Font.system(size: 22, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let caption = Font.system(size: 13, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .semibold)
        static let mono = Font.system(size: 15, weight: .medium, design: .monospaced)
    }
    
    // MARK: - Shadows
    
    enum Shadows {
        static let subtle = Color.black.opacity(0.06)
        static let card = Color.black.opacity(0.08)
    }
    
    // MARK: - Layout
    
    enum Layout {
        static let buttonHeight: CGFloat = 48
        static let rowMinHeight: CGFloat = 64
        static let badgeHeight: CGFloat = 24
        static let iconSize: CGFloat = 20
        static let avatarSize: CGFloat = 40
        static let splitLeftRatio: CGFloat = 0.4
        static let splitRightRatio: CGFloat = 0.6
        static let messageSplitLeft: CGFloat = 0.35
        static let messageSplitRight: CGFloat = 0.65
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
