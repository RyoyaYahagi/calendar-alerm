# カレンダー連動アラームアプリ 実装計画

## Context
ユーザーは Apple カレンダー / Google カレンダー上の予定を読み込み、タイトルやキーワードに応じて「予定の N 分前」にアラームを自動設定する iOS アプリを作りたい。アラームは iOS 26 で追加された **AlarmKit** を用いてシステムアラームとして発火させる(通知ではなく、サイレントモードでも鳴り、解除/スヌーズができる挙動)。

決定済みの方針:
- **iOS 26+ のみ**対応(AlarmKit をフル活用)
- ルール粒度は**タイトル/キーワード一致**(例: 「会議」を含むイベントは15分前 など)
- Google カレンダー認証は **Google Sign-In SDK (GIDSignIn)**
- 同期/再計算は **BGAppRefresh + 起動時同期**

カレンダーアプリ標準の「アラート(通知)」では、サイレント時に鳴らない・ロック画面で見落とすという欠点があるため、AlarmKit による"目覚まし級"アラームでこれを補う、というのがこのアプリの価値。

## アーキテクチャ概要

```
[UI: SwiftUI]
    │
    ▼
[RuleStore]──┐         [CalendarSync] ───┬─ AppleCalendarSource (EventKit)
[AlarmLedger]│                            └─ GoogleCalendarSource (GTMSessionFetcher + Calendar REST)
    │        │                ▲
    │        │                │ events
    ▼        ▼                │
[AlarmPlanner] ── plan ──► [AlarmScheduler (AlarmKit)]
            ▲
            │ triggers
[BGAppRefreshTask] + onAppear
```

- **CalendarSource** プロトコルで Apple / Google を抽象化
- **AlarmPlanner** がイベント × ルールを突き合わせて「いつ何のアラームを鳴らすか」を決定
- **AlarmScheduler** が AlarmKit 経由で `AlarmManager.shared.schedule(...)` を呼び出し、AlarmLedger(SwiftData) に発行済みID/対応イベントIDを記録して二重発行や取りこぼしを防止

## ディレクトリ構成 (Xcode プロジェクト)

```
CalendarAlarm/
├── CalendarAlarmApp.swift          # @main, AlarmKit / EventKit 権限要求のエントリ
├── Info.plist                       # NSCalendarsFullAccessUsageDescription, NSAlarmKitUsageDescription, BGTaskSchedulerPermittedIdentifiers
├── CalendarAlarm.entitlements       # 必要に応じて
├── Models/
│   ├── CalendarEvent.swift          # ソース横断の正規化済みイベント
│   ├── AlarmRule.swift              # SwiftData @Model: keyword, leadMinutes, enabled, soundID
│   └── ScheduledAlarm.swift         # SwiftData @Model: alarmID(UUID), eventID, fireDate, ruleID
├── Services/
│   ├── CalendarSource.swift         # protocol
│   ├── AppleCalendarSource.swift    # EventKit (EKEventStore.requestFullAccessToEvents)
│   ├── GoogleCalendarSource.swift   # GIDSignIn + Calendar v3 events.list
│   ├── RuleMatcher.swift            # タイトル/メモ vs keyword (大小区別なし、複数キーワードOR/AND)
│   ├── AlarmPlanner.swift           # events × rules → [PlannedAlarm]
│   ├── AlarmScheduler.swift         # AlarmManager wrap: schedule / cancel / list
│   ├── SyncCoordinator.swift        # 全ソース取得→Planner→Scheduler を直列実行、差分適用
│   └── BackgroundRefresh.swift      # BGTaskScheduler 登録 (com.example.calendaralarm.refresh)
├── Auth/
│   └── GoogleAuthController.swift   # GIDSignIn.sharedInstance, トークンリフレッシュ
└── Views/
    ├── HomeView.swift                # 近日アラーム一覧
    ├── RuleListView.swift            # ルール CRUD
    ├── RuleEditorView.swift          # keyword / leadMinutes / sound / 対象カレンダー
    └── SettingsView.swift            # 連携アカウント、権限状態、手動同期
```

