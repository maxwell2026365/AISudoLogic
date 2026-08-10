# AISudoLogic

An AI-powered Sudoku game for **macOS** and **iOS**.

---

## 1. Problem Statement

Traditional Sudoku games offer only a simple "fill - check - complete" loop, leaving players stranded when facing difficult boards. AISudoLogic addresses the core problems:

1. **Stuck with no guidance** — Players don't know what to fill next or why, on complex boards.
2. **No learning support** — Traditional games just reveal answers or make simple checks, without explaining Sudoku techniques (Naked Single, Hidden Single, etc.).
3. **Boring experience** — Only normal play, lacking achievements, challenges, and progress feedback.
4. **Fragmented cross-platform** — The same game feels inconsistent across macOS and iOS.

## 2. How We Solve It

**1. Complete Sudoku Core Engine**
- Pure Swift Sudoku generator and solver
- Four difficulty levels (Easy / Medium / Hard / Expert), guaranteeing a unique solution via "digging holes + uniqueness verification"
- Backtracking with Minimum Remaining Values (MRV) for millisecond-level solving

**2. Deep AI Integration**
- **AI Breakpoint Hint**: Local algorithm precisely locates a "Naked Single / Hidden Single" breakpoint, then the DeepSeek LLM explains the reasoning in plain language (with thinking mode disabled for instant response), rendered as Markdown
- **AI Coach Chat**: Connected to the DeepSeek API with streaming output, offering:
  - 💡 Next-step analysis
  - 📊 Board difficulty assessment
  - 🎯 Targeted technique practice
  - 🧭 Personalized recommendations based on your history
  - 💬 Free natural-language conversation

**3. Achievement & Retention System**
- **Statistics Panel**: Per-difficulty stats for wins, win rate, perfect-win rate, best/average time, current streak
- **Daily Challenge**: A fixed board generated from the date seed each day; complete it to earn a trophy 🏆

**4. Polished Cross-Platform Experience**
- Board auto-fills window width with aligned row/column labels, adapting to any screen
- Unified dark theme across both platforms
- Soft pastel-colored 3×3 boxes with animated feedback
- Auto-save progress (SwiftData), resume on relaunch

## 3. Highlights vs. Other Sudoku Games

| Highlight | Description |
|---|---|
| 🤖 **AI coach-style guidance** | Explains *why* and *which technique*, like a real coach — not just answers |
| ⚡ **Local algorithm + AI combo** | Deterministic algorithm finds the breakpoint (always correct), AI explains the reasoning — fast & accurate |
| 🎯 **Personalized recommendations** | AI recommends difficulty and practice direction based on your history |
| 🏆 **Daily challenge + trophies** | One fixed board per day, synchronized with the community; earn a trophy on completion |
| 📊 **Deep data statistics** | Win rate, perfect-win rate, streaks, timing — track your growth |
| 🧠 **Targeted training** | Dedicated explanations and practice for techniques you struggle with (e.g., X-Wing) |
| 📱 **Unified dual-platform** | Keyboard support on macOS, touch-optimized on iOS |

## 4. How to Launch

**Requirements**
- Xcode 15.7+ / macOS 14+
- DeepSeek API Key (optional, for AI features; without it, local algorithms still work)

**Option 1: Run in Xcode**
```bash
# Open the project
open AISudoLogic.xcodeproj
```
Select the AISudoLogic scheme in Xcode, pick a destination (macOS or iOS Simulator), and press ▶.

**Option 2: CLI dual-platform deployment**
```bash
./doc/sh/run_all.sh
```
This script builds and deploys to both macOS and the iPhone 17 Pro Max simulator automatically.

**Configure AI features (optional)**
1. Tap the 🔑 icon in the AI Coach dialog
2. Enter your DeepSeek API Key and model name (default `deepseek-v4-flash`)
3. Save, then AI hints and the AI coach become available

---

> 🇨🇳 [中文 README](./README.zh.md)
