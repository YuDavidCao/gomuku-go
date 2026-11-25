import Foundation
import OSLog

private let log = Logger(subsystem: "dev.local.gomoku", category: "storage")

enum Stone: String, Codable {
    case black, white

    var name: String { rawValue.capitalized }
}

struct Point: Hashable, Codable {
    let row: Int
    let col: Int
}

/// One game of freestyle Gomoku: black moves first, five or more in a row wins.
/// The whole state is the move list, so undo/redo are just stack pops.
struct Game: Equatable {
    static let winLength = 5
    static let sizes = [13, 15, 19]
    static let defaultSize = 15

    let size: Int
    private(set) var moves: [Point] = []
    /// Redo stack: most recently undone move is last.
    private(set) var undone: [Point] = []

    init(size: Int = Game.defaultSize) {
        self.size = size
    }

    static func stone(forMove index: Int) -> Stone {
        index.isMultiple(of: 2) ? .black : .white
    }

    var stones: [Point: Stone] {
        Dictionary(uniqueKeysWithValues: moves.enumerated().map { ($1, Self.stone(forMove: $0)) })
    }

    /// 1-based move number for each occupied point.
    var moveNumbers: [Point: Int] {
        Dictionary(uniqueKeysWithValues: moves.enumerated().map { ($1, $0 + 1) })
    }

    var currentPlayer: Stone { Self.stone(forMove: moves.count) }
    var lastMove: Point? { moves.last }

    /// Only the last move can have completed a line: the game stops at the first win.
    var winningLine: [Point]? {
        guard let last = moves.last else { return nil }
        let stones = stones
        let stone = stones[last]
        for (dr, dc) in [(0, 1), (1, 0), (1, 1), (1, -1)] {
            var line = [last]
            for sign in [1, -1] {
                var p = Point(row: last.row + dr * sign, col: last.col + dc * sign)
                while stones[p] == stone {
                    line.append(p)
                    p = Point(row: p.row + dr * sign, col: p.col + dc * sign)
                }
            }
            if line.count >= Self.winLength { return line }
        }
        return nil
    }

    var winner: Stone? {
        winningLine == nil ? nil : Self.stone(forMove: moves.count - 1)
    }

    var isDraw: Bool { winner == nil && moves.count == size * size }
    var isOver: Bool { winner != nil || isDraw }
    var canUndo: Bool { !moves.isEmpty }
    var canRedo: Bool { undone.last.map(canPlace) ?? false }

    func contains(_ p: Point) -> Bool {
        (0..<size).contains(p.row) && (0..<size).contains(p.col)
    }

    func canPlace(_ p: Point) -> Bool {
        !isOver && contains(p) && !moves.contains(p)
    }

    /// Returns false (and changes nothing) for an illegal move.
    @discardableResult
    mutating func place(at p: Point) -> Bool {
        guard canPlace(p) else { return false }
        moves.append(p)
        undone.removeAll()
        return true
    }

    mutating func undo() {
        guard let p = moves.popLast() else { return }
        undone.append(p)
    }

    mutating func redo() {
        guard canRedo, let p = undone.popLast() else { return }
        moves.append(p)
    }
}

extension Game: Codable {
    private enum CodingKeys: String, CodingKey { case size, moves, undone }

    /// Saved data is untrusted: replay every move so a corrupt save can't produce an impossible board.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let size = try c.decode(Int.self, forKey: .size)
        guard Self.sizes.contains(size) else {
            throw DecodingError.dataCorruptedError(forKey: .size, in: c, debugDescription: "Unsupported board size \(size)")
        }
        self.init(size: size)
        for p in try c.decode([Point].self, forKey: .moves) where !place(at: p) {
            throw DecodingError.dataCorruptedError(forKey: .moves, in: c, debugDescription: "Illegal move \(p)")
        }
        undone = try c.decode([Point].self, forKey: .undone)
    }
}

struct Score: Codable, Equatable {
    var black = 0
    var white = 0
    var draws = 0

    func adding(_ game: Game) -> Score {
        var s = self
        switch game.winner {
        case .black: s.black += 1
        case .white: s.white += 1
        case nil: if game.isDraw { s.draws += 1 }
        }
        return s
    }
}

/// Everything that survives an app relaunch.
struct Session: Codable, Equatable {
    var game = Game()
    /// Results of games before the current one.
    var finished = Score()

    /// Derived, so undoing a winning move also takes the point back.
    var score: Score { finished.adding(game) }

    mutating func newGame(size: Int) {
        finished = score
        game = Game(size: size)
    }

    mutating func resetScore() {
        finished = Score()
        game = Game(size: game.size)
    }

    private static let storageKey = "session.v1"

    static func load(from defaults: UserDefaults = .standard) -> Session {
        guard let data = defaults.data(forKey: storageKey) else { return Session() }
        do {
            return try JSONDecoder().decode(Session.self, from: data)
        } catch {
            log.error("Discarding unreadable saved game: \(error)")
            return Session()
        }
    }

    func save(to defaults: UserDefaults = .standard) {
        do {
            defaults.set(try JSONEncoder().encode(self), forKey: Self.storageKey)
        } catch {
            log.error("Could not save game: \(error)")
        }
    }
}
