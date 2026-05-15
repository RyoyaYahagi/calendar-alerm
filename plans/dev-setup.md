# 開発環境セットアップ手順

## Linux フェーズ（現環境で完結）

### 1. Swift ツールチェーンのインストール

```bash
wget https://download.swift.org/swift-6.0.3-release/ubuntu2404/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu24.04.tar.gz
tar xzf swift-6.0.3-RELEASE-ubuntu24.04.tar.gz
mv swift-6.0.3-RELEASE-ubuntu24.04 /usr/local/swift
export PATH="/usr/local/swift/usr/bin:$PATH"
swift --version
```

### 2. リポジトリ初期化

```bash
git clone https://github.com/RyoyaYahagi/calendar-alerm.git
cd calendar-alerm
git init  # 既に .git があれば必要なし
```

`.gitignore` はリポジトリに含まれています（`.build/`, `DerivedData/`, `GoogleService-Info.plist`, `⁊` など）。

### 3. パッケージ初期化

```bash
swift package init --type library --name CalendarAlarmCore
```

### 4. Core 実装

`Sources/CalendarAlarmCore/` 以下に実装:

- `Models/CalendarEvent.swift`
- `Models/AlarmRule.swift`
- `Models/PlannedAlarm.swift`
- `Models/ScheduledAlarmRecord.swift`
- `Models/SourceKind.swift`
- `RuleMatcher.swift`
- `AlarmPlanner.swift`
- `AlarmDiffer.swift`

### 5. ユニットテスト

`Tests/CalendarAlarmCoreTests/` 以下に実装:

- `RuleMatcherTests.swift`
- `AlarmPlannerTests.swift`
- `AlarmDifferTests.swift`

```bash
swift test
```

### 6. iOS 層スタブ

`Sources/CalendarAlarmApp/` 以下に空ファイルを配置（`#if canImport(UIKit)` でガード）:

- `CalendarAlarmApp.swift`
- `Services/*`
- `Auth/GoogleAuthController.swift`
- `Views/*`

### 7. ドキュメント整備

- `README.md`: セットアップ手順、Google Cloud Console 設定手順
- `plans/implementation-plan.md`: アーキテクチャ・実装計画

## macOS 移行フェーズ

Linux フェーズで以下が完了したら macOS に移行:

- Core モジュールのテストが緑
- iOS 層スタブのファイル/型シグネチャ確定
- 権限まわりの設計と Info.plist キー一覧の確定
- Google OAuth クライアント発行手順がドキュメント化されている

### macOS フェーズの流れ

1. Xcode 26 をインストール
2. リポジトリを `git clone` または `rsync`
3. Xcode プロジェクト作成 (iOS App, SwiftUI, SwiftData, iOS 26)
4. 既存 `Sources/CalendarAlarmApp/**` をファイル追加（Create groups, copy if needed オフ）
5. ローカル SPM パッケージ `CalendarAlarmCore` を追加
6. iOS-only SPM 依存を追加（GoogleSignIn-iOS, GoogleAPIClientForREST_Calendar）
7. `Info.plist` 、`CalendarAlarm.entitlements` 、Background Modes 設定
8. Google Cloud Console で OAuth クライアント発行 → `GoogleClientID.plist` 配置
9. シミュレータ / 実機でビルド・動作確認
