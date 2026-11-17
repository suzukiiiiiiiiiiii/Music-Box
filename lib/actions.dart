import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'library_model.dart';

const _permissionDenied =
    '音楽ファイルの読み取りが許可されていません。端末の設定から許可してください。';

/// 権限を確かめてからスキャンし直す。断られたら理由を出す。
Future<void> rescanLibrary(BuildContext context) async {
  final library = context.read<LibraryModel>();
  final messenger = ScaffoldMessenger.of(context);

  if (!await library.requestPermission()) {
    messenger.showSnackBar(const SnackBar(content: Text(_permissionDenied)));
    return;
  }
  await library.scan();
}

/// フォルダを選んでもらい、追加してからスキャンする。
Future<void> pickFolderAndScan(BuildContext context) async {
  final library = context.read<LibraryModel>();
  final messenger = ScaffoldMessenger.of(context);

  if (!await library.requestPermission()) {
    messenger.showSnackBar(const SnackBar(content: Text(_permissionDenied)));
    return;
  }
  final path = await FilePicker.getDirectoryPath();
  if (path == null) return;
  await library.addFolder(path);
  await library.scan();
}
