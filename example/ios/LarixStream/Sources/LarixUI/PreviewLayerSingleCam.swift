import Foundation
import AVFoundation
import UIKit

public class PreviewLayerSingleCam: PreviewLayer {
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    public var getCameraPosition: (() -> AVCaptureDevice.Position)? = nil

    override public var videoOrientation: AVCaptureVideoOrientation {
        didSet {
            previewLayer?.connection?.videoOrientation = videoOrientation
        }
    }

    public func createPreview(session: AVCaptureSession) {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = fillMode
        layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }
    
    public override func layoutSubviews() {
        previewLayer?.frame = adjustedFrame
        
        let deviceOrientation = UIApplication.shared.statusBarOrientation
        let newOrientation: AVCaptureVideoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue) ?? .portrait
        
        if previewLayer?.connection?.isVideoOrientationSupported == true {
            previewLayer?.connection?.videoOrientation = newOrientation
        }
    }
    
    public override func getFocusTarget(_ touchPoint: CGPoint) -> (CGPoint?, AVCaptureDevice.Position) {
        var focusPoint: CGPoint?
        let position: AVCaptureDevice.Position
        if let fn = getCameraPosition {
            position = fn()
        } else {
            position = .unspecified
        }
        guard let previewLayer = previewLayer else { return (nil, .unspecified) }
        let fpConvereted = layer.convert(touchPoint, to: previewLayer)
        focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: fpConvereted)
        if focusPoint == nil || focusPoint!.x < 0.0 || focusPoint!.x > 1.0 || focusPoint!.y < 0.0 || focusPoint!.y > 1.0 {
            return (nil, .unspecified)
        }

        return (focusPoint, position)
    }

    override func updateFillMode() {
        previewLayer?.videoGravity = fillMode
        super.updateFillMode()
    }

}
