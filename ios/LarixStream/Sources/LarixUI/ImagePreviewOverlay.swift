import Foundation
import UIKit

public class ImagePreviewOverlay: CALayer {
    public var streamWidth: Int = 1920
    public var streamHeight: Int = 1080
    public var fillScreen: Bool = true
    public var rotateQuad: Int = 0 // Rotation in quadrants (90º)
    public var virtualBlackBars: Bool = false
    public var flip: Bool = false {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    let imageLayer = CALayer()
    let pauseLayer = CALayer()

    public func setImage(_ image: CGImage?) {
        DispatchQueue.main.async {
            self.imageLayer.contents = image
            self.setNeedsLayout()
        }
    }
    
    public func setPause(_ paused: Bool) {
        imageLayer.isHidden = paused
        pauseLayer.isHidden = !paused
    }


    public func setPauseImage(_ image: CGImage?) {
        DispatchQueue.main.async {
            self.pauseLayer.contents = image
            self.setNeedsLayout()
        }
    }


    public override func layoutSublayers() {
        let w = rotateQuad % 2 == 0 ? bounds.width: bounds.height
        let h = rotateQuad % 2 == 0 ? bounds.height : bounds.width

        let videoRatio = CGFloat(streamWidth) / CGFloat(streamHeight)
        let screenRatio = w / h
        let screenW: CGFloat
        let screenH: CGFloat

        if (fillScreen && screenRatio > videoRatio) || (!fillScreen && screenRatio <= videoRatio) {
            if virtualBlackBars && videoRatio > 1.0 {
                screenH = w * videoRatio
                screenW = screenH * videoRatio
            } else {
                screenW = w
                screenH = w / videoRatio
            }
        } else {
            if virtualBlackBars && videoRatio < 1.0 {
                screenW = h / videoRatio
                screenH = screenW / videoRatio
            } else {
                screenW = h * videoRatio
                screenH = h
            }
        }
        let pauseW: CGFloat
        let pauseH: CGFloat
        if screenRatio > videoRatio {
            pauseW = w
            pauseH = pauseW / videoRatio
        } else {
            pauseH = h
            pauseW = pauseH * videoRatio
        }

        imageLayer.bounds = CGRect(x: 0, y: 0, width: screenW, height: screenH)
        if rotateQuad % 2 == 0 {
            imageLayer.position = CGPoint(x: w / 2.0, y: h / 2.0)
        } else {
            imageLayer.position = CGPoint(x: h / 2.0, y: w / 2.0)
        }
        pauseLayer.bounds = CGRect(x: 0, y: 0, width: pauseW, height: pauseH)
        pauseLayer.position = CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0)
        pauseLayer.opacity = 0.5
        if sublayers?.isEmpty != false {
            addSublayer(imageLayer)
            addSublayer(pauseLayer)
            pauseLayer.isHidden = true
        }
        var transform = CGAffineTransform(translationX: 0, y: 0)
        if flip {
            if rotateQuad % 2 == 0 {
                transform = transform.scaledBy(x: -1.0, y: 1.0)
            } else {
                transform = transform.scaledBy(x: 1.0, y: -1.0)
            }
        }
        transform = transform.rotated(by: CGFloat.pi * CGFloat(rotateQuad) / 2.0)
        imageLayer.setAffineTransform(transform)
    }

}
