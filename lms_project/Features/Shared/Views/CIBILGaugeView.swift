//
//  CIBILGaugeView.swift
//  lms_project
//

import SwiftUI

struct CIBILGaugeView: View {
    let score: Int

    private var clampedScore: Int {
        min(max(score, 300), 900)
    }

    private var markerOffsetRatio: CGFloat {
        CGFloat(clampedScore - 300) / 600
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CIBIL Score")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(clampedScore)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.Colors.critical.opacity(0.85))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.9))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.Colors.success.opacity(0.9))
                    }

                    Capsule()
                        .fill(Color.white)
                        .frame(width: 10, height: 22)
                        .overlay(Capsule().stroke(Color.black.opacity(0.12), lineWidth: 1))
                        .offset(x: max(0, min(proxy.size.width - 10, proxy.size.width * markerOffsetRatio - 5)))
                }
            }
            .frame(height: 14)

            HStack {
                Text("300")
                Spacer()
                Text("650")
                Spacer()
                Text("750")
                Spacer()
                Text("900")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.tertiary)
        }
    }

    private var scoreColor: Color {
        if clampedScore >= 750 { return Theme.Colors.success }
        if clampedScore >= 650 { return .orange }
        return Theme.Colors.critical
    }
}
