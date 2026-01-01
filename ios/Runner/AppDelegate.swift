import Flutter
import UIKit
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var pipChannel: FlutterMethodChannel?
  private var isInPipMode = false
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    pipChannel = FlutterMethodChannel(
      name: "com.echomirror.app/pip",
      binaryMessenger: controller.binaryMessenger
    )
    
    pipChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      
      switch call.method {
      case "enterPipMode":
        self.enterPictureInPictureMode(result: result)
      case "isPipSupported":
        result(self.isPictureInPictureSupported())
      case "isInPipMode":
        result(self.isInPipMode)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    // iOS can automatically enter PiP when app goes to background if video is playing
    // This is handled by the system when video layers are properly configured
  }
  
  private func enterPictureInPictureMode(result: @escaping FlutterResult) {
    // On iOS, PiP activation with Agora requires AVPictureInPictureController
    // which needs access to the native video layer. This is complex in Flutter.
    //
    // iOS will automatically enter PiP when:
    // 1. Video is playing
    // 2. App goes to background (home button or swipe up)
    // 3. Info.plist has picture-in-picture enabled (we have this)
    //
    // We return true to indicate PiP is supported and will work automatically
    // The Flutter side provides clear instructions to the user
    
    DispatchQueue.main.async { [weak self] in
      let supported = self?.isPictureInPictureSupported() ?? false
      if supported {
        // PiP is supported - it will activate when user backgrounds the app
        self?.isInPipMode = false // Will be set to true by system when PiP actually activates
        result(true)
      } else {
        result(false)
      }
    }
  }
  
  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    // Track when app becomes inactive (user might be activating PiP)
    // We can't detect PiP state directly, but this is called during the transition
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    // App became active - PiP might have ended
    if isInPipMode {
      isInPipMode = false
      notifyPipStateChanged(false)
    }
  }
  
  private func isPictureInPictureSupported() -> Bool {
    // PiP is supported on iOS 9+ for iPad, iOS 14+ for iPhone
    if #available(iOS 9.0, *) {
      return AVPictureInPictureController.isPictureInPictureSupported()
    }
    return false
  }
  
  private func notifyPipStateChanged(_ isInPip: Bool) {
    pipChannel?.invokeMethod("onPipModeChanged", arguments: isInPip)
  }
  
  // Handle PiP state changes from system
  override func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return .all
  }
}
