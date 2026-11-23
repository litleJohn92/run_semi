import Flutter
import UIKit
import UserNotifications
import CoreMotion

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RunSemiPedometer") {
      FlutterEventChannel(name: "run_semi/pedometer", binaryMessenger: registrar.messenger())
        .setStreamHandler(pedometerHandler)
    }
  }

  private let pedometerHandler = PedometerStreamHandler()
}

/// Envoie l'allure courante (s/m) calculée par CMPedometer à partir de l'accéléromètre.
class PedometerStreamHandler: NSObject, FlutterStreamHandler {
  private let pedometer = CMPedometer()

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CMPedometer.isPaceAvailable() else {
      return FlutterError(code: "unavailable", message: "Allure podomètre indisponible", details: nil)
    }
    pedometer.startUpdates(from: Date()) { data, _ in
      DispatchQueue.main.async { events(data?.currentPace?.doubleValue) }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    pedometer.stopUpdates()
    return nil
  }
}
