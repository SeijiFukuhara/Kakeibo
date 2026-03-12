# CLAUDE.md

## プロジェクト概要
- アプリ名: MyApp
- プラットフォーム: Windows デスクトップ（Flutter）

## ディレクトリ構成
lib/
├── main.dart
└── screens/
    ├── calendar_screen.dart
    └── category_settings_screen.dart

## よく使うコマンド
- 実行: flutter run -d windows
- テスト: flutter test
- 解析: flutter analyze

## アーキテクチャ
- 状態管理: 未導入（StatefulWidget使用）
- ウィジェットは小さく分割する
```

---

## 4. 新しい会話を始める

Claude Code パネル上部の **「+」ボタン** で新規セッション開始。

最初にこのように伝えます：
```
CLAUDE.mdを読んで、プロジェクト全体の構造を把握してください
```

---

## 5. 開発の進め方

### 機能追加を依頼する
```
ホーム画面を作成してください。
lib/views/home_view.dart として作成し、
main.dartから呼び出すように修正してください
```

### 複数ファイルの修正
```
ユーザー認証機能を追加してください。
必要なファイルをすべて作成・修正してください
```

### エラーを修正してもらう
```
flutter run したところ以下のエラーが出ました：
[エラーメッセージを貼り付け]
修正してください
```

### コードレビューを依頼する
```
@lib/views/home_view.dart をレビューして
改善点を教えてください