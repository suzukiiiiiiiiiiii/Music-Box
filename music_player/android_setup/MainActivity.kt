// android/app/src/main/kotlin/<あなたのパッケージ>/MainActivity.kt をこの内容にしてください。
// package 行だけは、既存のファイルに書かれているものをそのまま使ってください。

package com.example.music_player

import com.ryanheise.audioservice.AudioServiceActivity

// FlutterActivity ではなく AudioServiceActivity を継承します。
// これをしないとイヤホンの再生ボタンや通知バーの操作が効きません。
class MainActivity : AudioServiceActivity()
