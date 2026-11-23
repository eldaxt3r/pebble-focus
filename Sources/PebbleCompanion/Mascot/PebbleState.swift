import SwiftUI

public enum PebbleState: String, CaseIterable, Identifiable, Sendable {
    case idle
    case listening
    case thinking
    case happy
    case mad
    case speaking

    public var id: String { rawValue }

    public var displayTag: String {
        switch self {
        case .idle: return "Idle"
        case .listening: return "Listening"
        case .thinking: return "Thinking"
        case .happy: return "Happy"
        case .mad: return "Mad!"
        case .speaking: return "Speaking"
        }
    }

    public var bodyColor: Color {
        switch self {
        case .happy:
            return Color(red: 53/255, green: 164/255, blue: 92/255)   // #35A45C
        case .mad:
            return Color(red: 210/255, green: 69/255, blue: 60/255)   // #D2453C
        case .idle, .listening, .thinking, .speaking:
            return Color(red: 35/255, green: 35/255, blue: 38/255)    // #232326
        }
    }

    public var bodyNSColor: NSColor {
        switch self {
        case .happy:
            return NSColor(red: 53/255, green: 164/255, blue: 92/255, alpha: 1)
        case .mad:
            return NSColor(red: 210/255, green: 69/255, blue: 60/255, alpha: 1)
        case .idle, .listening, .thinking, .speaking:
            return NSColor(red: 35/255, green: 35/255, blue: 38/255, alpha: 1)
        }
    }

    public var eyeColor: Color {
        Color(red: 246/255, green: 241/255, blue: 231/255) // #F6F1E7
    }

    public var strokeColor: Color {
        switch self {
        case .happy, .mad:
            return Color.white.opacity(0.55)
        default:
            return Color.white.opacity(0.45)
        }
    }

    public var dotColor: Color {
        switch self {
        case .idle: return .green
        case .listening: return .orange
        case .thinking: return .cyan
        case .happy: return Color(red: 53/255, green: 164/255, blue: 92/255)
        case .mad: return Color(red: 210/255, green: 69/255, blue: 60/255)
        case .speaking: return .indigo
        }
    }

    public var expandsIsland: Bool {
        switch self {
        case .listening, .thinking, .mad, .speaking:
            return true
        case .idle, .happy:
            return false
        }
    }
}
