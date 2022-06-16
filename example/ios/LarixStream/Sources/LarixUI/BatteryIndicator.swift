import Foundation
import UIKit

public class BatteryIndicator: CALayer {
    public var displayThreshold: CGFloat = 100 // In percents
    public var yellowThreshold: CGFloat = 35
    public var redThreshold: CGFloat = 25

    private var outline = CAShapeLayer()
    private var fillBar = CALayer()
    private var boltLayer = CALayer()
    private let textRect = CATextLayer()

    private var boltIcon: CGImage?
    
    private let showPercent: Bool = false
    private var observing = false
    private var batteryCharge: CGFloat = 0.5
    private var batteryState: UIDevice.BatteryState = .unknown
    let circleRadius: CGFloat = 3.0
    
    override public func layoutSublayers() {
        super.layoutSublayers()
        if outline.path == nil {
            var rect = bounds
            rect.size.width -= circleRadius
            let batteryShape = CGMutablePath()
            batteryShape.addRoundedRect(in: rect, cornerWidth: 3.0, cornerHeight: 3.0)
            let arcCenter = CGPoint(x: bounds.maxX - circleRadius, y: bounds.midY)
            batteryShape.addArc(center: arcCenter, radius: circleRadius, startAngle: -CGFloat.pi * 0.5, endAngle: CGFloat.pi * 0.5, clockwise: false)
            outline.lineWidth = 1.0
            outline.strokeColor = UIColor.white.cgColor
            outline.fillColor = UIColor.clear.cgColor
            outline.path = batteryShape
            addSublayer(outline)
            addSublayer(fillBar)
            
            if showPercent {
                let textR =  CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width - circleRadius , height:bounds.height)
                textRect.bounds = CGRect(x: 0.0, y: 0.0, width: textR.width, height: textR.height)
                textRect.position = CGPoint(x:textR.midX, y:textR.midY)
                textRect.string = NSString("100%")
                textRect.fontSize = 8
                textRect.contentsScale = UIScreen.main.scale
                textRect.foregroundColor = UIColor.white.cgColor
                textRect.alignmentMode = .center
                addSublayer(textRect)
            }
        }
        if #available(iOS 13.0, *) {
            if boltIcon == nil {
                if let img = UIImage(systemName: "bolt.fill") {
                    let context = CIContext()
                    if let ciImage = CIImage(image: img),
                       let filter = CIFilter(name: "CIColorInvert"){
                        filter.setDefaults()
                        filter.setValue(ciImage, forKey: kCIInputImageKey)
                        boltIcon = context.createCGImage(filter.outputImage!, from: ciImage.extent)
                    }
                }
            }
            boltLayer.contents = boltIcon
            let h = bounds.height + 2
            let w = CGFloat(boltIcon!.width) * h / CGFloat(boltIcon!.height)
            boltLayer.frame = CGRect(x: bounds.midX - (w + circleRadius) / 2.0, y: bounds.minY - 1, width: w, height: h)
            boltLayer.contentsScale = UIScreen.main.scale

            addSublayer(boltLayer)
        }
        batteryUpdate()
        textRect.string = NSString(format: "%3.0f", batteryCharge * 100)
        
        var rect = bounds.insetBy(dx: 2.0, dy: 1.0)
        var color = UIColor.systemGreen.cgColor
        if batteryState == .unknown {
            color = UIColor.systemGray.cgColor
        } else {
            rect.size.width = max(2.0,(rect.width - circleRadius) * batteryCharge)
            
            if batteryCharge * 100 < redThreshold {
                color = UIColor.systemRed.cgColor
            } else if batteryCharge * 100 < yellowThreshold {
                color = UIColor.systemYellow.cgColor
            }
        }
        boltLayer.isHidden = batteryState != .charging
        textRect.isHidden = !showPercent || batteryState == .charging
        if boltIcon == nil && (batteryState == .charging || batteryState == .full) {
            outline.strokeColor = UIColor.systemGreen.cgColor
        } else {
            outline.strokeColor = UIColor.white.cgColor
        }
        fillBar.frame = rect
        fillBar.cornerRadius = 2.0
        fillBar.backgroundColor = color
        fillBar.borderWidth = 0
        //isHidden = batteryCharge * 100 > displayThreshold
        let hidden = ceil(batteryCharge * 100) > displayThreshold
        outline.isHidden = hidden
        fillBar.isHidden = hidden
        
    }
    
    override public func removeFromSuperlayer() {
        UIDevice.current.isBatteryMonitoringEnabled = false
        if observing {
            NotificationCenter.default.removeObserver(self, name: UIDevice.batteryLevelDidChangeNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIDevice.batteryStateDidChangeNotification
                                                      , object: nil)
            observing = false
        }
        super.removeFromSuperlayer()
    }
    
    func batteryUpdate() {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        if !observing {
            NotificationCenter.default.addObserver(self, selector: #selector(onBatteryChange), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(onBatteryChange), name: UIDevice.batteryStateDidChangeNotification, object: nil)
            observing = true
        }
        batteryCharge = CGFloat(device.batteryLevel)
        batteryState = device.batteryState
    }
    
    @objc func onBatteryChange(_ notification: Notification) {
        let device = UIDevice.current
        if abs(CGFloat(device.batteryLevel) - batteryCharge) < 0.001 && batteryState == device.batteryState {
            return
        }
        batteryCharge = CGFloat(device.batteryLevel)
        batteryState = device.batteryState
        setNeedsLayout()
    }

}

