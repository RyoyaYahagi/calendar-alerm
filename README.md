# CalendarAlarm

iOS 26+ 専用のカレンダー連動アラームアプリ。Apple / Google カレンダーの予定を読み込み、キーワードに応じたルールで「予定の N 分前」に AlarmKit によるシステムアラームを自動設定します。

## 機能概要

- Apple カレンダー (EventKit) / Google カレンダー (REST API) の両方に対応
- タイトル・メモに対するキーワード一致でルールを設定
- AlarmKit を使った「目覚まし級」アラーム（サイレントモードでも鳴る）
- 差分同期：予定変更時に自動でアラームを再スケジュール

## プロジェクト構成

- `Sources/CalendarAlarmCore/` — 純粋 Swift (Foundation) のロジック層。Linux で `swift test` 可能。
- `Sources/CalendarAlarmApp/` — iOS 専用層（SwiftUI / EventKit / AlarmKit / GoogleSignIn）。Xcode プロジェクトで組み込み。
- `plans/` — 実装計画とセットアップ手順

## 開発環境

- **Core 開発**: Swift 6.x (Linux 可)
- **iOS アプリ**: macOS + Xcode 26, iOS 26+ 実機またはシミュレータ
- **依存**: GoogleSignIn-iOS, GoogleAPIClientForREST_Calendar (SPM)

## セットアップ

### Core 層（Linux / macOS 共通）

```bash
cd CalendarAlarm
swift build
swift test
```

### iOS アプリ（macOS + Xcode）

1. Xcode で `CalendarAlarm.xcodeproj` を開く（または新規作成してファイルを取り込む）
2. SPM ローカルパッケージ `CalendarAlarmCore` を追加
3. GoogleSignIn-iOS と GoogleAPIClientForREST_Calendar を SPM で追加
4. `Info.plist` に以下を追加:
   - `NSCalendarsFullAccessUsageDescription`
   - `NSAlarmKitUsageDescription`
   - `BGTaskSchedulerPermittedIdentifiers`
   - `CFBundleURLTypes` (Google reversed client ID)
5. Google Cloud Console で iOS 用 OAuth クライアントを発行し、`GoogleClientID.plist` として配置（`.gitignore` 済み）
6. Apple Developer で Bundle Identifier を登録

## Google Cloud Console 設定

1. 新規プロジェクト作成 → API ライブラリ → Google Calendar API を有効化
2. 認証情報 → OAuth クライアント ID を作成（アプリケーションの種類: iOS）
3. Bundle Identifier を登録 → Client ID と reversed client ID を取得
4. 取得した Client ID を `.gitignore` 済みの `GoogleClientID.plist` またはコードに安全に配置

## ライセンス

MIT
