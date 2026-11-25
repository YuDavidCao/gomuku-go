import SwiftUI

struct BoardView: View {
    let game: Game
    let showMoveNumbers: Bool
    let onTap: (Point) -> Void

    private static let wood = Color(red: 0.87, green: 0.71, blue: 0.45)
    private static let stoneScale = 0.88

    var body: some View {
        let stones = game.stones
        let numbers = game.moveNumbers
        let winning = Set(game.winningLine ?? [])

        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(game.size)
            ZStack(alignment: .topLeading) {
                gridLines(cell: cell)
                ForEach(0..<game.size * game.size, id: \.self) { i in
                    let p = Point(row: i / game.size, col: i % game.size)
                    cellButton(p, stone: stones[p], number: numbers[p], isWinning: winning.contains(p), cell: cell)
                        .frame(width: cell, height: cell)
                        .position(x: (CGFloat(p.col) + 0.5) * cell, y: (CGFloat(p.row) + 0.5) * cell)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(6)
        .background(Self.wood, in: .rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }

    private func gridLines(cell: CGFloat) -> some View {
        Canvas { ctx, size in
            let n = game.size
            let start = cell / 2, end = size.width - cell / 2
            var lines = Path()
            for i in 0..<n {
                let x = start + CGFloat(i) * cell
                lines.move(to: CGPoint(x: x, y: start)); lines.addLine(to: CGPoint(x: x, y: end))
                lines.move(to: CGPoint(x: start, y: x)); lines.addLine(to: CGPoint(x: end, y: x))
            }
            ctx.stroke(lines, with: .color(.black.opacity(0.7)), lineWidth: 0.8)

            // Star points: corners-ish and center; 19x19 gets the full nine.
            let marks = [3, n / 2, n - 4]
            let dot = max(3, cell * 0.16)
            for r in marks { for c in marks where n == 19 || r == c || r + c == n - 1 {
                let center = CGPoint(x: start + CGFloat(c) * cell, y: start + CGFloat(r) * cell)
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - dot / 2, y: center.y - dot / 2, width: dot, height: dot)), with: .color(.black))
            } }
        }
    }

    private func cellButton(_ p: Point, stone: Stone?, number: Int?, isWinning: Bool, cell: CGFloat) -> some View {
        Button { onTap(p) } label: {
            ZStack {
                Color.clear.contentShape(.rect)
                if let stone {
                    StoneView(stone: stone, diameter: cell * Self.stoneScale)
                    if isWinning {
                        Circle().stroke(.red, lineWidth: max(2, cell * 0.1))
                            .frame(width: cell * Self.stoneScale, height: cell * Self.stoneScale)
                    }
                    if showMoveNumbers, let number {
                        Text("\(number)")
                            .font(.system(size: cell * 0.38, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(stone == .black ? .white : .black)
                            .frame(width: cell * 0.8)
                    } else if p == game.lastMove {
                        Circle().fill(.red).frame(width: cell * 0.22, height: cell * 0.22)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.coordinate(p, size: game.size))
        .accessibilityValue(accessibilityValue(stone: stone, number: number, isWinning: isWinning))
    }

    private func accessibilityValue(stone: Stone?, number: Int?, isWinning: Bool) -> String {
        guard let stone, let number else { return "Empty" }
        return "\(stone.name), move \(number)" + (isWinning ? ", winning line" : "")
    }

    /// Column letters A… left to right, row numbers counting up from the bottom, like a printed board.
    static func coordinate(_ p: Point, size: Int) -> String {
        let letter = Character(UnicodeScalar(UInt8(ascii: "A") + UInt8(p.col)))
        return "\(letter)\(size - p.row)"
    }
}

struct StoneView: View {
    let stone: Stone
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(stone == .black
                  ? RadialGradient(colors: [Color(white: 0.45), .black], center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: diameter * 0.6)
                  : RadialGradient(colors: [.white, Color(white: 0.8)], center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: diameter * 0.7))
            .overlay(Circle().stroke(.black.opacity(stone == .white ? 0.35 : 0), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.35), radius: diameter * 0.06, x: diameter * 0.04, y: diameter * 0.06)
            .frame(width: diameter, height: diameter)
    }
}
