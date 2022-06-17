import AVFoundation
import VideoToolbox
import LarixCore

public struct VideoConfig {
    public enum MultiCamMode: String {
        case off = "off"
        case pip = "pip"
        case sideBySide = "sideBySide"
    }
    
    public enum ProcessingMode {
        case disabled
        case coreImage
        case metal
    }
    /** Initial cameraID ([AVCaptureDevice.uniqueID](https://developer.apple.com/documentation/avfoundation/avcapturedevice/1390477-uniqueid) )
- Note: only valid for single-camera capture. For multi-camera, values from ``MultiCamConfig`` will be used instead.
     */
    public var cameraID: String
    /// Camera resolution
    public var videoSize: CMVideoDimensions
    /// Frame rate
    public var fps: Double
    /** Keyframe interval (GOP size) in seconds
- Note: will be multiplied by `fps` to set [MaxKeyFrameInterval](https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey_maxkeyframeinterval)
     */
    public var keyFrameIntervalDuration: Double = 2.0
    /// Video bitrate in bits/s - [AverageBitRate](https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey_averagebitrate)
    public var bitrate: Int
    /**  Birate limit - [DataRateLimits](https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey_dataratelimits)
- Note: Normally you don't need to set this, but in certain condition HEVC encoding would have artifacts untill you set this.
     Recommended value is bitrate * 2  */
    public var bitrateLimit: Int? = nil
    /// When true, stream in portait(vertical) orientaion
    public var portrait: Bool = false
    /// Video codec, either kCMVideoCodecType_H264 or kCMVideoCodecType_HEVC
    public var type: CMVideoCodecType = kCMVideoCodecType_H264
    /** Video profile level.
- Note:  For H264 should be kVTProfileLevel_H264_Baseline_AutoLevel, kVTProfileLevel_H264_Main_AutoLevel or kVTProfileLevel_H264_High_AutoLevel. For HEVC - either kVTProfileLevel_HEVC_Main_AutoLevel or kVTProfileLevel_HEVC_Main10_AutoLevel
     */
    public var profileLevel: CFString = kVTProfileLevel_H264_Baseline_AutoLevel
    /// Video processing mode: .none - disable rotation; .coreImage - rotate/scale using Core Image, .metal - using Metal shaders
    public var processingMode: ProcessingMode = .coreImage
    /** File writing mode: .sharingSession - send compressed frame (that was encoded for stream) to AVAssetWriter; .separateSession - send uncompressed audio/video frames and compress it with AVAssetWriter
- Note: .separateSession requires more resources for compression, but makes video files compatible with some tools like video editor on iOS
     */
    public var fileWritingMode: FileWritingMode = .sharedSession
    
    public var cameraWindow: CameraViewParams? = nil
        
    public init(cameraID: String, videoSize: CMVideoDimensions, fps: Double,
                keyFrameIntervalDuration: Double,
                bitrate: Int, bitrateLimit: Int? = nil,
                portrait: Bool,
                type: CMVideoCodecType = kCMVideoCodecType_H264,
                profileLevel: CFString = kVTProfileLevel_H264_Baseline_AutoLevel,
                processingMode: ProcessingMode = .coreImage,
                fileWritingMode: FileWritingMode = .sharedSession,
                camearaWindow: CameraViewParams? = nil) {
        self.cameraID = cameraID
        self.videoSize = videoSize
        self.fps = fps
        self.keyFrameIntervalDuration = keyFrameIntervalDuration
        self.bitrate = bitrate
        self.bitrateLimit = bitrateLimit
        self.portrait = portrait
        self.type = type
        self.profileLevel = profileLevel
        self.processingMode = processingMode
        self.fileWritingMode = fileWritingMode
        self.cameraWindow = camearaWindow
    }
    
    public var description: String {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        
        let codecDisplayName = type == kCMVideoCodecType_HEVC ? "HEVC" : "H.264"
        let width = String(videoSize.width)
        let height = String(videoSize.height)
        
        let profile = profileLevel as String
        let profileArr = profile.components(separatedBy: "_")
        let profileDisplayName = profileArr.count > 2 ? profileArr[1] : ""
        
        let message = String.localizedStringWithFormat(NSLocalizedString("%@ (%@), %@x%@", comment: ""), codecDisplayName, profileDisplayName, width, height)
        
        return message
    }
}
