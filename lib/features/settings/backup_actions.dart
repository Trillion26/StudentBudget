import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_scope.dart';
import '../../data/backup.dart';
import '../../design/toast.dart';

bool get _useShareSheet => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Sends [text] out as a file: the share sheet on iPhone (Files, iCloud
/// Drive, Google Drive, WhatsApp, email), a save dialog on Windows and in
/// Chrome. Returns true when the student finished sharing or saving.
Future<bool> exportTextFile({required String fileName, required String text, required String mimeType}) async {
  final bytes = Uint8List.fromList(utf8.encode(text));
  if (_useShareSheet) {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mimeType, name: fileName)],
      fileNameOverrides: [fileName],
      subject: fileName,
    ));
    return result.status == ShareResultStatus.success;
  }
  final saved = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    dialogTitle: 'Save $fileName',
    type: FileType.custom,
    allowedExtensions: [fileName.split('.').last],
  );
  return saved != null || kIsWeb;
}

/// Exports everything as one JSON file and records the backup date.
Future<void> saveBackup(BuildContext context) async {
  final store = StoreScope.read(context);
  final toast = ToastHost.of(context);
  try {
    final done = await exportTextFile(
      fileName: backupFileName(store.now()),
      text: store.exportBackupJson(),
      mimeType: 'application/json',
    );
    if (done) {
      await store.markBackedUp();
      toast.show('Backup saved. Keep it somewhere safe, like iCloud Drive or Google Drive.');
    }
  } catch (e) {
    toast.show("The backup couldn't be saved. Try again.");
  }
}

/// Exports one year's transactions as CSV.
Future<void> exportCsv(BuildContext context, int year) async {
  final store = StoreScope.read(context);
  final toast = ToastHost.of(context);
  try {
    final done = await exportTextFile(
      fileName: 'student-budget-$year.csv',
      text: store.exportCsv(year),
      mimeType: 'text/csv',
    );
    if (done) toast.show('Exported your $year transactions.');
  } catch (e) {
    toast.show("The export couldn't be saved. Try again.");
  }
}

/// Picks a backup file, checks it fully, shows a summary and asks before
/// replacing everything. Invalid files change nothing.
Future<void> restoreBackup(BuildContext context) async {
  final store = StoreScope.read(context);
  final toast = ToastHost.of(context);
  List<PlatformFile> files;
  try {
    files = await FilePicker.pickFiles(
      dialogTitle: 'Pick a Student Budget backup',
      type: kIsWeb || defaultTargetPlatform != TargetPlatform.iOS ? FileType.custom : FileType.any,
      allowedExtensions: kIsWeb || defaultTargetPlatform != TargetPlatform.iOS ? ['json'] : null,
    );
  } catch (e) {
    toast.show("Couldn't open the file picker. Try again.");
    return;
  }
  if (files.isEmpty || !context.mounted) return;

  BackupData backup;
  try {
    final bytes = await files.first.readAsBytes();
    backup = decodeBackup(utf8.decode(bytes, allowMalformed: false));
  } on BackupFormatException catch (e) {
    if (context.mounted) await showMessage(context, title: "That backup can't be used", message: e.message);
    return;
  } catch (e) {
    if (context.mounted) {
      await showMessage(
        context,
        title: "That backup can't be used",
        message: "This file isn't a Student Budget backup. Nothing was changed.",
      );
    }
    return;
  }
  if (!context.mounted) return;

  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('Replace everything on this phone with this backup?'),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('The backup has ${backup.summary}.\n\nEverything currently in the app will be replaced.'),
      ),
      actions: [
        CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(context, true), child: const Text('Replace')),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await store.restore(backup);
    toast.show('Backup restored: ${backup.summary}.');
  } catch (e) {
    toast.show("The backup couldn't be restored. Nothing was changed.");
  }
}

/// A simple dialog with an OK button.
Future<void> showMessage(BuildContext context, {required String title, required String message}) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(padding: const EdgeInsets.only(top: 8), child: Text(message)),
      actions: [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );
}
