import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/app_info.dart';

void main() {
  test('the version in Settings matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });
}
