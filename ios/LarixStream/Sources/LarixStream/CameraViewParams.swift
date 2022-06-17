import CoreGraphics

public struct CameraViewParams {
    public var scale: CGFloat // Window size relative to full size
    public var alignX: CGFloat // Window horizontal position: 0.0 - left, 1.0 - right
    public var alignY: CGFloat // Window vertical position: 0.0 - botton, 1.0 - top

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
    
    public init(_ s: String) {
        let strArr = s.split(separator: ":")
        if strArr.count < 3 {
            scale = 0.5
            alignX = 1.0
            alignY = 1.0
            return
        }
        let floatArr = strArr.map { s in
            return Double(s)
        }
        scale = floatArr[0] ?? 0.5
        alignX = floatArr[1] ?? 1.0
        alignY = floatArr[2] ?? 1.0
    }
    
    public func toString() -> String {
        return String(format: "%1.7f:%1.7f:%1.7f", scale, alignX, alignY)
    }
    
}