## 主要コンポーネント詳細

### 1. AlarmScheduler (AlarmKit)
- `import AlarmKit`
- 起動時に `AlarmManager.shared.requestAuthorization()` で `.authorized` を確認
- スケジュール時:
  ```swift
  let presentation = AlarmPresentation(
      alert: .init(title: event.title, stopButton: .init(text: "停止", textColor: .white)),
      countdown: nil
  )
  let attributes = AlarmAttributes(presentation: presentation, tintColor: .accentColor)
  let config = AlarmManager.AlarmConfiguration(
      schedule: .fixed(fireDate),
      attributes: attributes,
      sound: .named(rule.soundID)
  )
  let alarm = try await AlarmManager.shared.schedule(id: UUID(), configuration: config)
  ```
- 取消は `AlarmManager.shared.cancel(id:)`
- **重要**: AlarmKit は同時スケジュール数に上限があるため、AlarmLedger 上で「直近 N 件のみ保持」「過去分は cleanup」のルールを持たせる

### 2. AppleCalendarSource
- `EKEventStore().requestFullAccessToEvents()` (iOS 17+ 必須API)
- `predicateForEvents(withStart: now, end: now + 30days, calendars: nil)` で取得
- `EKEventStore.eventStoreChanged` 通知を購読し、SyncCoordinator にトリガー

### 3. GoogleCalendarSource
- 依存: `GoogleSignIn-iOS` (SPM), `GoogleAPIClientForREST/Calendar` または素の REST + `GTMAppAuth`
- スコープ: `https://www.googleapis.com/auth/calendar.events.readonly`
- `events.list(calendarId: "primary", timeMin: now, timeMax: now+30days, singleEvents: true, orderBy: startTime)`
- 複数カレンダー対応する場合は `calendarList.list` で取得→ユーザーが対象を選ぶ

### 4. RuleMatcher / AlarmPlanner
- `AlarmRule { id, keywords: [String], matchMode: .any/.all, leadMinutes: Int, enabled: Bool, soundID: String, sources: Set<SourceKind> }`
- マッチ判定: `event.title.localizedCaseInsensitiveContains(keyword)` ベース
- Planner は `(event, matchedRule) → PlannedAlarm(fireDate: event.start - leadMinutes, ...)` を生成
- 同一イベントに複数ルールがマッチした場合は **最も早い leadMinutes** を採用(あるいは複数発火するモードを設定で選べるように)
- `fireDate <= now` のものは破棄

### 5. SyncCoordinator (差分適用)
- 既存の `ScheduledAlarm` レコードと新 plan を `eventID` で突き合わせ:
  - 新規 → `schedule` して Ledger に追加
  - 削除/不一致 → `cancel` して Ledger から削除
  - fireDate 変更 → `cancel` → `schedule`
- 同期トリガー: アプリ前面化 / Apple カレンダー変更通知 / BGAppRefresh / 手動更新ボタン / ルール編集後

### 6. BackgroundRefresh
- `Info.plist` の `BGTaskSchedulerPermittedIdentifiers` に `com.example.calendaralarm.refresh` を登録
- アプリ起動時に `BGTaskScheduler.shared.register(forTaskWithIdentifier:)` → `BGAppRefreshTaskRequest(earliestBeginDate: now+1h)` を submit
- タスク内で SyncCoordinator.runOnce() を非同期実行、終了時に次回を再 submit

## 権限と Info.plist
- `NSCalendarsFullAccessUsageDescription` — Apple カレンダー読み取り
- AlarmKit の利用に関する Usage Description (例: `NSAlarmKitUsageDescription`、最終キー名は iOS 26 SDK ドキュメントに合わせる)
- `BGTaskSchedulerPermittedIdentifiers` — 上記 identifier
- Google Sign-In 用 URL スキーム (`CFBundleURLTypes` に reversed client ID)

