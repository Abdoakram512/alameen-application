import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyShieldView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    configureScreenProtectionObservers()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureScreenProtectionObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScreenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(showPrivacyShield),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    if UIScreen.main.isCaptured {
      showPrivacyShield()
    }
  }

  @objc private func handleScreenCaptureChanged() {
    if UIScreen.main.isCaptured {
      showPrivacyShield()
    } else if UIApplication.shared.applicationState == .active {
      hidePrivacyShield()
    }
  }

  @objc private func handleDidBecomeActive() {
    if !UIScreen.main.isCaptured {
      hidePrivacyShield()
    }
  }

  @objc private func showPrivacyShield() {
    guard let keyWindow = window else { return }
    if privacyShieldView == nil {
      let shield = UIView(frame: keyWindow.bounds)
      shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      shield.backgroundColor = UIColor(red: 1.0 / 255.0, green: 35.0 / 255.0, blue: 131.0 / 255.0, alpha: 1.0)
      privacyShieldView = shield
    }
    if let shield = privacyShieldView, shield.superview == nil {
      shield.frame = keyWindow.bounds
      keyWindow.addSubview(shield)
      keyWindow.bringSubviewToFront(shield)
    }
  }

  private func hidePrivacyShield() {
    privacyShieldView?.removeFromSuperview()
  }
}
