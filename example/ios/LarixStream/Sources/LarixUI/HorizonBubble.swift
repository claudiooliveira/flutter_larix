import Foundation
import UIKit

class HorizonBubble: CAShapeLayer {
    func makePath() {
        let shape = CGMutablePath()
        let r = bounds.height / 2.0
        let cicleRect = CGRect(x: bounds.midX - r, y: bounds.minY-0.5, width: r*2.0, height: r*2.0+1.0)
        shape.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
        shape.addLine(to: CGPoint(x: bounds.midX - r, y: bounds.midY))
        shape.addEllipse(in: cicleRect)
        shape.move(to: CGPoint(x: bounds.midX + r , y: bounds.midY))
        shape.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
        shape.closeSubpath()
        
        lineWidth = 2.0
        fillColor = UIColor.clear.cgColor
        path = shape
    }
    
    override func layoutSublayers() {
        if path == nil {
            makePath()
        }
    }
}
