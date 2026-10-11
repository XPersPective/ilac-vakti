import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "ilac_vakti/private_records",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getDirectory" || call.method == "protectFiles" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard call.arguments == nil else {
        result(FlutterError(code: "invalid_arguments", message: "No arguments accepted", details: nil))
        return
      }
      do {
        let manager = FileManager.default
        let support = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                      appropriateFor: nil, create: true)
        let directory = support.resolvingSymlinksInPath().appendingPathComponent("private-records", isDirectory: true)
        guard directory.standardizedFileURL == directory.resolvingSymlinksInPath().standardizedFileURL else {
          throw CocoaError(.fileWriteNoPermission)
        }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.protect(directory)
        for name in ["records-0.ivault", "records-1.ivault"] {
          let file = directory.appendingPathComponent(name)
          guard file.standardizedFileURL == file.resolvingSymlinksInPath().standardizedFileURL else {
            throw CocoaError(.fileWriteNoPermission)
          }
          var isDirectory: ObjCBool = false
          if manager.fileExists(atPath: file.path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else { throw CocoaError(.fileWriteNoPermission) }
            try Self.protect(file)
          }
        }
        if call.method == "getDirectory" {
          result(directory.path)
        } else {
          result(true)
        }
      } catch {
        result(FlutterError(code: "protection_failed", message: "Private storage unavailable", details: nil))
      }
    }
  }

  private static func protect(_ url: URL) throws {
    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    var target = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try target.setResourceValues(values)
    guard try target.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else {
      throw CocoaError(.fileWriteNoPermission)
    }
  }
}
