/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Treiber für Integrationstests mit Screenshots.
//
// Im iOS-Simulator liefert `takeScreenshot` aus dem Test nur weiße Bilder,
// deshalb holt der Treiber das Bild über `xcrun simctl io <udid> screenshot`.
// Umgebung: SIM_UDID (Simulator), SCREENSHOT_DIR (Ablage, Standard
// build/screenshots).
//
//   SIM_UDID=… SCREENSHOT_DIR=… flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/shopping_screenshots_test.dart -d <udid>

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final env = Platform.environment;
  final dir = env['SCREENSHOT_DIR'] ?? 'build/screenshots';
  final udid = env['SIM_UDID'];
  await Directory(dir).create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final path = '$dir/$name.png';
      if (udid != null && udid.isNotEmpty) {
        final r = await Process.run('xcrun', [
          'simctl',
          'io',
          udid,
          'screenshot',
          path,
        ]);
        return r.exitCode == 0;
      }
      await File(path).writeAsBytes(bytes);
      return true;
    },
  );
}
