import Flutter
import UIKit
import FBSDKCoreKit // เปลี่ยนจาก FacebookCore เป็นตัวนี้ เพราะมันเป็นชื่อหลักของ SDK

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // เรียกใช้ผ่านชื่อเต็มเพื่อให้ Xcode หาเจอแน่นอน
    FBSDKCoreKit.ApplicationDelegate.shared.application(
        application,
        didFinishLaunchingWithOptions: launchOptions
    )
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}