# iOS App Store 申請ガイド

## 概要
借り物のMacBookでの作業を最小限にするため、事前にWindowsで準備できることをすべて済ませておきます。

---

## Windows PC でやること（事前準備）

### 1. Apple Developer アカウント登録
- [developer.apple.com](https://developer.apple.com) にアクセスし、Apple IDで登録
- 年会費 $99（個人）または $299（法人）を支払い
- 登録完了まで数日かかる場合あり

### 2. App Store Connect でアプリ登録
- [appstoreconnect.apple.com](https://appstoreconnect.apple.com) にログイン
- 「マイApp」→「+」→「新規App」から以下を設定：
  - プラットフォーム: iOS
  - App名（日本語OK）
  - バンドルID（例: `com.yourname.kakeibo`）→ 後でXcodeと一致させる
  - SKU（任意の識別子）
  - ユーザーアクセス
- アプリ情報（説明文、カテゴリ、年齢制限）を入力
- プライバシーポリシーURL（必要な場合）

### 3. スクリーンショット準備
- 必要サイズ: 6.9インチ（iPhone 16 Pro Max相当）が必須
  - 1320 × 2868 px または 1290 × 2796 px
- iPhoneシミュレーターがない場合は [screenshots.pro](https://screenshots.pro) などのオンラインツール利用可
- App Store Connect の「App プレビューとスクリーンショット」にアップロードしておく

### 4. アプリアイコン準備
- 1024×1024 px の PNG（アルファチャンネルなし）を用意
- Flutterプロジェクトの `ios/Runner/Assets.xcassets/AppIcon.appiconset/` に配置
- パッケージ [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) を使うと自動生成できる：
  ```yaml
  # pubspec.yaml に追加
  dev_dependencies:
    flutter_launcher_icons: ^0.14.1

  flutter_launcher_icons:
    ios: true
    image_path: "assets/icon/app_icon.png"
  ```
  ```bash
  dart run flutter_launcher_icons
  ```

### 5. バンドルIDの確認
- `ios/Runner.xcodeproj/project.pbxproj` を開いてBUNDLE_IDENTIFIERを確認
- App Store Connectで登録したバンドルIDと一致させる（例: `com.yourname.kakeibo`）

### 6. Flutterコードの最終確認
- `pubspec.yaml` のバージョン番号を設定（例: `version: 1.0.0+1`）
- Firebaseの `GoogleService-Info.plist` が `ios/Runner/` に入っていることを確認
- 不要なデバッグコードを除去

### 7. Gitにプッシュ
```bash
git add .
git commit -m "iOS App Store提出準備"
git push
```
MacBook上でこのリポジトリをクローンして使う

---

## 借り物のMacBook でやること（最小限）

### 事前に用意しておくもの
- Apple IDとパスワード（Developer登録済みのもの）
- GitHubアカウントの認証情報

### ステップ 1: 環境セットアップ
```bash
# Xcodeをインストール（App Storeから、時間がかかるので先にダウンロードしておく）
# Xcode Command Line Tools
xcode-select --install

# Flutterのインストール（公式サイトから or homebrew）
brew install flutter
# または公式: https://docs.flutter.dev/get-started/install/macos

# Flutterの動作確認
flutter doctor
```

### ステップ 2: リポジトリのクローン
```bash
git clone https://github.com/あなたのGitHubユーザー名/kakeibo_app_mvp_2.git
cd kakeibo_app_mvp_2
flutter pub get
```

### ステップ 3: Xcodeで署名設定
```bash
open ios/Runner.xcworkspace
```
Xcodeが開いたら：
1. 左ペインで `Runner` を選択
2. `Signing & Capabilities` タブ
3. `Automatically manage signing` にチェック
4. `Team` に自分のApple Developer チームを選択
5. `Bundle Identifier` を App Store Connect のバンドルIDに合わせる

### ステップ 4: IPAビルド
```bash
flutter build ipa --release
```
成功すると `build/ios/ipa/` にIPAファイルが生成される

### ステップ 5: App Store Connectにアップロード
**方法A: Xcodeから（推奨）**
1. Xcodeメニュー → `Product` → `Archive`
2. Organizer が開いたら `Distribute App` → `App Store Connect`
3. 指示に従ってアップロード

**方法B: Transporter アプリ（App Storeから無料入手）**
1. Transporterを開く
2. IPAファイルをドラッグ＆ドロップ
3. 「配信」ボタンをクリック

### ステップ 6: App Store Connect で提出
- アップロード完了後、appstoreconnect.apple.com でビルドが表示されるまで待つ（数分〜30分）
- 「TestFlight」でテストするか、直接「審査へ提出」

---

## よくある注意点

| 項目 | 内容 |
|------|------|
| Xcodeバージョン | 最新のXcodeが必要（古いと審査却下される）|
| Privacy Manifest | iOS 17以降、PrivacyInfo.xcprivacy が必要な場合あり |
| Firebase設定 | `GoogleService-Info.plist` は `ios/Runner/` に必ず入れること |
| バージョン番号 | 審査通過後に同じバージョンは再提出不可（+1する） |
| 審査期間 | 通常24〜48時間（初回は数日かかることも） |

---

## ファイル構成（iOS関連）
```
ios/
├── Runner/
│   ├── GoogleService-Info.plist  ← Firebaseの設定ファイル（必須）
│   ├── Info.plist
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/   ← アイコン画像
├── Runner.xcodeproj/
└── Runner.xcworkspace            ← Xcodeで開くのはこちら
```

保存場所: `docs/appstore_deploy_guide.md`
