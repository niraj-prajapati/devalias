import Foundation

/// Best-effort stack badge derived from process / cwd heuristics (Phase 6).
enum TechStack: String, Codable, CaseIterable, Sendable, Equatable {
    case node
    case vite
    case next
    case python
    case php
    case ruby
    case go
    case docker
    case unknown

    var displayName: String {
        switch self {
        case .node: return "Node"
        case .vite: return "Vite"
        case .next: return "Next.js"
        case .python: return "Python"
        case .php: return "PHP"
        case .ruby: return "Ruby"
        case .go: return "Go"
        case .docker: return "Docker"
        case .unknown: return "Unknown"
        }
    }
}
