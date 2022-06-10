import Foundation
import AVFoundation

public enum MultiCamMode: String {
    case off = "off"
    case pip = "pip"
    case sideBySide = "sideBySide"
}
public struct MultiCamConfig {

    /// uniqueID of front camera
    public var frontCameraID: String
    /// uniqueID of back camera
    public var backCameraID: String
    public var primaryCameraPosition: AVCaptureDevice.Position
    /// Picture composition mode: picture-in-picture or side-by-side
    public var mode: MultiCamMode = .pip
    
    /// PIP scale relative to full size (valid only when mode == .pip )
    public var pipScale: CGFloat = 0.5
    /// Horizontal PIP position: 0.0 - left, 1.0 - right  (valid only when mode == .pip )
    public var alignX: CGFloat = 1.0
    /// Vertical PIP position: 0.0 - top, 1.0 - bottom  (valid only when mode == .pip )
    public var alignY: CGFloat = 1.0

    public init(frontCameraID: String, backCameraID: String,
                primaryCameraPosition: AVCaptureDevice.Position = .back,
                mode: MultiCamMode = .pip) {
        self.frontCameraID = frontCameraID
        self.backCameraID = backCameraID
        self.primaryCameraPosition = primaryCameraPosition
        self.mode = mode
    }
    
}
