# Windows PC から iPhone アプリをビルドする手順書

## 前提知識

**重要**: iOS アプリのビルドには本来 macOS + Xcode が必要です。  
Windows PC からビルドするには、**クラウドの Mac を使う**方法が現実的です。  
本手順書では **Codemagic**（無料枠あり）を使ったビルド方法をメインに解説します。

---

## 目次

1. [必要なもの](#1-必要なもの)
2. [Apple Developer アカウントの取得](#2-apple-developer-アカウントの取得)
3. [Firebase iOS の設定](#3-firebase-ios-の設定)
4. [Codemagic でビルドする](#4-codemagic-でビルドする)
5. [実機テスト（TestFlight）](#5-実機テストtestflight)
6. [App Store への申請](#6-app-store-への申請)
7. [トラブルシューティング](#7-トラブルシューティング)

---

## 1. 必要なもの

| 項目 | 費用 | 備考 |
|------|------|------|
| Apple Developer Program | 年間 $99（約 15,000円） | iOS アプリ配布に必須 |
| Codemagic アカウント | 無料（月500分まで） | CI/CD サービス |
| GitHub アカウント | 無料 | コードホスティング |
| iPhone（実機） | 持っているもの | テスト用 |

---

## 2. Apple Developer アカウントの取得

### 2-1. 登録

1. https://developer.apple.com/programs/ にアクセス
2. 「Enroll」をクリック
3. Apple ID でサインイン（なければ作成）
4. 個人として登録する場合：「Individual/Sole Proprietor」を選択
5. 年間 $99 を支払い（クレジットカード）

### 2-2. 証明書の準備（Codemagic が自動生成するので後回し可）

Codemagic を使う場合、証明書の作成は自動化できます。  
後の手順で設定します。

---

## 3. Firebase iOS の設定

現在のプロジェクトは Firebase を使用しています。iOS 用の設定を追加します。

### 3-1. Firebase コンソールで iOS アプリを追加

1. https://console.firebase.google.com/ にアクセス
2. プロジェクト（kakeibo_app_mvp_2）を開く
3. 「アプリを追加」→ iOS アイコンをクリック
4. バンドル ID を入力：`com.yourname.kakeiboAppMvp2`（任意、後で変更可）
5. アプリのニックネームを入力（例：家計簿 iOS）
6. 「アプリを登録」をクリック

### 3-2. GoogleService-Info.plist をダウンロード

1. Firebase コンソールから `GoogleService-Info.plist` をダウンロード
2. プロジェクトの `ios/Runner/` フォルダに配置：

```
kakeibo_app_mvp_2/
└── ios/
    └── Runner/
        └── GoogleService-Info.plist  ← ここに置く
```

### 3-3. バンドル ID を Flutter プロジェクトに設定

`ios/Runner.xcodeproj/project.pbxproj` 内の `PRODUCT_BUNDLE_IDENTIFIER` を  
Firebase で設定したバンドル ID に合わせる必要があります。  
Codemagic 設定時に指定できます。

---

## 4. Codemagic でビルドする

### 4-1. GitHub にコードをプッシュ

```bash
# GitHub でリポジトリを作成してから
git remote add origin https://github.com/あなたのユーザー名/kakeibo_app_mvp_2.git
git branch -M main
git push -u origin main
```

**注意**: `GoogleService-Info.plist` は `.gitignore` に追加して GitHub に上げないこと。

```
# .gitignore に追加
ios/Runner/GoogleService-Info.plist
```

### 4-2. Codemagic アカウント作成

1. https://codemagic.io/ にアクセス
2. GitHub アカウントでサインアップ
3. 「Add application」をクリック
4. GitHub リポジトリ（kakeibo_app_mvp_2）を選択
5. フレームワーク：「Flutter App」を選択

### 4-3. ビルド設定

Codemagic のダッシュボードで以下を設定します：

#### Build triggers（ビルドのトリガー）
- 「Trigger on push」にチェック（main ブランチ）

#### Build for platforms
- iOS にチェック

#### iOS code signing
1. 「Automatic」を選択
2. Apple Developer アカウントの認証情報を入力：
   - Apple ID（メールアドレス）
   - App-specific password（Apple ID 設定ページで生成）
3. Bundle identifier：`com.yourname.kakeiboAppMvp2`（Firebase と同じもの）
4. Provisioning profile：「App Store」を選択

#### 環境変数（Environment variables）
Firebase の設定ファイルをセキュアに渡すため：

1. 「+ Add variable」をクリック
2. 変数名：`GOOGLE_SERVICE_INFO_PLIST`
3. 値：`GoogleService-Info.plist` の中身をテキストで貼り付け
4. 「Secure」にチェック

**`codemagic.yaml` ファイルをプロジェクトルートに作成**（詳細設定用）：

```yaml
workflows:
  ios-workflow:
    name: iOS Build
    max_build_duration: 60
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
      vars:
        BUNDLE_ID: "com.yourname.kakeiboAppMvp2"
      ios_signing:
        distribution_type: app_store
        bundle_identifier: $BUNDLE_ID
    scripts:
      - name: GoogleService-Info.plist を配置
        script: |
          echo $GOOGLE_SERVICE_INFO_PLIST > $CM_BUILD_DIR/ios/Runner/GoogleService-Info.plist
      - name: Flutter パッケージ取得
        script: flutter pub get
      - name: iOS ビルド
        script: |
          flutter build ipa \
            --release \
            --export-options-plist=/Users/builder/export_options.plist
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
```

### 4-4. ビルド実行

1. Codemagic ダッシュボードで「Start new build」をクリック
2. ビルドが開始される（約 15〜30 分）
3. 成功すると `.ipa` ファイルがダウンロード可能になる

---

## 5. 実機テスト（TestFlight）

### 5-1. TestFlight とは

Apple の公式テスト配信サービス。  
App Store 申請前に実機でテストできます。

### 5-2. TestFlight にアップロード（Codemagic 経由）

Codemagic の publishing 設定で `submit_to_testflight: true` にすると自動でアップロードされます。

### 5-3. iPhone でテスト

1. iPhone に App Store から「TestFlight」アプリをインストール
2. Apple Developer アカウントのメールに招待が届く
3. TestFlight を開いてアプリをインストール

---

## 6. App Store への申請

### 6-1. App Store Connect でアプリ登録

1. https://appstoreconnect.apple.com/ にアクセス
2. 「マイ App」→「+」→「新規 App」
3. 必要事項を入力：
   - プラットフォーム：iOS
   - 名前：アプリ名
   - バンドル ID：Codemagic で設定したもの
   - SKU：任意の識別子

### 6-2. スクリーンショットの準備

最低限必要なサイズ：
- 6.5インチ（iPhone 14 Pro Max）：1284 × 2778 px
- 5.5インチ（iPhone 8 Plus）：1242 × 2208 px

### 6-3. 申請

1. App Store Connect でビルドを選択
2. 必要情報を入力（説明文、プライバシーポリシー URL など）
3. 「審査へ提出」をクリック
4. 審査期間：通常 1〜3 日

---

## 7. トラブルシューティング

### flutter_secure_storage のエラー

iOS では `flutter_secure_storage` が Keychain を使います。  
`ios/Podfile` に最低デプロイターゲットを設定：

```ruby
platform :ios, '12.0'
```

### Firebase が動かない

`GoogleService-Info.plist` が正しく配置されているか確認。  
`REVERSED_CLIENT_ID` が URL スキームに登録されているか確認：  
`ios/Runner/Info.plist` に以下を追加：

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

### ビルドが失敗する（CocoaPods エラー）

Codemagic のログを確認。多くの場合、`ios/Podfile` の設定が必要：

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

---

## まとめ：最短ルート

```
1. Apple Developer 登録（$99） 
   ↓
2. Firebase コンソールで iOS アプリ追加 → GoogleService-Info.plist 取得
   ↓
3. GitHub にコードをプッシュ（plist は除外）
   ↓
4. Codemagic にリポジトリを接続・環境変数設定
   ↓
5. Codemagic でビルド実行（自動で証明書取得・ビルド）
   ↓
6. TestFlight でテスト
   ↓
7. App Store 申請
```

---

*作成日: 2026-04-08*  
*対象プロジェクト: kakeibo_app_mvp_2*
