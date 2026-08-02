import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_box/app_theme.dart';
import 'package:music_box/models.dart';
import 'package:music_box/screens/theme_lab_screen.dart';
import 'package:music_box/settings_model.dart';
import 'package:provider/provider.dart';

/// load() を呼ばなければ SharedPreferences に触らないので、そのまま画面に渡せる。
Widget wrap(SettingsModel settings) {
  return ChangeNotifierProvider.value(
    value: settings,
    child: Consumer<SettingsModel>(
      builder: (context, s, _) => MaterialApp(
        theme: buildTheme(s),
        home: const ThemeLabScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('プレビューは下までスクロールしても消えない', (tester) async {
    final settings = SettingsModel();
    await tester.pumpWidget(wrap(settings));

    // プレビュー内のサンプル曲名で存在を確かめる。
    expect(find.text('プレビュー用の曲'), findsOneWidget);

    // 設定の一番下まで送る。何度か送って本当に末尾まで行かせる。
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }

    // 一番下まで来ている(最後の項目が見えている)ことを確かめたうえで、
    expect(find.text('アルバムをタイルで並べる'), findsOneWidget);

    // プレビューがまだ残っていること。これが崩れると調整しながら見られない。
    expect(
      find.text('プレビュー用の曲'),
      findsOneWidget,
      reason: 'つまみを触っている間もプレビューが見えていないと調整できない',
    );
  });

  testWidgets('背景を切り替えると設定に反映される', (tester) async {
    final settings = SettingsModel();
    await tester.pumpWidget(wrap(settings));

    expect(settings.surface, SurfaceMode.dark);
    await tester.tap(find.text('ライト'));
    await tester.pumpAndSettle();
    expect(settings.surface, SurfaceMode.light);
  });

  testWidgets('ジャケットの形を変えられる', (tester) async {
    final settings = SettingsModel();
    await tester.pumpWidget(wrap(settings));

    await tester.dragUntilVisible(
      find.text('丸'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await tester.tap(find.text('丸'));
    await tester.pumpAndSettle();
    expect(settings.artworkShape, ArtworkShape.circle);
  });

  testWidgets('初期状態に戻すとアクセント色が既定に戻る', (tester) async {
    final settings = SettingsModel()..accent = const Color(0xFFFF0000);
    await tester.pumpWidget(wrap(settings));

    await tester.tap(find.byTooltip('見た目を初期状態に戻す'));
    await tester.pumpAndSettle();
    expect(settings.accent.toARGB32(), SettingsModel.defaultAccent.toARGB32());
  });
}
