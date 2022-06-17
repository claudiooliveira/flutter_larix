import Foundation
import AVFoundation


public class FpsRange: Equatable, Hashable {
    public let fpsMin: Float64
    public let fpsMax: Float64
    
    init(fpsMin: Float64, fpsMax: Float64) {
        self.fpsMin = fpsMin
        self.fpsMax = fpsMax
    }
    public static func == (lhs: FpsRange, rhs: FpsRange) -> Bool {
        return lhs.fpsMin == rhs.fpsMin && lhs.fpsMax == rhs.fpsMax
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fpsMin)
        hasher.combine(fpsMax)
    }
    
}

extension CMVideoDimensions: Equatable, Hashable, Comparable {
    public static func < (lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        return lhs.height < rhs.height || (lhs.height == rhs.height && lhs.width < rhs.width)
    }
    
    public static func == (lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
    
    
}

public class CameraInfo: NSObject {
    
    init(cameraId: String) {
        //com.apple.avfoundation.avcapturedevice.built-in_video:N
        if cameraId.contains("built-in_video"), let pos = cameraId.lastIndex(of: ":") {
            let strPos = cameraId.index(after: pos)
            self.cameraId = String(cameraId.suffix(from: strPos))
        } else {
            self.cameraId = cameraId
        }
        super.init()
    }
    
    public var cameraId: String
    public var recordSizes: [CMVideoDimensions] = []
    public var lensFacing: String = "unknown"
    public var deviceType: String = "wide"
    public var fpsRanges: [FpsRange] = []
    public var maxZoom: Float = 1.0
    public var isTorchSupported: Bool = false
    public var physicalCameras: [String] = []
    public var physicalZoomFactors: [Float] = []

    @objc func toDictionary() -> NSDictionary {
        let rangeStr: [String] = fpsRanges.map { range in
            if range.fpsMin == range.fpsMax {
                return String(format:"%d", Int(range.fpsMin))
            } else {
                return String(format:"%d-%d", Int(range.fpsMin), Int(range.fpsMax))
            }
        }
        let resStr: [String] = recordSizes.map { res in
            return String(format: "%dx%d", res.width, res.height)
        }
        return [
            "cameraId": NSString(string: cameraId),
            "recordSizes": resStr as NSArray,
            "lensFacing": NSString(string: lensFacing),
            "deviceType": NSString(string: deviceType),
            "fpsRanges": rangeStr as NSArray,
            "maxZoom": NSNumber(value: maxZoom),
            "isTorchSupported": NSNumber(booleanLiteral: isTorchSupported)
        ]
    }
}
