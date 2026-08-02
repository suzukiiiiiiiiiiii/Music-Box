# Music Box

端末に入っている音楽ファイルを再生する Android アプリ。見た目をユーザー自身が調整できるのが中心の機能。

## 入っているもの

- 端末内の音楽ファイルを探して、タグ(曲名・アーティスト・アルバム・ジャケット)を読み込む
- バックグラウンド再生。通知バーとロック画面から操作でき、イヤホンの再生ボタンも効く
- イコライザー。プリセット5種類とバンドごとの手動調整
- プレイリストの作成、並べ替え、削除
- テーマ工房 — 背景(ライト/ダーク/真っ黒)、アクセント色8種、角の丸み、行の高さ、文字の大きさを、プレビューを見ながら変更できる
- アルバムアートから配色を自動生成するモード
- 曲・アルバム・アーティスト・プレイリストの4タブと検索
- シャッフル、リピート(なし/全曲/1曲)、再生速度の変更

## リポジトリに置くファイル

```
pubspec.yaml
README.md
.gitignore
android_config/AndroidManifest.xml
lib/
  main.dart
  models.dart
  settings_model.dart
  library_model.dart
  player_model.dart
  app_theme.dart
  widgets.dart
  screens/
    home_screen.dart
    now_playing_screen.dart
    equalizer_screen.dart
    playlist_screen.dart
    theme_lab_screen.dart
.github/workflows/build.yml
```

`android/` フォルダは置かない。ビルドのたびに GitHub Actions 側で生成し、`android_config/AndroidManifest.xml` で上書きする仕組みになっている。

## APK の作り方

1. GitHub でリポジトリを作る(パブリックなら Actions は無料枠無制限)
2. 上のファイルを push する。ブラウザからドラッグ&ドロップでも入る
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

**`bytes` が見つからない、といったエラーが `library_model.dart` で出る**
`audio_metadata_reader` のプロパティ名が変わった可能性がある。該当箇所は `_extractArt` の中だけで、しかも dynamic 経由なのでコンパイルは通るはず。ジャケットが出ない場合はここを疑う。ジャケットが無くてもタイトルから作ったグラデーションで代用されるので、再生自体は動く。

**通知バーに何も出ない**
`android_config/AndroidManifest.xml` のコピーが効いていない。ワークフローの「Apply AndroidManifest」ステップのログを確認する。

**イコライザーの画面が「まだ調整できません」のまま**
Android のイコライザーは再生エンジンが起動してから使えるようになる。1曲再生してから開き直す。機種によってはシステムがイコライザーを提供していないこともある。

**APK が大きい**
`--no-shrink` を外すと小さくなるが、`just_audio_background` のクラスが R8 に削られて release ビルドだけ再生が始まらない不具合が報告されている。まず動くことを優先している。

## 次に足せそうなもの

スリープタイマー、歌詞表示(`.lrc` の読み込み)、ウィジェット、フォルダ単位のブラウズ、再生履歴とよく聴く曲、ギャップレス再生の調整。
