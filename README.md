# SplitEase

**SplitEase** is a smart, real-time expense-splitting app built with Flutter. Split bills with friends, track who owes what, generate PDF reports, and settle up — all without a backend server.

---

## ✨ Features

### 💰 Group Expense Tracking
- Create groups for trips, roommates, events, or any shared expense scenario
- Add expenses with flexible split options: **Equal**, **Fixed Amount**, or **Percentage**
- Support for **multi-payer** expenses (e.g. two people jointly paid for an item)
- Real-time balance calculation — instantly see who owes who

### 🤝 Settlement Planner
- Optimal debt minimisation algorithm to reduce the number of transactions needed
- Visual settlement cards showing exact amounts to pay/receive

### 📊 PDF Financial Reports
- One-tap PDF export with full expense history, settlement plan, and balance summary
- Styled report with branded headers and clean data tables
- Share via any Android/iOS app (WhatsApp, Email, Drive, etc.) using native share sheet

### 🔗 Real-Time Collaboration (P2P WebRTC)
- Host a session or join a group via an invite link — **no account or server needed**
- Live sync across all connected devices: expenses, comments, and balances update instantly
- Works on both Web and Android

### 🕐 Activity Feed
- Per-group activity log tracking: group creation, member joins, expense additions & edits, name changes
- Timeline UI with color-coded icons and relative timestamps

### 💬 Expense Comments
- Discussion thread on every expense — type your message and press Enter to send

### ✏️ Expense Editing
- Edit any past expense with pre-filled form data
- Changes are broadcast to all connected peers in real time

### 📱 Deep Linking (Android)
- Clicking a SplitEase invite link on Android opens the app directly if installed
- Falls back to the web version otherwise

### 🔒 Admin Controls
- Group admin can delete a group (with confirmation dialog)
- Admin-only UI elements are automatically hidden from regular members

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.x or later
- Dart SDK 3.x or later
- For Android APK: Android Studio with Android SDK

### Run locally (web)
```bash
flutter pub get
flutter run -d chrome --web-hostname localhost --web-port 8080
```

### Build Android APK
```bash
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🌐 Live Demo

The app is deployed to GitHub Pages via GitHub Actions on every push to `main`.

➡️ [Open SplitEase Web App](https://sagarmemane135.github.io/SplitEase/)

> **Note:** After the GitHub Action runs for the first time, navigate to  
> **Repository Settings → Pages → Source** and set the branch to `gh-pages`.

---

## 📂 Project Structure

```
lib/
├── app/                        # Root app widget & theme
├── bootstrap/                  # App entry point
├── core/
│   ├── state/                  # AppStateController (global state & WebRTC sync)
│   ├── utils/                  # PDF generator, export helpers
│   └── widgets/                # Shared UI components
├── domain/
│   └── entities/               # Data models: Group, Expense, ActivityLog, etc.
└── features/
    ├── activity/               # Activity feed tab
    ├── collaboration/          # WebRTC transport layer
    ├── debts/                  # Settlement/settle-up view
    ├── expenses/               # Add/edit/list expenses
    ├── groups/                 # Groups list & group details
    ├── manage/                 # Account settings page
    ├── onboarding/             # Profile setup (first-time)
    └── shares/                 # Balance breakdown view
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter + Dart |
| State Management | Custom `ChangeNotifier` (no external lib) |
| Local Persistence | `shared_preferences` |
| Real-Time Sync | WebRTC via PeerJS (`peerjs.min.js`) |
| PDF Generation | `pdf` package |
| Native Sharing | `share_plus` |
| CI/CD | GitHub Actions → GitHub Pages |

---

## 📄 License

MIT License — free to use, modify, and distribute.
