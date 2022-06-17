import Foundation
import AVFoundation
import LarixCore
import LarixSupport
import LarixUI

public enum CaptureState {
    case setup
    case started
    case stopped
    case failed
    case canRestart
}

public enum CaptureStatus: Error {
    case success
    /// Failed to create video compression session. Check videoConfig
    case errorVideoEncoding
    /// AVCaptureSession failure
    case errorCaptureSession
    /// CIContext failure
    case errorCoreImage
    /**
     Microphone is used by other process. Can happed during incoming call.
     Streamer will start producing black frames until microphoe will be returned (call rejected) or session interruped (call accepted)
     */
    case errorMicInUse
    /// Camera is used by other process
    case errorCameraInUse
    /// No camera available
    case errorCameraUnavailable
    /// AVCaptureSession was interruped
    case errorSessionWasInterrupted
    case stepInitial
    case stepAudioSession
    case stepFilters
    case stepVideoEncoding
    case stepVideoIn
    case stepVideoOut
    case stepAudio
    case stepStillImage
    case stepSessionStart
}

public enum StreamerNotification {
    /// Camera was changed, sent after ``Streamer/changeCamera(to:)``
    case ActiveCameraDidChange
    /// Camera was failed to change, sent after ``Streamer/changeCamera(to:)``
    case ChangeCameraFailed
    case FrameRateNotSupported
    /// AVAudioSession.routeChangeNotification was called. Typically happen after external audio device (e.g. headset) was connected/disconnected
    case AudioSessionRouteChanged
    /// Called asynchronous after ``Streamer/continuousMetering(at:position:parameters:)`` and  ``Streamer/fixedMetering(at:position:parameters:)``
    case LockModeChanged
}

public protocol StreamerAppDelegate: AnyObject {
    /**
     Connection state was changed
     - Parameter id: ID of connection returned by ``Streamer/createConnection(config:)``
     - Parameter info: additional status information returned by server

     */
    func connectionStateDidChange(id: Int32, state: ConnectionState, status: ConnectionStatus, info: [AnyHashable:Any]!)
    /**
     Capture state was changed
     - Parameter state: capture state
     - Parameter status: value of ``CaptureStatus`` */
    func captureStateDidChange(state: CaptureState, status: Error)
    func notification(notification: StreamerNotification)
    /**
        Asyncrhonous result of ``Streamer/captureStillImage(fileUrl:format:)``
     */
    func snapshotStateDidChange(state: RecordState, fileUrl: URL?)
    
    /**
        Asyncrhonous result of  ``Streamer/startRecord(url:)`` , ``Streamer/stopRecord()``  or ``Streamer/switchRecord(nextFileUrl:)``
     */
    func recordStateDidChange(state: RecordState, fileUrl: URL?)
    
    /** Used by ``CompositeImageLayer`` when remote URL provided after saving to local file
     You may preserve image locally to skip downloading next time.
    - Parameter location: downloaded temporary file location
    - Parameter suggestedFilename: recomended name for file
    - Parameter layerId: ID of original layer
    - Returns: URL of file when you moved image to, or  `nil` to use from current location
     */
    func overlayDownloaded(location: URL, suggestedFilename: String, layer: ImageLayer) -> URL?

    func overlayError(error: ImageLayerError, layer: ImageLayer)

    
    /** Callback for audio buffer processing
     If you need to perform some manilulation, return updated result, otherwise return nil
- Parameter sampleBuffer: audio buffer
- Returns: `nil` to remain buffer unchanged, updated buffer if needed
     */
    func processsAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer?
    
    /** Callback for video buffer processing
     If you need to perform some image manilulation, return your CVPixelBuffer , otherwise return nil
- Parameter sampleBuffer: video buffer
- Parameter cameraPosition: position of camera image taken from (may have sense for multi-camera capture)
- Returns: `nil` to remain buffer unchanged, pixel buffe to substitute origninal sample buffer
     */
    func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, cameraPosition: AVCaptureDevice.Position) -> CVPixelBuffer?
}

public extension StreamerAppDelegate {
    func snapshotStateDidChange(state: RecordState, fileUrl: URL?) {
        LogError("snapshotStateDidChange doesn't implemented")
    }
    
    func recordStateDidChange(state: RecordState, fileUrl: URL?) {
        LogError("recordStateDidChange doesn't implemented")
    }
    
    func overlayDownloaded(location: URL, suggestedFilename: String, layer: ImageLayer) -> URL? {
        return nil
    }
    
    func overlayError(error: ImageLayerError, layer: ImageLayer)
    {
        
    }

    func processsAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        return nil
    }
    
    func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, cameraPosition: AVCaptureDevice.Position) -> CVPixelBuffer? {
        return nil
    }


}
