# Gomoku

Two-player, same-device Gomoku for iPhone and iPad (SwiftUI, iOS 17+). Freestyle rules: black moves first, five or more in a row wins.

- Unlimited undo and redo for both players, including after a win
- 13×13, 15×15 or 19×19 boards
- Winning line highlight, last-move marker, optional move numbers
- Running score (wins and draws); undoing a winning move takes the point back
- Game and score are saved across launches; haptics on moves and wins
- VoiceOver: every intersection is labeled (e.g. "H8, Black, move 3")

## Build

The Xcode project is generated from `project.yml`:

```bash
xcodegen generate && open Gomoku.xcodeproj
```

Run tests:

```bash
xcodebuild test -project Gomoku.xcodeproj -scheme Gomoku -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
```
