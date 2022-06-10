import Foundation
import AVFoundation

public enum CameraMeteringParameter: String {
    case Focus = "AF"
    case Exposure = "AE"
    case WhiteBalance = "AWB"
}

public typealias CameraMeteringParameters = Set<CameraMeteringParameter>

/** Preserved camera parameters
 You may re-initialize it when passed to CameraBuilder to reset all parameters to default
 */
public class CameraParameters {
    public var videoStabilizationMode: AVCaptureVideoStabilizationMode = .auto
    /// Zoom factor, 0 for default
    public var zoom: CGFloat = 0
    /// Color temperature (Kelvins), 0 for Auto
    public var colorTemperature: Float?
    /// Exposure compensation in EV steps
    public var exposureCompensation: Float = 0.0
    /// Set of locked parameters (Focus/Exposure/White balance)
    public var lockedParameters: CameraMeteringParameters = []
    public var pointOfInterest: CGPoint = CGPoint(x:0.5, y: 0.5)

    public init() {
        
    }
}

/** Set of ``CameraParameters`` for eack cameara position (back/front) */
public class CameraConfig {
    internal var params: [CameraParameters]
    public init() {
        params = []
        params.append(CameraParameters()) //Does we actually need element for .unspecified?
        params.append(CameraParameters())
        params.append(CameraParameters())
    }
    public func get(_ pos: AVCaptureDevice.Position) -> CameraParameters {
        let posInt = pos.rawValue
        return params[posInt]
    }
    
}

