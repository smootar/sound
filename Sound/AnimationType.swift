import Foundation

enum AnimationType: String, CaseIterable, Identifiable {
    case sunGlow = "Sun Glow"
    case balls = "Balls"
    case fire = "Fire"
    case line = "Line"
    case bars = "Bars"

    var id: String { self.rawValue }
}
