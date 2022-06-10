import Foundation
import UIKit
import AVFoundation

public struct CamViewPosition {
    public var scaleX: CGFloat // Horizontal size relative to full size
    public var scaleY: CGFloat // Vertical size relative to full size
    public var alignX: CGFloat // Horizontal position: 0.0 - left, 1.0 - right
    public var alignY: CGFloat // Vertical position: 0.0 - botton, 1.0 - top

    public init() {
        scaleX = 1.0
        scaleY = 1.0
        alignX = 0.0
        alignY = 0.0
    }
    
    public init(scaleX: CGFloat, scaleY: CGFloat, alignX: CGFloat, alignY: CGFloat) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.alignX = alignX
        self.alignY = alignY
    }
}


public class PreviewLayer: UIView {
    public var fillMode: AVLayerVideoGravity = .resizeAspectFill {
        didSet {
            updateFillMode()
        }
    }
    
    // Rectantle in relative coordinates reduced to 0..1 range
    public var previewRect: PipPosition? = nil {
        didSet {
            updateFillMode()
        }
    }
    
    public var adjustedFrame: CGRect {
        guard let previewRect = previewRect else {
            return layer.frame
        }
        let frame = layer.frame
        let originW = frame.width
        let originH = frame.height
        
        let x = previewRect.alignX * (1.0-previewRect.scale) * originW
        let y = previewRect.alignY * (1.0-previewRect.scale) * originH
        let w = previewRect.scale * originW
        let h = previewRect.scale * originH
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    public var videoOrientation: AVCaptureVideoOrientation = .portrait

    internal var parent: UIView

    public init(parent: UIView) {
        let rect = parent.frame
        self.parent = parent
        super.init(frame: rect)
        parent.insertSubview(self, at: 0)
        addConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func addConstraints() {
//        var constraints: [NSLayoutConstraint] = []
//        constraints.append(topAnchor.constraint(equalTo: parent.topAnchor))
//        constraints.append(bottomAnchor.constraint(equalTo: parent.bottomAnchor))
//        constraints.append(leadingAnchor.constraint(equalTo: parent.leadingAnchor))
//        constraints.append(trailingAnchor.constraint(equalTo: parent.trailingAnchor))
//        NSLayoutConstraint.activate(constraints)
     }
    
    public func getFocusTarget(_ touchPoint: CGPoint) -> (CGPoint?, AVCaptureDevice.Position) {
        return (nil, .unspecified)
    }
    
    internal func updateFillMode() {
        setNeedsLayout()
    }

    
}
