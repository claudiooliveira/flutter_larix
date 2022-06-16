import Foundation
import UIKit

public class GridLayer: CALayer {
    public var streamWidth: Int = 1920
    public var streamHeight: Int = 1080
    public var fillScreen: Bool = true
    
    public var gridLinesX: Int = 3
    public var gridLinesY: Int = 3
    
    public var rectMargin: CGFloat = 0.1
    public var rectRatio: [Float] = []
    
    private var gridShape = CAShapeLayer()
    private var marginPath = CAShapeLayer()
    private var marginVideoRatioPath = CAShapeLayer()

    override public func layoutSublayers() {
        let w = max(bounds.width, bounds.height)
        let h = min(bounds.height, bounds.width)
        let rotate = bounds.height > bounds.width
        let videoRatio = CGFloat(streamWidth) / CGFloat(streamHeight)
        let screenRatio = w / h
        let screenW: CGFloat
        let screenH: CGFloat

        if (fillScreen && screenRatio > videoRatio) || (!fillScreen && screenRatio <= videoRatio) {
            screenW = w
            screenH = w / videoRatio
        } else {
            screenW = h * videoRatio
            screenH = h
        }
        let uiGreyColor = UIColor(hue: 0.0, saturation: 0.0, brightness: 0.8, alpha: 0.5)
        let transform = CGAffineTransform(rotationAngle: rotate ? CGFloat.pi * 0.5 : 0.0).translatedBy(x: 0, y: rotate ? -h : 0.0)

        if gridLinesX > 0 && gridLinesY > 0 {
            let gridPath = CGMutablePath()
            let xOffset = (w - screenW) / 2.0
            let yOffset = (h - screenH) / 2.0

            for x in 1..<gridLinesX {
                let xPos = screenW / CGFloat(gridLinesX) * CGFloat(x) + xOffset
                gridPath.move(to: CGPoint(x: xPos, y: yOffset))
                gridPath.addLine(to: CGPoint(x: xPos, y: screenH+yOffset))
            }
            for y in 1..<gridLinesY {
                let yPos = screenH / CGFloat(gridLinesY) * CGFloat(y) + yOffset
                gridPath.move(to: CGPoint(x: xOffset, y: yPos))
                gridPath.addLine(to: CGPoint(x: screenW+xOffset, y: yPos))
            }
            gridPath.closeSubpath()
            gridShape.strokeColor = uiGreyColor.cgColor
            gridShape.lineWidth = 2.0
            gridShape.path = gridPath
            gridShape.setAffineTransform(transform)
        }
        
        var redRect: CGRect?
        let frameRatio = screenW / screenH
        let cropPath = CGMutablePath()
        for ratio in rectRatio {
            let c = 1.0 - rectMargin
            let ratioF = CGFloat(ratio)
            let rectW: CGFloat
            let rectH: CGFloat
            if frameRatio > ratioF {
                rectH = screenH * c
                rectW = screenH * ratioF * c
            } else {
                rectW = screenW * c
                rectH = screenW / ratioF * c
            }
            let offsetX = (w - rectW) / 2.0
            let offsetY = (h - rectH) / 2.0
            
            let rect = CGRect(x: offsetX, y: offsetY, width: rectW, height: rectH)
            
            if abs(ratioF - videoRatio) < 0.01 {
                //Draw rect with video ratio later
                redRect = rect
            } else {
                cropPath.addRect(rect)
            }
        }
        if !cropPath.isEmpty {
            let uiYellowColor = UIColor(hue: 0.17, saturation: 1.0, brightness: 0.8, alpha: 0.5)
            marginPath.fillColor = UIColor.clear.cgColor
            marginPath.strokeColor = uiYellowColor.cgColor
            marginPath.lineWidth = 2.0
            marginPath.path = cropPath
            marginPath.setAffineTransform(transform)
        }
        if let rect = redRect {
            let cropPath = CGMutablePath()
            let uiRedColor = UIColor(hue: 0.0, saturation: 1.0, brightness: 0.8, alpha: 0.5)
            cropPath.addRect(rect)
            cropPath.closeSubpath()
            marginVideoRatioPath.fillColor = UIColor.clear.cgColor
            marginVideoRatioPath.strokeColor = uiRedColor.cgColor
            marginPath.lineWidth = 2.0
            marginVideoRatioPath.path = cropPath
            marginVideoRatioPath.setAffineTransform(transform)
        }
        if sublayers?.isEmpty != false {
            if gridShape.path != nil {
                addSublayer(gridShape)
            }
            if marginPath.path != nil {
                addSublayer(marginPath)
            }
            if marginVideoRatioPath.path != nil {
                addSublayer(marginVideoRatioPath)
            }
        }

    }


}
