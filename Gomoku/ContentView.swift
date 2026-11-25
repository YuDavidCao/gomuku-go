import SwiftUI

struct ContentView: View {
    @State private var session = Session.load()
    @AppStorage("showMoveNumbers") private var showMoveNumbers = false
    @State private var pendingNewGameSize: Int?
    @State private var confirmResetScore = false

    private var game: Game { session.game }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                scoreboard
                status
                BoardView(game: game, showMoveNumbers: showMoveNumbers) { session.game.place(at: $0) }
                Spacer(minLength: 0)
                controls
            }
            .padding()
            .frame(maxWidth: 700)
            .navigationTitle("Gomoku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { menu }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: game.moves.count)
        .sensoryFeedback(.success, trigger: game.winner) { _, new in new != nil }
        .onChange(of: session) { session.save() }
        .confirmationDialog("Abandon the current game?", isPresented: .init(
            get: { pendingNewGameSize != nil },
            set: { if !$0 { pendingNewGameSize = nil } }
        ), titleVisibility: .visible) {
            Button("New Game", role: .destructive) {
                if let size = pendingNewGameSize { session.newGame(size: size) }
            }
        } message: {
            Text("The game in progress won't count toward the score.")
        }
        .confirmationDialog("Reset the score?", isPresented: $confirmResetScore, titleVisibility: .visible) {
            Button("Reset Score", role: .destructive) { session.resetScore() }
        } message: {
            Text("Clears all wins and draws and starts a fresh board.")
        }
    }

    private var scoreboard: some View {
        let score = session.score
        return HStack(spacing: 12) {
            PlayerCard(stone: .black, wins: score.black, isTurn: !game.isOver && game.currentPlayer == .black)
            VStack(spacing: 2) {
                Text("Draws").font(.caption).foregroundStyle(.secondary)
                Text("\(score.draws)").font(.headline.monospacedDigit())
            }
            .accessibilityElement(children: .combine)
            PlayerCard(stone: .white, wins: score.white, isTurn: !game.isOver && game.currentPlayer == .white)
        }
    }

    private var status: some View {
        HStack {
            Text(statusText)
                .font(.title3.weight(.semibold))
                .contentTransition(.opacity)
            Spacer()
            if game.isOver {
                Button("Play Again") { session.newGame(size: game.size) }
                    .buttonStyle(.borderedProminent)
            } else if let last = game.lastMove {
                Text("Last: \(BoardView.coordinate(last, size: game.size))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 36)
        .animation(.default, value: statusText)
    }

    private var statusText: String {
        if let winner = game.winner { return "\(winner.name) wins!" }
        if game.isDraw { return "Draw — board is full" }
        return "\(game.currentPlayer.name) to move · #\(game.moves.count + 1)"
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button { session.game.undo() } label: {
                Label("Undo", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
            }
            .disabled(!game.canUndo)
            Button { session.game.redo() } label: {
                Label("Redo", systemImage: "arrow.uturn.forward").frame(maxWidth: .infinity)
            }
            .disabled(!game.canRedo)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var menu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("New Game") {
                    ForEach(Game.sizes, id: \.self) { size in
                        Button("\(size) × \(size)" + (size == game.size ? " (current)" : "")) { requestNewGame(size: size) }
                    }
                }
                Toggle("Show Move Numbers", systemImage: "number", isOn: $showMoveNumbers)
                Button("Reset Score", systemImage: "arrow.counterclockwise", role: .destructive) { confirmResetScore = true }
            } label: {
                Label("Options", systemImage: "ellipsis.circle")
            }
        }
    }

    private func requestNewGame(size: Int) {
        // Only ask when real progress would be lost; a finished game is already scored.
        if game.moves.isEmpty || game.isOver {
            session.newGame(size: size)
        } else {
            pendingNewGameSize = size
        }
    }
}

private struct PlayerCard: View {
    let stone: Stone
    let wins: Int
    let isTurn: Bool

    var body: some View {
        HStack(spacing: 10) {
            StoneView(stone: stone, diameter: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(stone.name).font(.subheadline.weight(.semibold))
                Text("\(wins) win\(wins == 1 ? "" : "s")").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.fill.tertiary, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isTurn ? Color.accentColor : .clear, lineWidth: 2))
        .animation(.default, value: isTurn)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isTurn ? .isSelected : [])
    }
}

#Preview {
    ContentView()
}
