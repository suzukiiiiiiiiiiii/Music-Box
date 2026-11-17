# Music Box

端末に入っている音楽ファイルを再生する Android アプリ。見た目をユーザー自身が調整できるのが中心の機能。

## 画面の作り

下のバーで3つの面を行き来する。ミニプレイヤーはその上に常駐していて、一覧の
行やボタンと重ならない。

- **ライブラリ** — 検索欄が常に出ていて、曲・アルバム・アーティストのどの表示にも
  同じ絞り込みが掛かる。並べ替えは曲名・アーティスト・アルバム・新しい順。
  下に引くと再スキャン。右上のフォルダアイコンから取り込み設定へ
- **プレイリスト** — その場で作れて、ドラッグで並べ替え、横スワイプで曲を外す
- **テーマ** — プレビューが画面の上に貼り付いたまま動かないので、つまみを
  触りながら結果を見られる

## 入っているもの

- 端末内の音楽ファイルを探して、タグ(曲名・アーティスト・アルバム・ジャケット)を読み込む
- バックグラウンド再生。通知バーとロック画面から操作でき、イヤホンの再生ボタンも効く
- イコライザー。プリセット5種類とバンドごとの手動調整
- プレイリストの作成、並べ替え、削除
- 再生キューの編集 — 次に再生、最後に追加、並べ替え、その場で削除
- スリープタイマー(15/30/45/60/90分)
- テーマ — 背景(ライト/ダーク/真っ黒)、アクセント色8種 + 色相・鮮やかさ・明るさで
  自作、角の丸み、行の高さ、文字の大きさ、ジャケットの形(角丸/丸/四角)、
  アルバムのタイル表示と行表示
- アルバムアートから配色を自動生成するモード
- シャッフル、リピート(なし/全曲/1曲)、再生速度の変更

## リポジトリに置くファイル

```
pubspec.yaml
README.md
.gitignore
analysis_options.yaml
android_config/AndroidManifest.xml
lib/
  main.dart
  models.dart
  settings_model.dart
  library_model.dart
  player_model.dart
  app_theme.dart
  actions.dart
  widgets.dart
  screens/
    home_screen.dart        画面の骨組み(下のバーとミニプレイヤー)
    library_screen.dart
    now_playing_screen.dart
    equalizer_screen.dart
    playlist_screen.dart
    theme_lab_screen.dart
    settings_screen.dart
test/
  library_model_test.dart
  theme_lab_test.dart
.github/workflows/build.yml
```

`test/widget_test.dart` だけは追跡しない。`flutter create` が毎回作り直すもので、
存在しない `MyApp` を参照しているため。

`android/` フォルダは置かない。ビルドのたびに GitHub Actions 側で生成し、`android_config/AndroidManifest.xml` で上書きする仕組みになっている。

## APK の作り方

はじめての人向けに、クリックする場所まで書いた手順書が
[docs/APKの作り方.md](docs/APKの作り方.md) にある。以下はその要約。

1. GitHub でリポジトリを作る(パブリックなら Actions は無料枠無制限)
2. 上のファイルを push する。ブラウザからドラッグ&ドロップでも入る。
   zip のまま置いても Actions はビルドできないので、必ず展開した状態で入れる
3. Actions タブを開く。push した時点で自動的にビルドが始まる
4. 完了したら実行結果ページの下にある Artifacts から `music-box-apk` をダウンロード
5. スマホで zip を解凍して APK を開く。「提供元不明のアプリのインストール」を許可すれば入る

初回は Gradle と Flutter SDK のダウンロードで 8〜12 分ほどかかる。2 回目以降はキャッシュが効く。

## 初回起動時

アプリを開くと曲が0件の状態から始まる。「フォルダを選ぶ」から音楽の入ったフォルダを指定すると、権限の確認が出たあとスキャンが走る。

`/storage/emulated/0/Music`、`/Download`、`/Podcasts` は指定しなくても毎回見に行く。

## つまずきそうなところ

**ビルドが `Namespace not specified` で落ちる**
使っているパッケージが古い Android Gradle Plugin 向けのまま。`android/build.gradle.kts` に namespace を補う設定を足すか、そのパッケージを外す。今の構成では該当するものは入れていない。

**`flutter analyze` が知らないエラーを出す**
依存パッケージが破壊的変更を入れた可能性が高い。`pubspec.yaml` は主要な依存をキャレット指定で止めてあるので、上げるときは 1 つずつ。過去に `file_picker` が 11.0.0 で `FilePicker.platform` を廃止して static 呼び出しになった例がある。

**`GeneratedPluginRegistrant.java` で `cannot find symbol` が出る**
そのプラグインの Kotlin が 1 行もコンパイルされていない。Flutter 3.38 以降は AGP 9 の Built-in Kotlin を使うが、プラグイン側が「AGP 9 なら Kotlin プラグインを当てない」とだけ書いて Built-in Kotlin を見ていないと、`.kt` が丸ごと無視されてクラスが消える。`file_picker` 11.0.3 がこれで、12 系で直っている。プラグインの `android/build.gradle` が `android.builtInKotlin` を見ているか確認する。

**`checkReleaseAarMetadata` で「compile against version 37 or later」と言われる**
プラグインが Flutter の既定 `compileSdk` より新しい SDK を要求している。AGP にも推奨上限があるので上げれば済むとは限らない。`compileSdk` が収まるバージョンまでそのプラグインを下げるほうが確実。`permission_handler` を 12 系に留めているのはこれが理由。

**`bytes` が見つからない、といったエラーが `library_model.dart` で出る**
`audio_metadata_reader` のプロパティ名が変わった可能性がある。該当箇所は `_extractArt` の中だけで、しかも dynamic 経由なのでコンパイルは通るはず。ジャケットが出ない場合はここを疑う。ジャケットが無くてもタイトルから作ったグラデーションで代用されるので、再生自体は動く。

**通知バーに何も出ない**
`android_config/AndroidManifest.xml` のコピーが効いていない。ワークフローの「Apply AndroidManifest」ステップのログを確認する。

**イコライザーの画面が「まだ調整できません」のまま**
Android のイコライザーは再生エンジンが起動してから使えるようになる。1曲再生してから開き直す。機種によってはシステムがイコライザーを提供していないこともある。

**APK が大きい**
`--no-shrink` を外すと小さくなるが、`just_audio_background` のクラスが R8 に削られて release ビルドだけ再生が始まらない不具合が報告されている。まず動くことを優先している。

## 次に足せそうなもの

歌詞表示(`.lrc` の読み込み)、ウィジェット、フォルダ単位のブラウズ、再生履歴とよく聴く曲、ギャップレス再生の調整。

スキャンは `readMetadata` が同期関数なので、曲数が多いと読み込み中に画面が
引っかかる。別アイソレートに逃がすと直る。
