import Foundation
import UIKit

public class ZoomIndicator: CALayer {
    
    public var zoom: CGFloat = 1.0 {
        didSet {
            if initZoom == 0 {
                initZoom = zoom
            }
            isHidden = false
            autoHideTimer?.invalidate()
            if hideTimeout > 0 {
                autoHideTimer = Timer.scheduledTimer(withTimeInterval: hideTimeout, repeats: false) { [weak self] (_) in
                    self?.isHidden = true
                }
            }
            self.setNeedsLayout()
        }
    }
    public var maxZoom: CGFloat = 1.0
    public var initZoom: CGFloat = 0.0
    public var zoomLevels: [CGFloat] = []
    public var hideTimeout: TimeInterval = 2.0
    
    private let frameShape = CAShapeLayer()
    private let meterShape = CAShapeLayer()
    private let markShape = CAShapeLayer()
    private let ticksShape = CAShapeLayer()
    private let textRect = CATextLayer()
    private let barWidth: CGFloat = 8.0
    
    private var autoHideTimer: Timer?
    
    override public func layoutSublayers() {
        super.layoutSublayers()

        if frameShape.path == nil {
            let box = CGMutablePath()
            let boxRect = CGRect(x: bounds.maxX - barWidth, y: bounds.minY, width: barWidth, height: bounds.height)
            box.addRoundedRect(in: boxRect, cornerWidth: barWidth / 2.0, cornerHeight: barWidth / 2.0)
            frameShape.fillColor = UIColor(white: 0.5, alpha: 0.8).cgColor
            frameShape.path = box
            addSublayer(frameShape)
        }
        if meterShape.path == nil {
            meterShape.lineWidth = 0.0
            meterShape.fillColor = UIColor(white: 1.0, alpha: 0.8).cgColor
            meterShape.anchorPoint = CGPoint(x:0.5, y:1.0)
            let rect = CGRect(x: bounds.maxX - barWidth, y: bounds.minY, width: barWidth, height: bounds.height)
            let box = CGMutablePath()
            box.addRoundedRect(in: rect, cornerWidth: barWidth / 2.0, cornerHeight: barWidth / 2.0)
            meterShape.path = box
            meterShape.masksToBounds = true
            meterShape.position = CGPoint(x: bounds.midX, y: bounds.maxY)
            addSublayer(meterShape)
            
            let textWidth:CGFloat = 30.0
            let textX = bounds.maxX - (barWidth + textWidth) / 2.0
            textRect.frame = CGRect(x: textX, y: bounds.minY - 18, width: textWidth, height: 16)
            textRect.string = NSString("1.0x")
            textRect.fontSize = 12.0
            textRect.backgroundColor = UIColor(white: 0.1, alpha: 0.5).cgColor
            textRect.cornerRadius = 8.0
            textRect.alignmentMode = .center
            textRect.foregroundColor = UIColor.white.cgColor
            textRect.contentsScale = UIScreen.main.scale

            addSublayer(textRect)
        }
        if markShape.path == nil {
            let triangle = CGMutablePath()
            let a = CGFloat.pi / 6.0
            let r:CGFloat = 10.0
            let cx = bounds.maxX - barWidth
            let cy = bounds.maxY
            triangle.move(to: CGPoint(x: cx, y: cy))
            triangle.addLine(to: CGPoint(x: cx - r, y: cy + tan(a) * r))
            triangle.addLine(to: CGPoint(x: cx - r, y: cy - tan(a) * r))
            triangle.closeSubpath()
            markShape.anchorPoint = CGPoint(x:1.0, y:0.5)
            markShape.path = triangle
            markShape.lineWidth = 0.0
            markShape.fillColor = UIColor(hue: 0.0, saturation: 0.9, brightness: 1.0, alpha: 0.6).cgColor
            
            addSublayer(markShape)
            
            if maxZoom > 1.0 && !zoomLevels.isEmpty {
                let ticks = CGMutablePath()
                for f in zoomLevels {
                    let posY = bounds.height * (1.0 - log(f) / log(maxZoom))
                    ticks.move(to: CGPoint(x: bounds.minX, y: posY))
                    ticks.addLine(to: CGPoint(x: bounds.maxX, y: posY))
                }
                ticksShape.path = ticks
            }
            ticksShape.lineWidth = 1.0
            ticksShape.strokeColor = UIColor(white: 0.0, alpha: 0.8).cgColor
            addSublayer(ticksShape)

        }
        let h = maxZoom <= 1.0 ? 0.0 : log(zoom) / log(maxZoom) * bounds.height
        meterShape.bounds = CGRect(x: bounds.minX, y: bounds.maxY, width: bounds.width, height: -h)
        markShape.position = CGPoint(x: 0, y: -h)
        textRect.string = NSString(format: "%2.1fx", initZoom == 0 ? zoom : zoom / initZoom)
    }

}
