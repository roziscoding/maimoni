import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import '../api/client.dart';
import '../api/models.dart';

/// Offers an export through the system's share sheet, to save it to the files or send it somewhere.
/// Returns whether the person went through with it.
Future<bool> shareExport(Json data) async {
  final day = DateTime.now().toIso8601String().substring(0, 10);
  final name = 'maimoni-$day.json';
  final file = XFile.fromData(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)), mimeType: 'application/json', name: name);
  final result = await SharePlus.instance.share(ShareParams(files: [file], fileNameOverrides: [name]));
  return result.status != ShareResultStatus.dismissed;
}

/// Asks for an export file and reads it; `null` when the person closed the picker. Throws
/// [ApiException] for a file that isn't JSON.
Future<Object?> pickExport() async {
  final file = await openFile(acceptedTypeGroups: const [
    XTypeGroup(label: 'Export do maimoni', extensions: ['json'], mimeTypes: ['application/json'], uniformTypeIdentifiers: ['public.json']),
  ]);
  if (file == null) return null;
  try {
    return jsonDecode(await file.readAsString());
  } on FormatException {
    throw ApiException('Esse arquivo não é um export do maimoni');
  }
}