## 依存ライブラリ (SPM)
- `https://github.com/google/GoogleSignIn-iOS` (GoogleSignIn, GoogleSignInSwift)
- `https://github.com/google/google-api-objectivec-client-for-rest` (`GoogleAPIClientForREST_Calendar`)

## 開発環境セットアップ計画

ビルド・実機テストは macOS + Xcode 26 でしか行えないが、**純粋ロジック層は Foundation のみで書けるため Linux でも `swift test` で検証可能**。これを活かして「テストできる土台を Linux で作り込んでから macOS に持っていく」二段構えで進める。

### モジュール分割 (重要)
SwiftPM のマルチターゲット構成で、iOS-only と Linux-testable を分離する:

```
CalendarAlarm/                      # SPM ルート (Package.swift)
├── Package.swift                    # Core / CoreTests のみ宣言。iOS-only はここに入れない
├── Sources/
│   ├── CalendarAlarmCore/           # ★ Linux で swift test 可能 (Foundation only)
│   │   ├── Models/
│   │   │   ├── CalendarEvent.swift     # struct, Codable, ソース非依存
│   │   │   ├── AlarmRule.swift         # struct (SwiftData 化は App 層で wrap)
│   │   │   └── PlannedAlarm.swift
│   │   ├── RuleMatcher.swift
│   │   ├── AlarmPlanner.swift
│   │   └── AlarmDiffer.swift           # (既存 Ledger, 新 plan) → (toSchedule, toCancel)
│   └── CalendarAlarmApp/            # ★ iOS-only (UIKit/SwiftUI/EventKit/AlarmKit/GoogleSignIn 依存)
│       ├── CalendarAlarmApp.swift   # @main
│       ├── Services/                # AppleCalendarSource, GoogleCalendarSource, AlarmScheduler, ...
│       ├── Auth/
│       ├── Views/
│       └── Resources/Info.plist
└── Tests/
    └── CalendarAlarmCoreTests/      # ★ Linux で実行
        ├── RuleMatcherTests.swift
        ├── AlarmPlannerTests.swift
        └── AlarmDifferTests.swift
```

`Package.swift` では `CalendarAlarmCore` を `.library` として `platforms: [.iOS(.v26), .macOS(.v15)]` 程度に宣言(Linux も SwiftPM ビルドできるよう platforms を絞らない構成にする)。`CalendarAlarmApp` ターゲットは Xcode プロジェクト側で本体アプリに組み込み、SPM 上はビルドしない(あるいは `#if canImport(UIKit)` でガードする)。

### Linux フェーズ (現環境で完結する作業)

1. **Swift ツールチェーンのインストール**
   - `swiftly` (公式インストーラ) または apt パッケージで Swift 6.x を入れる
     ```bash
     curl -L https://swift-server.github.io/swiftly/swiftly-install.sh | bash
     swiftly install latest
     swiftly use latest
     swift --version   # 6.x が出ること
     ```
2. **リポジトリ初期化**
   - 現在のディレクトリ `/home/yappa/dev/app/calender-alerm` で `git init`
   - `.gitignore` (Swift, Xcode, macOS テンプレ + `.build/`, `*.xcuserstate`, `GoogleService-Info.plist`, `GoogleClientID.plist`)
3. **`swift package init --type library --name CalendarAlarmCore`** → 上記モジュール構成に整形
4. **Core 実装**
   - `CalendarEvent`, `AlarmRule`, `PlannedAlarm` の struct を定義
   - `RuleMatcher.matches(event:rule:)` を Foundation の `String.range(of:options:)` ベースで実装
   - `AlarmPlanner.plan(events:rules:now:)` を純粋関数として実装
   - `AlarmDiffer.diff(existing:planned:)` で「予約すべき/取り消すべき」のセットを返す
5. **ユニットテスト (`swift test` で全部走る)**
   - キーワード OR/AND の境界、大小区別なし、空文字、絵文字
   - イベント開始が `now` より前の場合は plan に含めない
   - 同一 event に複数ルールがマッチした際の挙動 (最早 leadMinutes 採用 / 多発火モード)
   - 差分: 新規/削除/fireDate 変更を正しく分類
