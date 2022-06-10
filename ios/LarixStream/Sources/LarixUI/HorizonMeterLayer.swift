import Foundation
import UIKit
import CoreMotion

fileprivate extension Double {
    var toDegree: Double {
        return self / Self.pi * 180.0
    }
}

public class HorizonMeterLayer: CALayer {
    let rollBubble = HorizonBubble()  //left-right
    let pitchBubble = HorizonBubble() //up-down
    let straitLine = CAShapeLayer()
    let motion = CMMotionManager()

    public var landscape: Bool = false
    public var displayWidth: CGFloat = 0.0
    public var displayHeight: CGFloat = 0.0
    
    private let queue = OperationQueue()

    public func startQueuedUpdates() {
        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 1.0 / 8.0
            // DeviceMotion's attitude give some odd results, calculate rotation from accelerometer data instead
            motion.startAccelerometerUpdates(to: queue) { (data: CMAccelerometerData?, err: Error?) in
                if let validData = data {
                    let acc = validData.acceleration
                    let a = atan2(acc.x, acc.y)
                    var roll = self.landscape ? a + Double.pi / 2.0 : a + Double.pi
                    roll.formTruncatingRemainder(dividingBy: Double.pi)
                    if roll > Double.pi / 2.0 {
                        roll -= Double.pi
                    }
                    let pitch = acc.z

                DispatchQueue.main.async {
                    let rollTransform = CGAffineTransform(rotationAngle: CGFloat(roll))
                    self.rollBubble.setAffineTransform(rollTransform)
                    let offset = self.displayHeight * CGFloat(pitch) * 0.4
                    let pitchTransform = CGAffineTransform(translationX: 0, y: offset)
                    self.pitchBubble.setAffineTransform(pitchTransform)
                    var aDeg = abs(roll).toDegree
                    if aDeg > 120.0 {
                        aDeg = abs(aDeg - 180.0)
                    }
                    if aDeg < 0.5 {
                        //Green if tilt is less than 0.5º
                        self.rollBubble.strokeColor = UIColor(hue: 0.3, saturation: 1.0, brightness: 0.7, alpha: 0.7).cgColor
                    } else if aDeg < 2.0 {
                        //Yellow if tilt is less than 2º
                        self.rollBubble.strokeColor = UIColor(hue: 0.15, saturation: 1.0, brightness: 0.7, alpha: 0.7).cgColor
                    } else {
                        self.rollBubble.strokeColor = UIColor(hue: 0.0, saturation: 0.0, brightness: 0.7, alpha: 0.7).cgColor
                    }
                }
             }
          }
       }
    }
    
    public func stopQueuedUpdates() {
        motion.stopAccelerometerUpdates()
    }
    
    override public func layoutSublayers() {
        if displayWidth == 0 && displayHeight == 0 {
            createLayers(displayFrame: frame)
        }
        if abs(frame.width + frame.height - displayHeight - displayWidth) > 0.01 {
            sizeLayers(displayFrame: frame)
        }
        arrangeLayers(displayFrame: frame)
    }
    
    internal func createLayers(displayFrame: CGRect) {
        let whiteColor = UIColor(hue: 0.0, saturation: 0.0, brightness: 0.7, alpha: 0.7)
        let blueColor = UIColor(hue: 0.5, saturation: 0.3, brightness: 0.7, alpha: 0.7)

        rollBubble.strokeColor = whiteColor.cgColor
        pitchBubble.strokeColor = blueColor.cgColor
        straitLine.strokeColor = whiteColor.cgColor
        
        straitLine.path = linePath(width: 10.0)

        addSublayer(straitLine)
        addSublayer(pitchBubble)
        addSublayer(rollBubble)
    }
    
    internal func sizeLayers(displayFrame: CGRect) {
        let width = min(displayFrame.width, displayFrame.height) * 0.5
        let height = width * 0.33
        rollBubble.bounds = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        pitchBubble.bounds = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        
        straitLine.path = linePath(width: width * 0.75)
    }
    
    internal func linePath(width: CGFloat) -> CGMutablePath {
        let line = CGMutablePath()
        line.move(to: CGPoint(x: -width / 3.0, y: 0))
        line.addLine(to: CGPoint(x: width / 3.0, y: 0))
        line.closeSubpath()
        return line
    }

    internal func arrangeLayers(displayFrame: CGRect) {
        if displayWidth == displayFrame.width && displayHeight == displayFrame.height {
            return
        }
        displayWidth = displayFrame.width
        displayHeight = displayFrame.height
        landscape = displayFrame.width > displayFrame.height

        let centerPoint = CGPoint(x: displayFrame.midX, y: displayFrame.midY)
        rollBubble.position = centerPoint
        pitchBubble.position = centerPoint
        straitLine.position = centerPoint
    }
}
