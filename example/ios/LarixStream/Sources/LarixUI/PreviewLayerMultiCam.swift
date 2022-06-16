import Foundation
import AVFoundation
import UIKit

public enum MultiCamPicturePosition {
    /// Multi-camera disabled
    case off
    /// Compose front camera for PIP image, back camera as main image
    case pip_front
    /// Compose back camera for PIP image, front camera as main image
    case pip_back
    /// Compose back camera on left side, front camera on right side
    case left_front
    /// Compose front camera on left side, back camera on right side
    case left_back
    
    public var opposite: MultiCamPicturePosition {
        switch self {
            
        case .off:
            return .off
        case .pip_front:
            return .pip_back
        case .pip_back:
            return .pip_front
        case .left_front:
            return .left_back
        case .left_back:
            return .left_front
        }
    }
    
    public var isPip: Bool {
        return self == .pip_back || self == .pip_front
    }
    
    public var isSbs: Bool {
        return self == .left_front || self == .left_back
    }
}

public struct PipPosition {
    public var scale: CGFloat // PIP size relative to full size
    public var alignX: CGFloat // Horizontal PIP position: 0.0 - left, 1.0 - right
    public var alignY: CGFloat // Vertical PIP position: 0.0 - botton, 1.0 - top

    public init() {
        scale = 0.5
        alignX = 1.0
        alignY = 1.0
    }
    
    public init(scale: CGFloat, alignX: CGFloat, alignY: CGFloat) {
        self.scale = scale
        self.alignX = alignX
        self.alignY = alignY
    }
}

@available(iOS 13.0, *)
public class PreviewLayerMultiCam: PreviewLayer {
    
    public var portraitMode: Bool = false
    public var getCameraPosition: (() -> MultiCamPicturePosition)? = nil
    public var pipPosition = PipPosition()
    public var aspectRatio: CGFloat = 16.0 / 9.0
    
    public private(set) var frontPreviewLayer: AVCaptureVideoPreviewLayer?  //Preview from front camera
    public private(set) var backPreviewLayer: AVCaptureVideoPreviewLayer?   //Preview from back camera
    
    override public var videoOrientation: AVCaptureVideoOrientation {
        didSet {
            frontPreviewLayer?.connection?.videoOrientation = videoOrientation
            backPreviewLayer?.connection?.videoOrientation = videoOrientation
        }
    }
    
    public func createPreview(session: AVCaptureSession) {
        let backPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        let frontPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)

        backPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        frontPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        
        layer.addSublayer(backPreviewLayer)
        layer.insertSublayer(frontPreviewLayer, above: backPreviewLayer)
        self.frontPreviewLayer = frontPreviewLayer
        self.backPreviewLayer = backPreviewLayer
    }
    
    public override func layoutSubviews() {

        guard let getPosFn = getCameraPosition else {
            return
        }

        let pipPos: MultiCamPicturePosition = getPosFn()
        if pipPos.isPip {
            layoutPip(pipPos: pipPos)

        } else {
            layoutSbs(pipPos: pipPos)
        }
    }
    
    func layoutPip(pipPos: MultiCamPicturePosition) {
        guard let fullLayer = pipPos == .pip_front ? backPreviewLayer : frontPreviewLayer,
            let pipLayer = pipPos == .pip_back ? backPreviewLayer : frontPreviewLayer else {
                return
        }
        pipLayer.removeFromSuperlayer()
        fullLayer.removeFromSuperlayer()

        pipLayer.frame = getPipRect(pipPosition)
        if let mainPos = previewRect {
            fullLayer.frame = getPipRect(mainPos)
        } else {
            fullLayer.frame = layer.frame
        }
        layer.addSublayer(fullLayer)
        layer.insertSublayer(pipLayer, above: fullLayer)
    }
    
    func getPipRect(_ pos: PipPosition) -> CGRect {
        let viewFrame = layer.frame
        let viewWidth = viewFrame.width
        let viewHeight = viewFrame.height

        let scale = pos.scale
        let alignX = pos.alignX
        let alignY = pos.alignY
        var pipW = viewWidth * scale
        var pipH = viewHeight * scale
        var posX = viewWidth * (1 - scale) * alignX
        var posY = viewHeight * (1 - scale) * alignY
        let viewPortrait = videoOrientation == .portrait || videoOrientation == .portraitUpsideDown
        let videoWidth: CGFloat
        let videoHeight: CGFloat
        if viewPortrait {
            videoWidth = viewHeight / aspectRatio
            videoHeight = viewWidth * aspectRatio
        }
        else {
            videoWidth = viewHeight * aspectRatio
            videoHeight = viewWidth / aspectRatio
        }
        if videoWidth < viewWidth {
            let subWidth = videoWidth
            let offset = (viewWidth - subWidth) / 2.0
            pipW = subWidth * scale
            posX = subWidth * (1 - scale) * alignX + offset
        } else {
            let subHeight = videoHeight
            let offset = (viewHeight - subHeight) / 2.0
            pipH = subHeight * scale
            posY = subHeight * (1 - scale) * alignY + offset
        }

        return CGRect(x: viewFrame.origin.x + posX, y: viewFrame.origin.y + posY, width: pipW, height: pipH)
    }
    
    func layoutSbs(pipPos: MultiCamPicturePosition) {
        guard let leftLayer = pipPos == .left_front ? frontPreviewLayer : backPreviewLayer,
            let rightLayer = pipPos == .left_front ? backPreviewLayer : frontPreviewLayer else {
                return
        }
        let viewFrame = layer.frame
        let viewWidth = viewFrame.width
        let viewHeight = viewFrame.height

        let leftFrame: CGRect
        let rightFrame: CGRect
        if portraitMode == false {
            leftFrame = CGRect(x: 0, y: 0, width: viewWidth / 2, height: viewHeight)
            rightFrame = CGRect(x: viewWidth / 2, y: 0, width: viewWidth / 2, height: viewHeight)
        } else {
            leftFrame =  CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight / 2)
            rightFrame = CGRect(x: 0, y: viewHeight / 2, width: viewWidth, height: viewHeight / 2)
        }
        leftLayer.frame = leftFrame.offsetBy(dx: viewFrame.origin.x, dy: viewFrame.origin.y)
        rightLayer.frame = rightFrame.offsetBy(dx: viewFrame.origin.x, dy: viewFrame.origin.y)
    }
    
    public override func getFocusTarget(_ touchPoint: CGPoint) -> (CGPoint?, AVCaptureDevice.Position) {
        var focusPoint: CGPoint?
        var position: AVCaptureDevice.Position = .unspecified
        guard  let getPosFn = getCameraPosition,
                let backPreview = backPreviewLayer, let frontPreview = frontPreviewLayer else {
            return (nil, .unspecified)
        }
        let previewPosition: MultiCamPicturePosition = getPosFn()
        if previewPosition == .off {
            return (nil, .unspecified)
        }
        let withinFront: Bool
        if previewPosition.isSbs {
            withinFront = frontPreview.frame.contains(touchPoint)
        } else {
            withinFront = (previewPosition == .pip_front && frontPreview.frame.contains(touchPoint)) || (previewPosition == .pip_back && !backPreview.frame.contains(touchPoint))
        }
        position = withinFront ? .front : .back
        if withinFront {
            let fpConvereted = layer.convert(touchPoint, to: frontPreview)
            focusPoint = frontPreview.captureDevicePointConverted(fromLayerPoint: fpConvereted)
        } else {
            let fpConvereted = layer.convert(touchPoint, to: backPreview)
            focusPoint = backPreview.captureDevicePointConverted(fromLayerPoint: fpConvereted)
        }
        if focusPoint == nil || focusPoint!.x < 0.0 || focusPoint!.x > 1.0 || focusPoint!.y < 0.0 || focusPoint!.y > 1.0 {
            return (nil, .unspecified)
        }
        return (focusPoint, position)
    }

}
