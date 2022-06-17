import AVFoundation
import CoreImage
import UIKit

import LarixCore
import LarixUI
import LarixSupport
import LarixObjC


/// Error can be thrown by ``Streamer/startCapture(startAudio:startVideo:startEncoding:)``
public enum StreamerError: Error {
    /// Not authorized, check camera and mcrophone permissions
    case DeviceNotAuthorized
    /// ``StreamerBuilder/delegate`` did not assigned
    case NoDelegate
    /// ``StreamerBuilder/videoConfig`` did not assigned while video capture requested
    case NoVideoConfig
    /// ``StreamerBuilder/audioConfig`` did not assigned while audio capture requested
    case NoAudioConfig
    /// Other failure during capture initialization - check status string for details
    case SetupFailed(String)
    /// ``StreamerBuilder/multiCamConfig`` was set, but doesn't supported by current device/iOS version
    case MultiCamNotSupported
}

/** Pause mode
 While pause is active,(standy/pause mode) black frame with ``Streamer/pauseOverlays`` will be send as video and audio muted.
 */
public enum PauseMode {
    /// Turned off
    case off
    /// Standy pause. It's intended that it would set prior to streaming start, but for streamer itself there is no difference
    case standby
    /// Normal pause during streaming
    case pause
}

class StreamerSingleton {
    static private var engineRef: StreamerEngineProxy?
    static var sharedEngine: StreamerEngineProxy {
        if engineRef == nil {
            engineRef = StreamerEngineProxy()
        }
        return engineRef!
    }
    static let sharedQueue = DispatchQueue(label: "LarixBroadcaster")
    private init() {} // This prevents others from using the default '()' initializer for this class.

}


