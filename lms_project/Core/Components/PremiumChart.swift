//
//  PremiumChart.swift
//  lms_project
//
//  A premium, smooth line chart component with area gradients and markers.
//

import SwiftUI

struct PremiumLineChart: View {
    let data: [Double]
    let labels: [String]
    let accentColor: Color
    let showPoints: Bool
    
    @State private var hoveredIndex: Int? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let points = calculatePoints(in: geo.size)
            
            ZStack {
                // Interaction Surface
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                dragLocation = value.location
                                updateHoveredIndex(at: value.location, in: geo.size)
                            }
                            .onEnded { _ in
                                isDragging = false
                                hoveredIndex = nil
                            }
                    )
                
                // Background Gradient Area
                let baselineY = geo.size.height - 35 // Consistent baseline for labels
                PremiumLineShape(points: points, closed: true, height: baselineY)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.15), accentColor.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // The Main Premium Line
                PremiumLineShape(points: points, closed: false)
                    .stroke(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                
                // Markers - Small filled circle for every point
                if showPoints {
                    ForEach(0..<points.count, id: \.self) { i in
                        Circle()
                            .fill(accentColor)
                            .frame(width: 6, height: 6)
                            .position(points[i])
                    }
                }
                
                ZStack {
                    ForEach(labels.indices, id: \.self) { i in
                        let stepX = (geo.size.width - 40) / CGFloat(labels.count - 1)
                        let x = 20 + CGFloat(i) * stepX
                        Text(labels[i])
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .position(x: x, y: geo.size.height - 10)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                
                // Dynamic Tooltip Overlay
                if let index = hoveredIndex, index < points.count {
                    let point = points[index]
                    
                    // Vertical highlight line
                    Rectangle()
                        .fill(accentColor.opacity(0.3))
                        .frame(width: 1)
                        .position(x: point.x, y: (geo.size.height - 35) / 2 + 15) // Centered between paddings
                        .frame(height: geo.size.height - 65) // Respect top and bottom padding
                    
                    // Glowing point indicator
                    Circle()
                        .fill(accentColor)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: accentColor.opacity(0.5), radius: 4)
                        .position(point)
                    
                    // Tooltip Box
                    VStack(spacing: 4) {
                        Text("\(labels[index]): \(String(format: "%.1f", data[index]))k")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 2, height: 6)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .position(x: point.x, y: point.y - 35)
                }
            }
        }
    }
    
    private func updateHoveredIndex(at location: CGPoint, in size: CGSize) {
        let stepX = (size.width - 40) / CGFloat(data.count - 1)
        let index = Int(((location.x - 20) / stepX).rounded())
        if index >= 0 && index < data.count {
            if hoveredIndex != index {
                // Optional Haptic Feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                hoveredIndex = index
            }
        }
    }
    
    private func calculatePoints(in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        
        let maxVal = data.max() ?? 1.0
        let minVal = data.min() ?? 0.0
        let range = maxVal - minVal
        let drawRange = range == 0 ? 1.0 : range
        
        let horizontalPadding: CGFloat = 20
        let topPadding: CGFloat = 40    // Room for tooltip
        let bottomPadding: CGFloat = 40 // Room for labels
        
        let drawHeight = size.height - topPadding - bottomPadding
        let stepX = (size.width - horizontalPadding * 2) / CGFloat(data.count - 1)
        
        return data.enumerated().map { index, value in
            let x = horizontalPadding + CGFloat(index) * stepX
            let normalizedY = CGFloat((value - minVal) / drawRange)
            let y = topPadding + drawHeight - (normalizedY * drawHeight)
            return CGPoint(x: x, y: y)
        }
    }
}

struct PremiumLineShape: Shape {
    let points: [CGPoint]
    var closed: Bool = false
    var height: CGFloat = 0
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        
        path.move(to: points[0])
        
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        if closed {
            path.addLine(to: CGPoint(x: points.last!.x, y: height))
            path.addLine(to: CGPoint(x: points.first!.x, y: height))
            path.closeSubpath()
        }
        
        return path
    }
}

struct PremiumLineChart_Previews: PreviewProvider {
    static var previews: some View {
        PremiumLineChart(
            data: [12.4, 15.1, 9.8, 18.2, 14.6, 22.0, 16.8],
            labels: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"],
            accentColor: .blue,
            showPoints: true
        )
        .frame(height: 200)
        .padding()
    }
}
