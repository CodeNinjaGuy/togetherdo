/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// UIScene-Lebenszyklus (ab iOS 27 Pflicht): Plugins hängen an der Engine der Szene.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerDeviceChannel(engineBridge.pluginRegistry)
  }

  /// Kleine Brücke für das Profilbild: Kamera vorhanden? Einstellungen öffnen.
  private func registerDeviceChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "TogetherDoDevice") else { return }
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

/// Szene der App; in dieser Datei, damit das Xcode-Projekt unverändert bleibt.
class SceneDelegate: FlutterSceneDelegate {}