public class Streamer: NSObject,
                       StreamerEngineDelegate {
    
    override init() {
        super.init()
    
        engine.setDelegate(self)
    }
    
    weak var delegate: StreamerAppDelegate?
    
    /// Returns true when AVCaptureSession is active
    public var active: Bool {
        return session != nil
    }
    /**
     Camera and video encoding settings
     - Remark: Use StreamerBuilder to set it
     */
    public var videoConfig: VideoConfig?
    /**
     Microphone and audio encoding settings
     - Remark: Use StreamerBuilder to set it
     */
    public var audioConfig: AudioConfig?

    /**
        Camera picture parameters
        - Note: Stores separate CameraParameters for back/front camera.
        - SeeAlso: ``CameraParameters``
     */
    public var cameraConfig = CameraConfig()
    
    var session: AVCaptureSession?

    /**
    Pause mode [.off | .pause | .standby ]

    Will output silence and black frames wien set to value different from .off
     */
    public var pauseMode: PauseMode = .off
    
    public var paused: Bool {
        return pauseMode != .off
    }
    
    weak public var imageLayerPreview: ImagePreviewOverlay?
    
    /**
    Image layes displayed in paused state
     */
    public var pauseOverlays: [ImageLayer] = []

    /**
    Image layes displayed in playback state
     */
    public var overlays: [ImageLayer] = []
    
    
    public var webViews: [LarixWebWidget] = []
    
    /**
        Measured frame rate of video encoding
        - Important:  May be lower then camera frame rate if video encoder would skip frames
     */
    public var measuredFps: Int {
        let fps = engine.getFps()
        return Int(round(fps))
    }
    
    /**
     Audio mute On/Off

     Fills audio frames with zeros when set to true
     */
    public var isMuted: Bool = false {
        didSet {
            engine.setSilence(isMuted)
        }
    }


    /**
     Standard zoom factor.

     Will be 1 for single camera.
     For dual/triple back camera, will be equal to zoom factor of normal (wide camera) - normally it 2.0
     Divide current zoom factor by this value to get zoom scale similar to standard Camera app
     (it shows 0.5 for ultra-wide camera)
     */
    public internal(set) var baseZoomFactor: CGFloat = 1
    
    /**
        Maximum zoom factor
     */
    public internal(set) var maxZoomFactor: CGFloat = 1
    
    /**
        Currently selected camera position
     
     Will be .back/.front for single-camera capture,
     .undefined for multi-camera capture
     */
    public var cameraPosition: AVCaptureDevice.Position {
        return .unspecified
    }

    /**
     Live rotation
     Camera picture will be rotated according to specified orientation,
     blaсk stripes will be added if doesn't match video orientation (portratait/ladscape)
     - Note: will not affect image if VideoConfig.processingMode set to .disabled
         */
    public var orientation: AVCaptureVideoOrientation = .landscapeLeft
    public var stereoOrientation: AVAudioSession.StereoOrientation = .landscapeLeft
    
    internal var engine: StreamerEngineProxy {
        return StreamerSingleton.sharedEngine
    }
    
    internal var workQueue = StreamerSingleton.sharedQueue

    internal var recordMode: ConnectionMode = .videoAudio
    
    /**
     Initiate connection to sever
     - Parameters:
        - config:  either  <doc:ConnectionConfig> for RTMP/RTSP or <doc:SrtConfig> for SRT or <doc:RistConfig> for RIST
     - Returns: ID of new connection in a case of valid config, -1 in case of bad config.
     
     Returned value doesn't mean connection is actually established, it just initiates connection asynchronously.
     Please handle ``StreamerAppDelegate/connectionStateDidChange(id:state:status:info:)`` to get actual status.
     */
    public func createConnection(config: NSObject?) -> Int32 {
        if let tcpConfig = config as? ConnectionConfig {
            return engine.createConnection(tcpConfig)
        }
        if let srtConfig = config as? SrtConfig {
            return engine.createSrtConnection(srtConfig)
        }
        if let ristConfig = config as? RistConfig {
            return engine.createRistConnection(ristConfig)
        }
        LogError("Unknown connection type")
        return -1
    }

    /**
     Close connection to sever
     - Parameters:
        - id: ID of existing connection
     */
    public func releaseConnection(id: Int32) {
        engine.releaseConnection(id)
    }
    
    /// Сonnection notification from StreamerEngineDelegate
    public func connectionStateDidChangeId(_ connectionID: Int32, state: ConnectionState, status: ConnectionStatus, info: [AnyHashable:Any]) {
        delegate?.connectionStateDidChange(id: connectionID, state: state, status: status, info: info)
    }
    
    /// File recording notification from StreamerEngineDelegate
    public func recordStateDidChange(_ state: RecordState, url: URL?) {
        delegate?.recordStateDidChange(state: state, fileUrl: url)
    }
    
    // MARK: Сonnection statistics
    public func bytesSent(connection: Int32) -> UInt64 {
        return engine.getBytesSent(connection)
    }

    public func bytesDelivered(connection: Int32) -> UInt64 {
        return engine.getBytesDelivered(connection)
    }

    public func bytesRecv(connection: Int32) -> UInt64 {
        return engine.getBytesRecv(connection)
    }
    
    public func udpPacketsLost(connection: Int32) -> UInt64 {
        return engine.getUdpPacketsLost(connection)
    }
    
    public func srtStats(connection: Int32) -> SrtStats? {
        let stats = SrtStats()
        if engine.getSrtStats(connection, stats: stats, clear: false, instantaneous: false) == false {
            return nil
        }
        return stats
    }
    
/**
Capture setup
- Parameter startAudio: true if you need to capture audio
- Parameter startVideo: true uf you need to cature video. false for audio-only capture
- Parameter startEncoding: true to start audio/video encoding at once
- Throws ``StreamerError`` if configuration are not valid
- Precondition: audioConfig must be set in ``StreamerBuilder`` if startAudio is true.
- Precondition: Mic permission must be requested if startAudio is true.
- Precondition:Audio session must be configured if startAudio is true.
- Precondition: videoConfig must be set in ``StreamerBuilder`` if startVideo is true.
- Precondition: Camera permission must be requested if startVideo is true.
- Important: If you set startEncoding to false, you should call startEncoding() prior to streaming start.
 
``StreamerAppDelegate/captureStateDidChange(state:status:)`` will be called with ``CaptureState/setup`` and several phases of initialization and either ``CaptureState/started`` in case of success or ``CaptureState/failed`` in case of failure
 
 - Seealso: Utility classes: ``PermissionChecker``, ``AudioSession``
 - Seealso: `startEncoding`
 */
    public func startCapture(startAudio: Bool, startVideo: Bool, startEncoding: Bool = true) throws {
        guard delegate != nil else {
            throw StreamerError.NoDelegate
        }
    }
    
    /** Stop cature session
     ``StreamerAppDelegate/captureStateDidChange(state:status:)`` will be called with ``CaptureState/stopped`` when done
     */
    public func stopCapture() {
    }

/** Start video encoding.
- Important:no need to call if you call ``startCapture(startAudio:startVideo:startEncoding:)`` with startEncodig: true.
- Seealso: ``startCapture(startAudio:startVideo:startEncoding:)``
*/
    public func startEncoding() {
    }

    /** Stop video encoding.
     - Important: need to call only if you control encoding separately.
     */
    public func stopEncoding() {
    }

    
/** Switch active camera.
Actually switch camera on single-camera capture only. On multi-camera capture just swaps primary and secondary camera images
- Parameter newCamera: Camera to switch to. If set to `nil`, switch to default camera on opposite side (i.e. front when back camera is currently active and vice versa)
- Remark: Switch is peformed asyntronous. During switch, black video frames and empty audio frames will be generated to avoid timestamp gaps.
     ``StreamerAppDelegate/notification(notification:)``  with ``StreamerNotification/ActiveCameraDidChange`` will be called after camera change
     */
    public func changeCamera(to newCamera: AVCaptureDevice? = nil) {
        
    }
    
/** Start video file recording
- Parameter url: URL of video file to write
- Remark: only QuickTime format (.mov) is supported
``StreamerAppDelegate/recordStateDidChange(state:fileUrl:)-30pi6`` will be called with state = .started if recirding is started
- Note: ``VideoConfig/fileWritingMode`` affects file writing. When set to .sharedSession, compressed frames that was broadcasted will be stored to file. When set to .separateSession, video frames for file will be compressed separately. This has side effect that files created with .sharedSession doesn't contain thumbnails and some other medadata. If this have meaning for you, use .separateSession.
     */
    public func startRecord(url: URL) {
        LarixLogger.put(message: "Start writing to file", severity: .info, priority: .med)
        workQueue.async {
            guard self.engine.startFileWriter(url, mode: self.recordMode) else {
                LogError("can't start record")
                return
            }
        }
    }

    /** Finish video file recording
    - Remark: ``StreamerAppDelegate/recordStateDidChange(state:fileUrl:)`` will be called with state = .stopped and URL of recorded file
     */
    public func stopRecord() {
        LogVerbose("stopRecord")
        engine.stopFileWriter()
    }
    
    /** Switch recording to new file
     - Remark: ``StreamerAppDelegate/recordStateDidChange(state:fileUrl:)`` will be called with state = .stopped and URL of previously recorded file, then with state = .started for new file
     */
    public func switchRecord(nextFileUrl: URL) {
        LarixLogger.put(message: "Switching file", severity: .info, priority: .med)
        engine.switchFileWriter(nextFileUrl)

    }

    /// Returns true when file writing is in progress
    public var isWriting: Bool {
        return false
    }
    
    /**
     Capture snapshot
     - Parameter fileUrl: URL of picture file to write
     - Parameter format: image format - either .jpg or .heic
     - Remark: ``StreamerAppDelegate/snapshotStateDidChange(state:fileUrl:)-83slr`` will be called with  state = .stopped and URL of image taken
     */
    public func captureStillImage(fileUrl: URL, format: AVFileType? = nil) {
    }

    // MARK: Autofocus
    public func continuousMetering(at focusPoint: CGPoint?,
                         position: AVCaptureDevice.Position = .unspecified,
                         parameters: CameraMeteringParameters = [.Focus]) {
    }

    public func fixedMetering(at focusPoint: CGPoint?,
                   position: AVCaptureDevice.Position = .unspecified,
                   parameters: CameraMeteringParameters = [.Focus]) {
        
    }
        
    public func canPointTo(position: AVCaptureDevice.Position = .unspecified,
                  parameters: CameraMeteringParameters = [.Focus]) -> Bool {
        return false
    }
    
    public func canSetColorTemperature(position: AVCaptureDevice.Position = .unspecified) -> Bool {
        return false
    }
    
    //Will measure grey card WB when called with tempKelvins = 0
    public func setColorTemperature(tempKelvins: Float = 0, position: AVCaptureDevice.Position = .unspecified) {

    }

    public func getColorTemperatureK(position: AVCaptureDevice.Position = .unspecified) -> Float {
        return 0
    }

    
    public func getLockedParameters() -> CameraMeteringParameters {
        return cameraConfig.get(cameraPosition).lockedParameters
    }

    public func resetFocus() {
        fatalError("not implemented")
    }
    
    public func zoomTo(factor: CGFloat) {
        fatalError("not implemented")
    }
    
    public func getCurrentZoom() -> CGFloat {
        return 1.0
    }

    public func setExposureCompensation(_ ev: Float, position: AVCaptureDevice.Position = .unspecified) {
        fatalError("not implemented")
    }
    
    public func getExposureCompensation(position: AVCaptureDevice.Position = .unspecified) -> Float {
        return 0.0
    }

    /**
        Set RTMP metadata for connection
     - SeeAlso: Adobe documentation: [Adding metadata to a live stream](https://helpx.adobe.com/adobe-media-server/dev/adding-metadata-live-stream.html)
     - Parameter connection: ID of RTMP connection
     - Parameter meta: Dictionary with metadata items


     Example of setting metadata
     ````
         var meta = Dictionary<String, Any>()
         meta["artist"] = "Michael Jackson"
         meta["title"] = "Beat It"
         meta["booleanValue"] = false
         meta["integerValue"] = 10
         meta["doubleValue"] = 22.22
         streamer.pushMetaData(connection: id, meta:meta)
     ````
     - Important: Larix sets the following metadata properties and values. Do not add this metadata to live streams:
        `"width"`, `"height"`, `"videodatarate"`, `"videocodecid"`,
        `"audiosamplerate"`, `"audiodatarate"`, `"audiosamplesize"`, `"stereo"`, `"audiocodecid"`
     
     */
    public func pushMetaData(connection: Int32, meta: Dictionary<String, Any>) {
        engine.pushMetaData(connection, metadata: meta)
    }
    
    /**
        Immediately send RTMP metadata for connection
     */
    public func sendDirect(connection: Int32, handler: String, meta: Dictionary<String, Any>) {
        engine.sendDirect(connection, handler:handler, metadata: meta)
    }

    /**
        Change video encoding bitrate
     */
    public func changeBitrate(newBitrate: Int32) {
        LarixLogger.put(message: "Change bitrate to \(newBitrate)", severity: .info, priority: .med)
        engine.updateBitrate(newBitrate)
    }
    
    
    /**
        Change camera FPS
     
     */
    public func updateFps(_ fps: Double) {

    }
    
    /** Get switching zoom factors for virtual device
     Will use active camera for single camera capture, back camera for multi-camera capture
    - SeeAlso: [virtualDeviceSwitchOverVideoZoomFactors](https://developer.apple.com/documentation/avfoundation/avcapturedevice/3153003-virtualdeviceswitchovervideozoom)
     
     */
    public func getSwitchZoomFactors() -> [CGFloat] {
        return []
    }
  
    /** Toggle flash (torch)
    Will use active camera for single camera capture, back camera for multi-camera capture
     - Returns: true if turned on, false if turned off or unavaiable
     */
    public func toggleFlash() -> Bool {
        return false
    }
    
    /** Check flash (torch) support
     - Returns: true if flash supported for current camera (or back camera for multi-camera capture)
     */
    public func supportFlash() -> Bool {
        return false
    }
    
    /** Get current flash status
     - Returns: true if turned off, false if turned off or unsupported
     */
    public func flashOn() -> Bool {
        return false
    }
    
    /** Get information for active camera and active format parameters
     - Returns: array of ``ActiveCameraInfo`` - one element for sinble camera, two for multi-camera
     */
    public func getActiveCameraInfo() -> [ActiveCameraInfo] {
        return []
    }

    
    /**
     Create preview layer for current streamer.
     Will create either ``LarixUI/PreviewLayerSingleCam`` or ``LarixUI/PreviewLayerMultiCam`` depending on stremer
     Created layer will reflect parent size change and resize accordingly
     - Parameter parentView: view to add layer to
     - Returns: PreviewLayer if can be created
      */
    public func createPreviewLayer(parentView: UIView) -> PreviewLayer? {
        return nil
       
    }

}
