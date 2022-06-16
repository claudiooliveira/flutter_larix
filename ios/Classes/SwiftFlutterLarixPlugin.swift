import Flutter
import UIKit

public class SwiftFlutterLarixPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = FlutterLarixNativeViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "br.com.devmagic.flutter_larix/nativeview")
   
    let channel = FlutterMethodChannel(name: "br.com.devmagic.flutter_larix/nativeview_controller", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterLarixPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

   public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("chegou aqui pelo menos")
       switch call.method {
            case "initCamera":
                result("teste deu bom")
                break
            case "startStream":
                result("true")
                break
            case "stopStream":
                break
             case "flipCamera":
                // result(data)
                break
            case "stopAudioCapture":
                // result(dataAudioStop)
                break
            case "startAudioCapture":
                // result(dataAudioStart)
                break
            case "stopVideoCapture":
                result("true")
                break
            case "startVideoCapture":
                result("true")
                break
            case "setDisplayRotation":
                result("true")
                break
            case "toggleTorch":
                // result(mStreamerGL.isTorchOn() ? "true" : "false");
                break
            case "getPermissions":
                result("permissions")
                break
            case "requestPermissions":
                break
            case "initCamera":
                result("camera without permission")
                break
            case "disposeCamera":
                break
            default:
                result("not Implemented")
        }
    }


}
