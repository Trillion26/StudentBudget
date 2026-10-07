import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the bundled Nunito font so screenshots look like the real app.
Future<void> loadAppFonts() async {
  final loader = FontLoader('Nunito');
  for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Nunito-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}