6. **iOS 層のスタブも書いておく(コンパイルは Linux では通らないがファイルは置く)**
   - `AppleCalendarSource.swift` などに `#if canImport(EventKit)` ガードで本実装、`#else` 側は空にしておくと SPM ビルドが Linux でも通る
7. **ドキュメント整備**
   - `README.md`: セットアップ手順、Google Cloud Console での OAuth クライアント発行手順 (iOS 用、reversed client ID の取得)、Apple Developer 設定の TODO
   - `plans/dev-setup.md` にこの手順を抜き出して残す

**この段階で達成される状態**: Core ロジックが TDD で固まり、Linux 上で `swift test` が緑になる。iOS 層は型シグネチャと TODO コメントだけのスタブが揃っている。

### macOS 移行フェーズ (テスト準備が整った時点で移す)

1. **環境準備**
   - Xcode 26 (App Store または developer.apple.com から)
   - `xcode-select --install`, `sudo xcodebuild -license accept`
   - Apple Developer アカウント (実機テストに必要、AlarmKit は実機推奨)
2. **リポジトリの取り込み**
   - Linux で作ったリポを `git clone` または `rsync`
3. **Xcode プロジェクト作成**
   - File > New > Project > iOS App, SwiftUI, Swift, Storage: SwiftData, Min Deployment: iOS 26
   - 生成された App ターゲットに既存の `Sources/CalendarAlarmApp/**` を「Add Files... (Create groups, copy if needed をオフ)」で取り込み
   - ローカル SPM package `CalendarAlarmCore` を File > Add Package Dependencies > Add Local で追加し、App ターゲットの Frameworks に追加
4. **iOS-only SPM 依存の追加**
   - `GoogleSignIn-iOS` (`GoogleSignIn`, `GoogleSignInSwift`)
   - `google-api-objectivec-client-for-rest` (`GoogleAPIClientForREST_Calendar`)
5. **権限/Info.plist**
   - `NSCalendarsFullAccessUsageDescription`
   - AlarmKit Usage Description (iOS 26 SDK のキー名に追従)
   - `BGTaskSchedulerPermittedIdentifiers` に `com.example.calendaralarm.refresh`
   - `CFBundleURLTypes` に Google reversed client ID
   - Background Modes (capability): Background fetch
6. **Google Cloud Console 側の準備**
   - 新規プロジェクト → OAuth client ID (iOS) を作成
   - Bundle Identifier を登録 → `GoogleService-Info.plist` 相当の client ID / reversed client ID を取得
   - Calendar API を有効化
   - `.gitignore` 済みの安全な場所に `GoogleClientID.plist` として保存
7. **初回ビルド & 動作確認**
   - シミュレータ (iOS 26) で起動 → EventKit / AlarmKit 権限ダイアログを確認
   - シミュレータの Apple カレンダーに予定を入れて取得 → ルール作成 → AlarmKit でアラーム発火 (シミュレータでもサウンド再生されることを確認)
   - 実機でも同様に確認 (AlarmKit のロック画面挙動・サイレント時の挙動は実機がベスト)
8. **CI (任意、後回し可)**
   - GitHub Actions の `macos-latest` で `xcodebuild test` + Linux ランナーで `swift test`(Core のみ)を並行実行

### 移行の節目 (= macOS に移すタイミング)
以下が Linux 上で揃ったら macOS に移す:
- Core モジュールのテストが緑
- iOS 層スタブのファイル/型シグネチャ確定
- 権限まわりの設計と Info.plist キー一覧の確定
- Google OAuth クライアント発行手順がドキュメント化されている

これで macOS 側では「Xcode プロジェクトを作って既存コードを取り込み、iOS 依存ライブラリを追加して走らせる」だけに作業が絞れる。

## 実装順序

