import Flutter
import UIKit

public class SwiftFlutterLarixPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
      let factory = FlutterLarixNativeViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "np-ablo-spanhou")
    
    let channel = FlutterMethodChannel(name: "br.com.devmagic.flutter_larix/nativeview", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterLarixPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
        case "initCamera":
            result("teste deu bom")
            break
        default:
            result("teste deu ruim")
    }
    result("iOS " + UIDevice.current.systemVersion)
  }
}
