# Music Player

端末内の音楽ファイルを再生する Android 向けミュージックプレイヤー（Flutter）。

リポジトリには `lib/` と設定ファイルだけを置いています。`android/` は各自の環境で生成する方式なので、Gradleの生成物や署名まわりがコミットに混ざりません。

## APK の作り方

GitHub Actions の **Build Music Player APK** が push のたびに APK を作ります。
実行結果ページの下の Artifacts から `music-player-apk` をダウンロードして、
zip を解凍して出てきた `app-release.apk` をスマホで開けば入ります
（「提供元不明のアプリのインストール」の許可が要ります）。

手元で作る場合:

```bash
cd music_player
./tool/prepare_android.sh          # android/ を生成して設定を流し込む
flutter build apk --release --no-shrink
```

APKは `build/app/outputs/flutter-apk/app-release.apk` にできます。
パッケージ名を変えたいときは `ORG=com.yourname ./tool/prepare_android.sh`。

`prepare_android.sh` がやること:

1. `flutter create --platforms=android` で `android/` を生成（`lib/` と設定ファイルは退避してから復元）
2. `android_setup/AndroidManifest.xml` を反映
3. `MainActivity.kt` を `AudioServiceActivity` 継承に書き換え（package行は保持）
4. `android/app/build.gradle.kts` の `minSdk` を 23 にする（`just_audio_background` の下限）
5. `flutter pub get`

`--no-shrink` を付けているのは、R8 が `just_audio_background` のクラスを削って
release ビルドだけ再生が始まらなくなる既知の問題を避けるためです。

### Flutter のバージョン

CI は **3.35.7** に固定しています。3.38 以降は AGP 9 の Built-in Kotlin に
変わり、`on_audio_query` のような古い書き方のプラグインは Kotlin が
コンパイルされずクラスごと消えます。上げるときはここから確認してください。

### on_audio_query について

公開版の Android 実装（`on_audio_query_android` 1.1.0）は AGP 4.1 の頃の
ビルド設定のままで、`namespace` が無いため AGP 8 以降ではビルドが通りません。
ビルド設定だけ直した改変版を `packages/on_audio_query_android/` に置き、
`pubspec.yaml` の `dependency_overrides` で差し替えています。Kotlin のソースは
公開版のままです。詳細は
[`packages/on_audio_query_android/README.md`](packages/on_audio_query_android/README.md)。

## 入っている機能

- 曲・アルバム・アーティストの一覧（MediaStoreから自動で読み込み）
- 再生 / 一時停止 / 前後スキップ / シーク
- シャッフル、リピート（なし・全体・1曲）
- **バックグラウンド再生**＋通知バーとイヤホンのボタンからの操作
- 再生キュー（次に再生・最後に追加・並びの確認・不要な曲を外す）
- プレイリストの作成・名前変更・削除・並べ替え（端末内に保存）
- お気に入り
- 曲名 / アーティスト / アルバムの検索
- スリープタイマー、再生速度の変更
- **再生中のジャケットから配色を作り、アプリ全体の色が曲ごとに変わる**
- ライト / ダーク / 端末に合わせる、真っ黒背景、テーマ色の選択

## 構成

```
lib/
├── main.dart                  アプリの起動とテーマの配線
├── utils.dart                 時間表示などの小物
├── theme/
│   └── app_theme.dart         配色とコンポーネントのスタイル
├── services/
│   ├── player_controller.dart      再生エンジン（just_audio）
│   ├── library_controller.dart     端末内の曲の取得と権限
│   ├── playlist_controller.dart    プレイリストとお気に入り
│   ├── settings_controller.dart    表示設定の保存
│   └── artwork_theme_controller.dart  ジャケットからの配色生成
├── screens/                   画面（ホーム・各タブ・プレイヤー・設定ほか）
└── widgets/                   ジャケット、曲の行、ミニプレイヤー
android_setup/                 Android側に流し込む設定ファイル
packages/                      改変版 on_audio_query_android
tool/prepare_android.sh        android/ を生成するスクリプト
```

## つまずきやすいところ

**`Namespace not specified` でビルドが止まる**
`on_audio_query` の Android 実装が古いGradle形式のままなのが原因です。
`packages/on_audio_query_android/` の改変版で差し替えて対処しているので、
`dependency_overrides` が効いているか（`flutter pub get` のログに path 指定が
出るか）を確認してください。

**曲が1つも出てこない**
権限が拒否されています。画面の「権限を許可する」から、端末の設定で「音楽とオーディオ」を許可してください。Android 13以上は `READ_MEDIA_AUDIO` が必要です。

**通知バーの操作が効かない**
`MainActivity` が `AudioServiceActivity` を継承しているか、Manifestに `AudioService` と `MediaButtonReceiver` が入っているかを確認してください。

**`flutter pub get` で依存が解決できない**
`just_audio` と `just_audio_background` はバージョンの組み合わせがずれると衝突します。`flutter pub upgrade --major-versions` を一度走らせてください。

## 入れていないもの

イコライザーはFlutterだけでは実装できず、Androidの `android.media.audiofx.Equalizer` を叩くプラットフォームチャネルを自分で書く必要があります。
