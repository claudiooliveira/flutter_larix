import Foundation
import LarixSupport

public class StreamerBuilder {
    /// Streamer delegate, should be assigned prior to ``build()``
    public var delegate: StreamerAppDelegate?
    /// Video capture parameters. If you capture audio-only may skip it
    public var videoConfig: VideoConfig?
    /// Video capture parameters. If you capture video-only may skip it
    public var audioConfig: AudioConfig?
    /**
     Multi-camera capture. Assign if you want to capture from front and back cameras simultaneously
     - SeeAlso: [AVCaptureMultiCamSession](https://developer.apple.com/documentation/avfoundation/avcapturemulticamsession)
     */
    ///
    public var multiCamConfig: MultiCamConfig?
    
    /**
     Initial camera parameters
     */
    public var cameraConfig: CameraConfig
    
    public init() {
        cameraConfig = CameraConfig()
    }
    
    
    /** Create streamer instance
    - Returns either StreamerSingleCam or StreamerMultiCam depending on ``multiCamConfig``
     */
    public func build() -> Streamer {
        var multiStreamer: Streamer? = nil
        if multiCamConfig != nil && multiCamConfig?.mode != .off {
            multiStreamer = createMultiCam()
        }
        let result = multiStreamer ?? StreamerSingleCam()
        result.delegate = delegate
        result.videoConfig = videoConfig
        result.audioConfig = audioConfig
        result.cameraConfig = cameraConfig
        return result
    }
    
    private func createMultiCam() -> Streamer? {
        guard #available(iOS 13.0, *) else {
            LarixLogger.put(message: "Multi-camera is not available on iOS 12", severity: .error, priority: .high)
            return nil
        }
        guard let videoConfig = videoConfig, var multiCamConfig = multiCamConfig else {
            return nil
        }

        if StreamerMultiCam.probeMultiCam(videoConfig: videoConfig, cameraConfig: multiCamConfig) == false {
            guard let backCamera = CameraManager.getDefaultBackCamera(videoSize: videoConfig.videoSize, fps: videoConfig.fps, isMultCam: true) else {
                LarixLogger.put(message: "Can't create multi-camera with specified settings", severity: .error, priority: .high)
                return nil
            }
            multiCamConfig.backCameraID = backCamera.uniqueID
            LarixLogger.put(message: "Changed back camera to \(backCamera.localizedName)", severity: .error, priority: .high)
        }
        let multiStreamer = StreamerMultiCam()
        multiStreamer.multiCamConfig = multiCamConfig
        return multiStreamer
    }
    
    
}
