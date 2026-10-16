/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerDeviceChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Kleine Brücke für das Profilbild: Kamera vorhanden? Einstellungen öffnen.
  private func registerDeviceChannel() {
    guard let registrar = self.registrar(forPlugin: "TogetherDoDevice") else { return }
    let channel = FlutterMethodChannel(
      name: "togetherdo/device",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "hasCamera":
        result(UIImagePickerController.isSourceTypeAvailable(.camera))
      case "openAppSettings":
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
