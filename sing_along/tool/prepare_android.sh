#!/usr/bin/env bash
#
# android/ を生成して、このアプリに必要な設定を流し込みます。
#
#   ./tool/prepare_android.sh
#   flutter build apk --release --no-shrink
#
# AndroidManifest の差し替えと minSdk の引き上げまでまとめて済ませます。
# CI からもこれを呼びます。lib/ と pubspec.yaml は退避してから戻すので、
# 変更が消えることはありません。
set -euo pipefail

cd "$(dirname "$0")/.."

ORG="${ORG:-com.example}"
PROJECT_NAME="$(grep -m1 '^name:' pubspec.yaml | awk '{print $2}')"

echo "==> プロジェクト: $PROJECT_NAME (org: $ORG)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter が見つかりません。Flutter SDK を PATH に通してください。" >&2
  exit 1
fi

# --- 1. android/ を生成 -------------------------------------------------------
# flutter create はひな形で lib/ や pubspec.yaml を上書きしてくるので、
# 先に退避して、生成が終わったら戻す。
BACKUP="$(mktemp -d)"
trap 'rm -rf "$BACKUP"' EXIT
for f in lib pubspec.yaml analysis_options.yaml README.md .gitignore; do
  [ -e "$f" ] && cp -r "$f" "$BACKUP/"
done

flutter create --platforms=android --org "$ORG" --project-name "$PROJECT_NAME" . >/dev/null

rm -rf lib
for f in lib pubspec.yaml analysis_options.yaml README.md .gitignore; do
  [ -e "$BACKUP/$f" ] && cp -r "$BACKUP/$f" .
done
# 存在しない MyApp を参照していて解析が落ちるので、これだけ捨てる
rm -f test/widget_test.dart
echo "==> android/ を生成し、lib/ と設定ファイルを戻しました"

# --- 2. AndroidManifest.xml を差し替え ---------------------------------------
cp android_config/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
echo "==> AndroidManifest.xml を差し替えました"

# --- 3. MainActivity を AudioServiceActivity 継承に --------------------------
# これをしないと通知バーとイヤホンのボタンからの操作が効かない。
MAIN_ACTIVITY="$(find android/app/src/main -name 'MainActivity.kt' | head -n1)"
if [ -z "$MAIN_ACTIVITY" ]; then
  echo "MainActivity.kt が見つかりませんでした。" >&2
  exit 1
fi
PKG="$(grep -m1 '^package ' "$MAIN_ACTIVITY" | awk '{print $2}')"
cat > "$MAIN_ACTIVITY" <<EOF
package $PKG

import com.ryanheise.audioservice.AudioServiceActivity

// 通知バーとイヤホンのボタンから操作するために AudioServiceActivity を継承します。
class MainActivity : AudioServiceActivity()
EOF
echo "==> $MAIN_ACTIVITY を書き換えました (package: $PKG)"

# --- 4. minSdk を 23 に --------------------------------------------------------
# just_audio_background の下限。Flutter の既定より高いので上書きする。
python3 - <<'PY'
import pathlib
import re
import sys

for name in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    path = pathlib.Path(name)
    if not path.exists():
        continue
    text = path.read_text()
    # `minSdk = flutter.minSdkVersion` (kts) と `minSdkVersion flutter.minSdkVersion` (groovy)
    patched, count = re.subn(
        r'minSdk(?:Version)?\s*=?\s*flutter\.minSdkVersion',
        'minSdk = 23',
        text,
    )
    if count == 0:
        print(f'!! {name} の minSdk を書き換えられませんでした', file=sys.stderr)
        sys.exit(1)
    path.write_text(patched)
    print(f'==> {name} の minSdk を 23 にしました')
    break
else:
    print('!! android/app/build.gradle(.kts) が見つかりません', file=sys.stderr)
    sys.exit(1)
PY

# --- 5. 依存を取得 ------------------------------------------------------------
flutter pub get

cat <<'EOF'

==> ここまで完了しました。APK を作るには:

  flutter build apk --release --no-shrink
  # build/app/outputs/flutter-apk/app-release.apk

  --no-shrink: R8 が just_audio_background のクラスを削ってしまい、
  release ビルドだけ再生が始まらなくなる既知の問題を避けるため。

EOF
