# on_audio_query_android (このリポジトリ向けの改変版)

pub.dev の [`on_audio_query_android` 1.1.0](https://pub.dev/packages/on_audio_query_android)
をそのまま取り込み、Android のビルド設定だけ直したもの。BSD 3-Clause のまま
(`LICENSE` を参照)。

公開版は Android Gradle Plugin 4.1 の頃の設定で止まっていて、今の Flutter が
生成する `android/` では次の理由でビルドが通らない。

- `android { namespace }` が無く、名前空間を `AndroidManifest.xml` の
  `package` 属性で指定している。AGP 8 でこの書き方は廃止された
- `buildscript` に AGP 4.1.3 と Kotlin 1.6.10 を自前で載せていて、
  アプリ側のツールチェーンと衝突する

直したのは `android/build.gradle` と `android/src/main/AndroidManifest.xml` の
2つだけで、Kotlin のソースは公開版のまま。差分の内容は
`android/build.gradle` の冒頭のコメントに書いてある。

`music_player/pubspec.yaml` の `dependency_overrides` からこのディレクトリを
指している。本家が namespace に対応したら override を消せる。
