import Foundation
import Testing
@testable import Gomoku

/// Plays the given black moves, with white answering on a far-away row so it never interferes.
private func playBlack(_ points: [(Int, Int)], size: Int = 15) -> Game {
    var game = Game(size: size)
    for (i, (r, c)) in points.enumerated() {
        let ok = game.place(at: Point(row: r, col: c)); #expect(ok)
        if i < points.count - 1 { let ok = game.place(at: Point(row: size - 1, col: i * 2)); #expect(ok) }
    }
    return game
}

@Test(arguments: [
    [(7, 3), (7, 4), (7, 5), (7, 6), (7, 7)],   // horizontal
    [(2, 9), (3, 9), (4, 9), (5, 9), (6, 9)],   // vertical
    [(0, 0), (1, 1), (2, 2), (3, 3), (4, 4)],   // diagonal
    [(0, 8), (1, 7), (2, 6), (3, 5), (4, 4)],   // anti-diagonal
    [(7, 3), (7, 4), (7, 6), (7, 7), (7, 5)],   // completed in the middle
])
func fiveInARowWins(points: [(Int, Int)]) {
    let game = playBlack(points)
    #expect(game.winner == .black)
    #expect(game.winningLine?.count == 5)
    #expect(game.isOver)
}

@Test func fourIsNotAWin() {
    let game = playBlack([(7, 3), (7, 4), (7, 5), (7, 6)])
    #expect(game.winner == nil)
    #expect(game.currentPlayer == .white)
}

@Test func overlineWinsInFreestyle() {
    let game = playBlack([(7, 1), (7, 2), (7, 3), (7, 5), (7, 6), (7, 4)])
    #expect(game.winningLine?.count == 6)
}

@Test func rejectsIllegalMoves() {
    var game = Game()
    let tries = [Point(row: 7, col: 7), Point(row: 7, col: 7), Point(row: -1, col: 0), Point(row: 0, col: 15)]
    let results = tries.map { game.place(at: $0) }
    #expect(results == [true, false, false, false])
    #expect(game.moves.count == 1)

    var won = playBlack([(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)])
    let placedAfterWin = won.place(at: Point(row: 5, col: 5))
    #expect(!placedAfterWin)
}

@Test func undoAfterWinReopensTheGameAndRedoRestoresIt() {
    var game = playBlack([(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)])
    game.undo()
    #expect(game.winner == nil)
    #expect(game.currentPlayer == .black)
    #expect(game.canRedo)
    game.redo()
    #expect(game.winner == .black)
}

@Test func newMoveClearsRedo() {
    var game = Game()
    game.place(at: Point(row: 1, col: 1))
    game.undo()
    game.place(at: Point(row: 2, col: 2))
    #expect(!game.canRedo)
    #expect(game.stones[Point(row: 2, col: 2)] == .black)
}

@Test func undoAllTheWayBack() {
    var game = playBlack([(1, 1), (2, 2), (3, 3)])
    while game.canUndo { game.undo() }
    #expect(game.moves.isEmpty)
    game.undo() // no-op on empty board
    #expect(game.undone.count == 5)
}

@Test func drawWhenBoardFillsWithoutFive() {
    // Black where (col + 2*row) % 4 < 2: 85 black, 84 white, no five in any direction on 13x13.
    var game = Game(size: 13)
    let cells = (0..<169).map { Point(row: $0 / 13, col: $0 % 13) }
    let black = cells.filter { ($0.col + 2 * $0.row) % 4 < 2 }
    let white = cells.filter { ($0.col + 2 * $0.row) % 4 >= 2 }
    let order = zip(black, white).flatMap { [$0, $1] } + [black.last!]
    let results = order.map { game.place(at: $0) }
    #expect(!results.contains(false))
    #expect(game.isDraw)
    #expect(Score().adding(game).draws == 1)
}

@Test func sessionScoreFollowsUndoAndFoldsIntoNewGame() {
    var session = Session()
    session.game = playBlack([(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)])
    #expect(session.score.black == 1)
    session.game.undo()
    #expect(session.score.black == 0)
    session.game.redo()
    session.newGame(size: 19)
    #expect(session.score.black == 1)
    #expect(session.game.size == 19)
    #expect(session.game.moves.isEmpty)
    session.resetScore()
    #expect(session.score == Score())
}

@Test func saveRoundTripsAndRejectsCorruptData() throws {
    var session = Session()
    session.game.place(at: Point(row: 3, col: 3))
    session.game.place(at: Point(row: 4, col: 4))
    session.game.undo()
    let data = try JSONEncoder().encode(session)
    #expect(try JSONDecoder().decode(Session.self, from: data) == session)

    let duplicate = #"{"size":15,"moves":[{"row":1,"col":1},{"row":1,"col":1}],"undone":[]}"#
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(Game.self, from: Data(duplicate.utf8)) }
    let badSize = #"{"size":4,"moves":[],"undone":[]}"#
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(Game.self, from: Data(badSize.utf8)) }
}