### Linux フェーズ (現環境)
L1. Swift ツールチェーン導入 + `git init` + `.gitignore`
L2. `swift package init` で `CalendarAlarmCore` を作成、`Package.swift` を上記構成に整形
L3. `Models/` (CalendarEvent / AlarmRule / PlannedAlarm) の struct を定義
L4. `RuleMatcher` + ユニットテスト
L5. `AlarmPlanner` + ユニットテスト (events × rules → plans の純粋関数)
L6. `AlarmDiffer` + ユニットテスト (既存 vs 新 plan → toSchedule/toCancel)
L7. iOS 層スタブの空ファイル作成 (`#if canImport(...)` ガード) + ファイル/型シグネチャ確定
L8. `README.md` と `plans/dev-setup.md` 整備、Google OAuth 発行手順ドキュメント化
L9. `swift test` が緑であることを確認 → macOS 移行 GO

### macOS フェーズ (Xcode 環境に移してから)
M1. Xcode プロジェクト作成 (iOS 26 deployment target, SwiftUI App, SwiftData) + Core ローカルパッケージを追加
M2. iOS-only SPM 依存 (GoogleSignIn-iOS, GoogleAPIClientForREST_Calendar) を追加
M3. `Models/` の SwiftData @Model ラッパー (Core struct ↔ SwiftData) + `ModelContainer` 配線
M4. `AppleCalendarSource` + EventKit 権限要求 + ホーム画面で取得イベント一覧を表示
M5. `AlarmScheduler` 実装 + デバッグ画面で「次のイベント10分前」を手動予約できるようにする
M6. `RuleListView` / `RuleEditorView` (Core の RuleMatcher / AlarmPlanner はそのまま再利用)
M7. `SyncCoordinator` で差分適用 (Core の AlarmDiffer を再利用、前面化 + EKEventStore 変更通知)
M8. `GoogleAuthController` + `GoogleCalendarSource` を CalendarSource に追加
M9. `BackgroundRefresh` (BGAppRefresh) 登録
M10. エッジケース: 端末再起動後の Ledger 検証、AlarmKit 上限到達時の打ち切り、終日イベントの扱い、繰り返しイベント

## 検証 (Verification)

### Linux フェーズの検証 (現環境で完結)
- `swift build` が警告なしで通る
- `swift test` で Core モジュールの全テストが緑
  - RuleMatcher: キーワード OR/AND、大小区別なし、空文字、絵文字、メモ欄一致
  - AlarmPlanner: `fireDate <= now` のものを除外、複数ルールマッチ時の最早採用
  - AlarmDiffer: 新規/削除/fireDate 変更が正しく分類されること
- ファイルツリーに iOS 層スタブが揃い、Linux で `swift build` する際に `#if canImport(...)` ガードで除外されている

### macOS フェーズの検証 (移行後)
- **Apple カレンダー**: シミュレータ/実機の標準カレンダーに「テスト会議 5 分後開始」を作成 → ルール「会議」「3分前」→ 2 分後にシステムアラームが鳴ることを確認
- **Google カレンダー**: web UI で予定追加 → アプリ起動 → 同期 → 該当時刻にアラーム発火
- **差分適用**: 既存予定の開始時刻を変更 → 再同期 → 旧アラームが消え新アラームが立つ
- **重複防止**: 同じ予定で 2 回同期 → AlarmLedger の同一 eventID レコードが 1 件のままであること
- **BGAppRefresh**: Xcode の Debug → Simulate Background Fetch、または `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.example.calendaralarm.refresh"]` で発火し、ログで SyncCoordinator が走ったことを確認
- **権限拒否時**: カレンダー権限 / AlarmKit 権限を拒否した状態で空状態 UI とリトライ導線が出ること

## オープン項目 (実装中に決める)
- 終日イベントの扱い (デフォルトでスキップ vs ルールで個別指定)
- 繰り返しイベントは展開後の各インスタンスを別アラームとして扱う(EventKit/Google ともに `singleEvents` 相当で展開)
- AlarmKit のサウンドは custom (`AlarmKit` のカスタムサウンド指定 API)対応するか
- マルチ Google アカウント対応の優先度
