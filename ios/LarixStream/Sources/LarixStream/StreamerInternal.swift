import AVFoundation
import CoreImage
import UIKit

import LarixCore
import LarixUI
import LarixSupport
import LarixObjC

class StreamerInternal: Streamer,
                       AVCaptureVideoDataOutputSampleBufferDelegate,
                       AVCaptureAudioDataOutputSampleBufferDelegate,
                       AVCapturePhotoCaptureDelegate,
                       SilenceGeneratorDelegate,
                       CompositeImageLayerDelegate {

    
    internal var bufferPool: BufferPool?
    internal var overlayTexture: MTLTexture?
    
    override weak public var imageLayerPreview: ImagePreviewOverlay? {
        didSet {
            if let image = self.imageLayer.outputImage, let layer = imageLayerPreview {
                let cgImage = image.cgImage
                layer.setImage(cgImage)
            }
            silenceGenerator?.imageLayerPreview = imageLayerPreview
        }
    }

    
    override public var pauseMode: PauseMode {
        didSet {
            engine.setSilence(isMuted || pauseMode != .off)
            if paused {
                silenceGenerator?.setOverlays(pauseOverlays)
            } else {
                silenceGenerator?.setOverlays([])
            }
        }
    }
    
    override public var pauseOverlays: [ImageLayer] {
        didSet {
            if paused {
                silenceGenerator?.setOverlays(pauseOverlays)
            }
        }
    }

    override public var overlays: [ImageLayer] {
        didSet {
            if session?.isRunning == true {
                imageLayer.loadList(overlays)
            }
        }
    }

    override public var stereoOrientation: AVAudioSession.StereoOrientation {
        didSet {
            updateStereo()
        }
    }

    // audio
    private var audioOut: AVCaptureAudioDataOutput?
    private var audioConnection: AVCaptureConnection?
    internal var silenceGenerator: SilenceGenerator?

    // mp4 record
    internal var isRecording = false
    internal var isRecordSessionStarted = false
    internal var externalEncodingMode: Bool {
        return isRecording && videoConfig?.fileWritingMode == .separateSession
    }

    // jpeg capture
    internal var photoFileUrl: URL?

    override public var orientation: AVCaptureVideoOrientation {
        didSet {
            bufferPool?.invalidate()
        }
    }

    
    internal var ciContext: CIContext?
    
    internal var position: AVCaptureDevice.Position = .back
    
    internal var imageLayer = CompositeImageLayer()
    
    internal var streamWidth: Int = 192
    internal var streamHeight: Int = 144


    internal var postprocess: Bool {
        false
    }
    internal var currentFpsRange: AVFrameRateRange?
    internal var currentFps: Double = 0.0
    
    internal var stereo: Bool = false
    
    internal var encodingStarted: Bool = false
    
    //var prevVideoPts: CMTime?
    
    internal var videoOrientation: AVCaptureVideoOrientation {
        // CoreImage filters enabled, we will rotate video on app side, so request not rotated buffers
        if postprocess {
            return .landscapeRight
        } else {
            // CoreImage filters disabled; camera will rotate buffers for us
            if videoConfig?.portrait == true {
                return .portrait
            } else {
                return .landscapeRight
            }
        }
    }

    // MARK: File recording notification
    override public func recordStateDidChange(_ state: RecordState, url: URL?) {
        switch state {
        case .initialized:
            isRecording = true
        case .started:
            isRecordSessionStarted = true
        case .stopped, .stalled:
            isRecording = false
        case .failed:
            isRecording = false
        default:
            LogError("Unknown recording state");
        }
        super.recordStateDidChange(state, url: url)
    }
    
    
    // MARK: Capture setup
    // Either set startEncoding to true to start audio/video encoding at once,
    //  or call startEncoding() later
    override public func startCapture(startAudio: Bool, startVideo: Bool, startEncoding: Bool = true) throws {
        try! super.startCapture(startAudio: startAudio, startVideo: startVideo, startEncoding: startEncoding)
        if startAudio && startVideo {
            recordMode = .videoAudio
        } else if startAudio {
            recordMode = .audioOnly
        } else if startVideo {
            recordMode = .videoOnly
        }
        if startAudio {
            guard AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == AVAuthorizationStatus.authorized else {
                throw StreamerError.DeviceNotAuthorized
            }
            guard audioConfig != nil else {
                throw StreamerError.NoAudioConfig
            }
        }
        if startVideo {
            guard AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.authorized else {
                throw StreamerError.DeviceNotAuthorized
            }
            guard videoConfig != nil else {
                throw StreamerError.NoVideoConfig
            }
        }
        
        workQueue.async {
            do {
                guard self.session == nil else {
                    LogVerbose("session is running (guard)")
                    return
                }
                LogVerbose("startCapture (async)")
                
                self.notifySetupProgress(step: CaptureStatus.stepInitial)
                
                // IMPORTANT NOTE:
                
                // The way applications handle audio is through the use of audio sessions. When your app is launched, behind the scenes it is provided with a singleton instance of an AVAudioSession. Your app use the shared instance of AVAudioSession to configure the behavior of audio in the application.
                
                // https://developer.apple.com/documentation/avfoundation/avaudiosession
                
                // Before configuring AVCaptureSession app MUST configure and activate audio session. Refer to AppDelegate.swift for details.
                
                // ===============


                // AVCaptureSession is completely managed by application, libmbl2 will not change neither CaptureSession's settings nor camera settings.
                self.session = self.createSession()

                // We want to select input port (Built-in mic./Headset mic./AirPods) on our own
                // Also it keeps h/w sample rate as is (48kHz for Built-in mic. and 16kHz for AirPods)
                self.session?.automaticallyConfiguresApplicationAudioSession = false

                // Raw audio and video will be delivered to app in form of CMSampleBuffer. Refer to func captureOutput for details.
                
                if startAudio {
                    self.notifySetupProgress(step: CaptureStatus.stepAudioSession)
                    
                    // Prerequisites: AVAudioSession is active.
                    // Refer to AppDelegate.swift / startAudio() for details.
                    try self.setupAudioSession()
                    
                    self.engine.setAudioConfig(self.createAudioEncoderConfig())
                    
                    self.notifySetupProgress(step: CaptureStatus.stepAudio)
                    try self.setupAudio()
                    
                    self.isMuted = false
                    if startVideo == false && startEncoding == true {
                        //No special aciton to start audio encoding, but we must set it to handle audio buffers
                        self.encodingStarted = true
                    }
                }
                
                if startVideo {
                    
                    // If "Live rotation" is on, we will use CoreImage filters. You can add any custom filter like wartermark, etc.
                    // https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_tasks/ci_tasks.html
                    // All of the processing of a core image is done in a CIContext. You will always need one when outputting the CIImage object.
                    
                    // Consider disabling color management if: Your app needs the absolute highest performance. Users won't notice the quality differences after exaggerated manipulations.
                    // To disable color management, set the kCIImageColorSpace key to null. If you are using an EAGL context, also set the context colorspace to null when you create the EAGL context.
                    
                    self.notifySetupProgress(step: CaptureStatus.stepFilters)
                    
                    let options = [CIContextOption.workingColorSpace: NSNull(),
                                   CIContextOption.outputColorSpace: NSNull(),
                                   CIContextOption.useSoftwareRenderer: NSNumber(value: false)]
                    self.ciContext = CIContext(options: options)
                    guard let ciContext = self.ciContext else {
                        self.delegate?.captureStateDidChange(state: CaptureState.failed, status: CaptureStatus.errorCoreImage)
                        return
                    }
                    self.silenceGenerator = SilenceGenerator(context: ciContext, delegate: self)
                    self.engine.setVideoConfig(self.createVideoEncoderConfig())
                    self.bufferPool = BufferPool(width: self.streamWidth, height: self.streamHeight)
                    if self.paused {
                        self.silenceGenerator?.setOverlays(self.pauseOverlays)
                    }

                    if let writingMode = self.videoConfig?.fileWritingMode {
                        self.engine.setFileWritingMode(writingMode)
                    }
                    
                    if self.videoConfig?.processingMode == .metal {
                        self.setupMetal()
                    }
                    
                    if startEncoding {
                        // Start VTCompressionSession to encode raw video to h264, and then feed libmbl2 with CMSampleBuffer produced by AVCaptureSession.
                        self.notifySetupProgress(step: CaptureStatus.stepVideoEncoding)
                        
                        let h264Started = self.engine.startVideoEncoding()
                        guard h264Started else {
                            self.delegate?.captureStateDidChange(state: CaptureState.failed, status: CaptureStatus.errorVideoEncoding)
                            return
                        }
                        self.encodingStarted = true
                    }
                    
                    self.notifySetupProgress(step: CaptureStatus.stepVideoIn)
                    try self.setupVideoIn()
                    
                    self.notifySetupProgress(step: CaptureStatus.stepVideoOut)
                    try self.setupVideoOut()
                    
                    self.notifySetupProgress(step: CaptureStatus.stepStillImage)
                    try self.setupStillImage()
                    
                    self.imageLayer.delegate = self
                    self.imageLayer.size = CGSize(width: self.streamWidth, height: self.streamHeight)
                    
                    if !self.overlays.isEmpty {
                        self.imageLayer.loadList(self.overlays)
                    }
                }
                
                self.notifySetupProgress(step: CaptureStatus.stepSessionStart)
                
                // Only setup observers and start the session running if setup succeeded.
                self.registerForNotifications()
                self.session!.startRunning()
                // Wait for AVCaptureSessionDidStartRunning notification.
                
            } catch {
                LogError("Capture error: \(error.localizedDescription)")
                self.delegate?.captureStateDidChange(state: CaptureState.failed, status: error)
            }
        }
    }
    
    
    override public func stopCapture() {
        LogVerbose("stopCapture")

        MetalCore.shutdown()

        workQueue.async {
            self.releaseCapture()
        }
    }

    override public func startEncoding() {
        if encodingStarted {
            LogWarn("Encodng already started")
            return
        }
        workQueue.async {
            
            self.notifySetupProgress(step: CaptureStatus.stepVideoEncoding)
            if self.recordMode == .audioOnly || self.engine.startVideoEncoding() {
                self.encodingStarted = true
            } else {
                self.delegate?.captureStateDidChange(state: CaptureState.failed, status: CaptureStatus.errorVideoEncoding)
            }
        }
    }

    override public func stopEncoding() {
        if !encodingStarted {
            LogWarn("Encoding doesn't running")
            return
        }
        workQueue.async {
            self.encodingStarted = false
            self.engine.stopVideoEncoding()
            self.engine.stopAudioEncoding()
        }
    }
    
    internal func setupMetal() {
    }
    
    internal func createSession() -> AVCaptureSession? {
        return nil
    }
    
    private func notifySetupProgress(step: CaptureStatus) {
        delegate?.captureStateDidChange(state: CaptureState.setup, status: step)
    }
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        let nc = NotificationCenter.default
        
        nc.addObserver(
            self,
            selector: #selector(audioSessionRouteChange(notification:)),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession)
        
        nc.addObserver(self,
                       selector: #selector(handleAudioSessionInterruption(notification:)),
                       name: AVAudioSession.interruptionNotification,
                       object: audioSession)


        var preferredInput: AVAudioSessionPortDescription? = nil
        if let inputs = audioSession.availableInputs, let preferredType = audioConfig?.preferredInput {
            preferredInput = inputs.first(where: { $0.portType == preferredType })
        }
        try audioSession.setPreferredInput(preferredInput)

        if let activeInput = audioSession.currentRoute.inputs.first {
            LogInfo("Active audio input: \(activeInput.description)")
            var position = audioConfig?.micPosition ?? .unspecified
            if position == .unspecified {
                position = cameraPosition
            }
            if !setupMicPosition(input: activeInput, position: position) {
                unsetStereo(input: activeInput)
            }
        }

        if #available(iOS 13.0, *) {
            try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
        }
    }
    
    internal func updateAudio(cameraPosition: AVCaptureDevice.Position ) {
        let pos = audioConfig?.micPosition ?? .unspecified
        if pos != .unspecified {
            //Do nothing if position is fixed
            return
        }
        let audioSession = AVAudioSession.sharedInstance()
        if let input = audioSession.currentRoute.inputs.first {
            if !setupMicPosition(input: input, position: cameraPosition) {
                unsetStereo(input: input)
            }
        }
    }
    
    private func createAudioEncoderConfig() -> AudioEncoderConfig {
        let config = AudioEncoderConfig()
        guard let audioConfig = audioConfig else {
            LogError("No audioConfig provided")
            return config
        }

        config.channelCount = Int32(audioConfig.channelCount)
        config.sampleRate = audioConfig.sampleRate
        config.bitrate = Int32(audioConfig.bitrate)
        
        config.manufacturer = kAppleSoftwareAudioCodecManufacturer
        
        LogVerbose("sampleRate = \(config.sampleRate)")
        LogVerbose("channelCount = \(config.channelCount)")
        LogVerbose("bitrate = \(config.bitrate)")
        
        return config
    }
    
    private func createVideoEncoderConfig() -> VideoEncoderConfig {
        let config = VideoEncoderConfig()
        guard let videoConfig = videoConfig else {
            LogError("No videoConfig provided")
            return config
        }
        config.pixelFormat = Consts.PixelFormat_YUV
        
        if videoConfig.portrait {
            streamHeight = Int(videoConfig.videoSize.width)
            streamWidth = Int(videoConfig.videoSize.height)
            
            config.height = Int32(videoConfig.videoSize.width)
            config.width = Int32(videoConfig.videoSize.height)
            
        } else {
            streamWidth = Int(videoConfig.videoSize.width)
            streamHeight = Int(videoConfig.videoSize.height)
            
            config.width = Int32(videoConfig.videoSize.width)
            config.height = Int32(videoConfig.videoSize.height)
        }
        silenceGenerator?.setStreamSize(width: streamWidth, height: streamHeight)
        
        config.type = videoConfig.type
        config.profileLevel = videoConfig.profileLevel as String
        
        config.fps = Int32(videoConfig.fps)
        // Convert key frame interval from seconds to number of frames. A key frame interval of 1 indicates that every frame must be a keyframe, 2 indicates that at least every other frame must be a keyframe, and so on.
        config.maxKeyFrameInterval = Int32(videoConfig.keyFrameIntervalDuration * videoConfig.fps)
        
        // https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey_averagebitrate
        config.bitrate = Int32(videoConfig.bitrate)
        
        // https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey_dataratelimits
        if let limit = videoConfig.bitrateLimit {
            config.limit = Int32(limit)
        }
        
        // later you can update video bitrate  using engine?.updateBitrate() api; this can be used to lower bitrate on the fly in case of slow connection
        
        LogVerbose("camera id = \(videoConfig.cameraID)")
        LogVerbose("portrait = \(videoConfig.portrait)")
        LogVerbose("width = \(config.width)")
        LogVerbose("height = \(config.height)")
        LogVerbose("bitrate = \(config.bitrate)")
        LogVerbose("limit = \(config.limit)")
        LogVerbose("framerate = \(config.fps)")
        LogVerbose("keyframe = \(config.maxKeyFrameInterval)")
        LogVerbose("profileLevel = \(String(describing: config.profileLevel))")
        return config
    }
    
    internal func setupVideoIn() throws {
        throw StreamerError.SetupFailed("NOT_IMPLEMENTED")
    }

    internal func setupVideoOut() throws {
        throw StreamerError.SetupFailed("NOT_IMPLEMENTED")
    }
    
    internal func setCameraParams(camera: AVCaptureDevice) -> AVCaptureDevice.Format? {
        guard let format = CameraHelper.findFormat(camera: camera,
                                                   videoConfig: &self.videoConfig,
                                                   validateFn: isValidFormat) else {
            LogError("streamer fail: can't find video output format")
            return nil
        }
        guard let videoConfig = videoConfig else {
            LogError("no videoConfig")
            return nil
        }
        do {
            try camera.lockForConfiguration()
        } catch {
            LogError("streamer fail: can't lock video device for configuration: \(error)")
           return nil
        }
        
        let fps = videoConfig.fps
        SwiftTryCatch.try({
            camera.activeFormat = format
            camera.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
            camera.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
            self.currentFps = fps
        }, catch: { (error) in
            LogError("Failed: \(error.description)")
        }, finally: {
            
        })
        
        let cameraRes = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        LarixLogger.put(message: "\(camera.localizedName) \(cameraRes.width)x\(cameraRes.height) @ \(camera.activeVideoMinFrameDuration.timescale) FPS", severity: .info, priority: .med)

        defaultFocus(camera: camera)

        var initZoom: CGFloat = 1.0
        if camera.position == .back {
            let backSettings = self.cameraConfig.get(.back)
            if backSettings.zoom > 0 {
                initZoom = self.cameraConfig.get(.back).zoom
            } else {
                initZoom = self.baseZoomFactor
            }
            if initZoom > format.videoMaxZoomFactor {
                LogWarn("Zoom factor \(initZoom) is out of range")
                initZoom = format.videoMaxZoomFactor
                backSettings.zoom = initZoom
            }
        }
        camera.videoZoomFactor = initZoom
        self.restoreWhiteBalance(camera: camera)
        camera.unlockForConfiguration()
        
        return format
    }
    
    internal func isValidFormat(_ format: AVCaptureDevice.Format) -> Bool {
        return CMFormatDescriptionGetMediaType(format.formatDescription) == kCMMediaType_Video
    }

    internal func setVideoStabilizationMode(connection: AVCaptureConnection, camera: AVCaptureDevice) {
        let pos = camera.position
        let mode = cameraConfig.get(pos).videoStabilizationMode
        CameraHelper.setVideoStabilizationMode(connection: connection, camera: camera, mode: mode)
    }
    
    internal func restoreWhiteBalance(camera: AVCaptureDevice) {
        let pos = camera.position
        guard let kelvins = cameraConfig.get(pos).colorTemperature else {
            return
        }
        if CameraHelper.setColorTempInternal(camera: camera, tempK: kelvins) {
            let camParams = cameraConfig.get(pos)
            camParams.lockedParameters.insert(.WhiteBalance)
        }

    }
    
    internal func setupAudio() throws {
        guard let session = session else {
            throw StreamerError.SetupFailed("No session")
        }

        // start audio input configuration
        guard let recordDevice = AVCaptureDevice.default(for: AVMediaType.audio) else {
            LogError("streamer fail: can't open audio device")
            throw StreamerError.SetupFailed("Failed to open audio device")
        }
        let audioIn: AVCaptureInput
        do {
            audioIn = try AVCaptureDeviceInput(device: recordDevice)
        } catch {
            LogError("streamer fail: can't allocate audio input: \(error)")
            throw StreamerError.SetupFailed("Failed to allocate audio input")
        }
        
        if session.canAddInput(audioIn) {
            session.addInput(audioIn)
        } else {
            LogError("streamer fail: can't add audio input")
            throw StreamerError.SetupFailed("Failed to add audio input")
        }
        // audio input configuration completed
        
        // start audio output configuration
        let audioOut = AVCaptureAudioDataOutput()
        audioOut.setSampleBufferDelegate(self, queue: workQueue)
        
        if session.canAddOutput(audioOut) {
            session.addOutput(audioOut)
        } else {
            LogError("streamer fail: can't add audio output")
            throw StreamerError.SetupFailed("Failed to add audio output")
        }
        
        self.audioOut = audioOut
        self.audioConnection = audioOut.connection(with: AVMediaType.audio)
        guard self.audioConnection != nil else {
            LogError("streamer fail: can't allocate audio connection")
            throw StreamerError.SetupFailed("Failed to add audio connection")
        }
        
        // audio output configuration completed
    }
    
    internal func setupStillImage() throws {
        throw StreamerError.SetupFailed("NOT_IMPLEMENTED")
    }
    
    internal func setupMicPosition(input: AVAudioSessionPortDescription, position: AVCaptureDevice.Position) -> Bool {
        stereo = false
        
        guard var dataSources = input.dataSources else {
            return false
        }
        var canUseStereo = false
        if #available(iOS 14.0, *) {
            if audioConfig?.channelCount == 2  {
                let stereoSources = dataSources.filter({ (source) -> Bool in
                    source.supportedPolarPatterns?.contains(.stereo) ?? false
                })
                if !stereoSources.isEmpty {
                    dataSources = stereoSources
                    canUseStereo = true
                }
            }
        }
        var preferredSource: AVAudioSessionDataSourceDescription?
        for source in dataSources {
            LogInfo(source.description)
        }
        if position == .front {
            preferredSource = dataSources.first(where: { $0.orientation == .front })
        } else if position == .back {
            preferredSource = dataSources.first(where: { $0.orientation == .back })
        }
        guard let selectedSource = preferredSource ?? dataSources.first else {
            return false
        }
        
        var pattern: AVAudioSession.PolarPattern = .omnidirectional
        if #available(iOS 14.0, *) {
            if canUseStereo && position != .unspecified {
                pattern = .stereo
            }
        }

        let audioSession = AVAudioSession.sharedInstance()
        var success = true
        do {
            if let patterns = selectedSource.supportedPolarPatterns, patterns.contains(pattern) {
                try selectedSource.setPreferredPolarPattern(pattern)
            }
            try input.setPreferredDataSource(selectedSource)
            if #available(iOS 14.0, *) {
                if pattern == .stereo {
                    try audioSession.setPreferredInputOrientation(stereoOrientation)
                    stereo = true
                }
            }
        } catch {
            LogError("Unable to select audio source: \(error.localizedDescription)")
            success = false
        }
        return success
    }
    
    internal func unsetStereo(input: AVAudioSessionPortDescription) {
        guard #available(iOS 14.0, *) else {
            return
        }
        do {
            try input.setPreferredDataSource(nil)
            if let source = input.preferredDataSource {
                try source.setPreferredPolarPattern(.omnidirectional)
            }
        } catch {
            LogError("Unable to reset audio source")
        }
    }
    
    internal func updateStereo() {
        guard #available(iOS 14.0, *), stereo else {
            return
        }
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setPreferredInputOrientation(stereoOrientation)
        } catch {
            LogError("Unable to set stereo orientation")
        }
    }
    
    
    internal func releaseCapture() {
        audioOut?.setSampleBufferDelegate(nil, queue: nil)
        NotificationCenter.default.removeObserver(self)
        silenceGenerator?.stop()
        engine.stopFileWriter()
        engine.stopVideoEncoding()
        engine.stopAudioEncoding()
        bufferPool = nil

        if session?.isRunning == true {
            LogVerbose("stopRunning")
            session?.stopRunning()
        }
        imageLayer.invalidate()

        audioConnection = nil
        audioOut = nil
        ciContext = nil
        silenceGenerator = nil
        session = nil
        
        delegate?.captureStateDidChange(state: CaptureState.stopped, status: CaptureStatus.success)
        
        LogVerbose("all capture released")
    }


    // MARK: Notifications from capture session
    internal func registerForNotifications() {
        let nc = NotificationCenter.default
        
        nc.addObserver(
            self,
            selector: #selector(sessionDidStartRunning(notification:)),
            name: NSNotification.Name.AVCaptureSessionDidStartRunning,
            object: session)
        
        nc.addObserver(
            self,
            selector: #selector(sessionDidStopRunning(notification:)),
            name: NSNotification.Name.AVCaptureSessionDidStopRunning,
            object: session)
        
        nc.addObserver(
            self,
            selector: #selector(sessionRuntimeError(notification:)),
            name: NSNotification.Name.AVCaptureSessionRuntimeError,
            object: session)
        
        nc.addObserver(
            self,
            selector: #selector(sessionWasInterrupted(notification:)),
            name: NSNotification.Name.AVCaptureSessionWasInterrupted,
            object: session)
        
        nc.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded(notification:)),
            name: NSNotification.Name.AVCaptureSessionInterruptionEnded,
            object: session)
    }
    
    
    @objc private func sessionDidStartRunning(notification: Notification) {
        LogVerbose("AVCaptureSessionDidStartRunning")
        delegate?.captureStateDidChange(state: CaptureState.started, status: CaptureStatus.success)
    }
    
    @objc private func sessionDidStopRunning(notification: Notification) {
        LogVerbose("AVCaptureSessionDidStopRunning")
    }
    
    @objc private func sessionRuntimeError(notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            return
        }
        LogError("AVCaptureSessionRuntimeError: \(error)")
        delegate?.captureStateDidChange(state: CaptureState.failed, status: CaptureStatus.errorCaptureSession)
    }
    
    @objc private func sessionWasInterrupted(notification: Notification) {
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?, let reasonIntegerValue = userInfoValue.integerValue, let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            LogVerbose("AVCaptureSessionWasInterrupted \(reason)")
            
            if reason == .videoDeviceNotAvailableInBackground {
                return // Session will be stopped by Larix app when it goes to background, ignore notification
            }
            
            var status = CaptureStatus.errorSessionWasInterrupted // Unknown error
            if reason == .audioDeviceInUseByAnotherClient {
                status = CaptureStatus.errorMicInUse
                if session?.isRunning == true {
                    let fps = recordMode == .audioOnly ? 0.0 : videoConfig?.fps ?? 0.0
                    silenceGenerator?.start(fps: fps, withAudio: recordMode != .videoOnly)
                }
            } else if reason == .videoDeviceInUseByAnotherClient {
                status = CaptureStatus.errorCameraInUse
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                status = CaptureStatus.errorCameraUnavailable
            }
            delegate?.captureStateDidChange(state: CaptureState.failed, status: status)
        }
    }
    
    @objc private func sessionInterruptionEnded(notification: Notification) {
        LogVerbose("AVCaptureSessionInterruptionEnded")
        silenceGenerator?.stopAudio()
        delegate?.captureStateDidChange(state: CaptureState.canRestart, status: CaptureStatus.success)
    }
    
    @objc private func audioSessionRouteChange(notification: Notification) {
        if let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber, let routeChangeReason = AVAudioSession.RouteChangeReason(rawValue: UInt(value.intValue)) {
            
            if let routeChangePreviousRoute = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                LogVerbose("\(#function) routeChangePreviousRoute: \(routeChangePreviousRoute)")
            }
            
            switch routeChangeReason {
                
            case .unknown:
                LogVerbose("\(#function) routeChangeReason: unknown")
                
            case .newDeviceAvailable:
                // e.g. a headset was added or removed
                LogVerbose("\(#function) routeChangeReason: newDeviceAvailable")
                
            case .oldDeviceUnavailable:
                // e.g. a headset was added or removed
                LogVerbose("\(#function) routeChangeReason: oldDeviceUnavailable")
                
            case .categoryChange:
                // called at start - also when other audio wants to play
                LogVerbose("\(#function) routeChangeReason: categoryChange")
                
            case .override:
                LogVerbose("\(#function) routeChangeReason: override")
                
            case .wakeFromSleep:
                LogVerbose("\(#function) routeChangeReason: wakeFromSleep")
                
            case .noSuitableRouteForCategory:
                LogVerbose("\(#function) routeChangeReason: noSuitableRouteForCategory")
                
            case .routeConfigurationChange:
                LogVerbose("\(#function) routeChangeReason: routeConfigurationChange")
                
            default:
                break
            }
            self.delegate?.notification(notification: .AudioSessionRouteChanged)
        }
    }
    
    @objc func handleAudioSessionInterruption(notification: Notification) {
        
        guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber,
           let interruptionType = AVAudioSession.InterruptionType(rawValue: UInt(value.intValue)) else {
            return
        }
        silenceGenerator?.setAudioInterruption(started: interruptionType == .began)
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            LogVerbose("sample buffer is not ready, skipping sample")
            return
        }
        
//        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let videoDataOutput = output as? AVCaptureVideoDataOutput {
            processVideoSampleBuffer(sampleBuffer, fromOutput: videoDataOutput)
//            if let prevTs = prevVideoPts {
//                let delta = timestamp - prevTs
//                DDLogInfo("Video PTS\(timestamp.seconds) \tdt \(delta.seconds)")
//            }
//            prevVideoPts = timestamp
        } else if let audioDataOutput = output as? AVCaptureAudioDataOutput {
            //DDLogInfo("Audio PTS \(timestamp.seconds)")
            processsAudioSampleBuffer(sampleBuffer, fromOutput: audioDataOutput)
        }
    }
    
    internal func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput) {
    }

    internal func processsAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer, fromOutput audioDataOutput: AVCaptureAudioDataOutput) {
        let outBuffer: CMSampleBuffer
        if let newBuffer = delegate?.processsAudioSampleBuffer(sampleBuffer) {
            outBuffer = newBuffer
        } else {
            outBuffer = sampleBuffer
        }
        silenceGenerator?.handleAudioSampleBuffer(outBuffer)
        if encodingStarted || externalEncodingMode {
            engine.didOutputAudioSampleBuffer(outBuffer)
        }
    }

    override public var isWriting: Bool {
        return isRecording && isRecordSessionStarted
    }
    
    internal func setColorTemperature(tempKelvins: Float, camera: AVCaptureDevice?) {
        workQueue.async {
            guard let camera = camera else {
                return
            }
            let camSettings = self.cameraConfig.get(camera.position)
            if CameraHelper.setColorTemperature(camera: camera, tempK: tempKelvins) {
                if (tempKelvins > 0) {
                    camSettings.colorTemperature = tempKelvins
                }
                camSettings.lockedParameters.insert(.WhiteBalance)
            }
        }
    }

    internal func pointOfInterestSupported(camera: AVCaptureDevice?, parameters: CameraMeteringParameters) -> Bool {
        guard let camera = camera else {return false}
        let af = parameters.contains(.Focus) && camera.isFocusPointOfInterestSupported
        let ae = parameters.contains(.Exposure) && camera.isExposurePointOfInterestSupported
        return af || ae
    }
    

    internal func setMetering(camera: AVCaptureDevice?, at point: CGPoint?, locked: Bool, parameters: CameraMeteringParameters) {
        workQueue.async {
            guard let camera = camera else { return }
            let camSettings = self.cameraConfig.get(camera.position)
            var lockedParameters = camSettings.lockedParameters
            if parameters.isEmpty { return }
            for param in parameters {
                if locked {
                    lockedParameters.insert(param)
                } else {
                    lockedParameters.remove(param)
                }
            }
            
            if parameters.contains(.WhiteBalance)  {
                let wbMode: AVCaptureDevice.WhiteBalanceMode = locked ? .locked : .continuousAutoWhiteBalance
                if camera.isWhiteBalanceModeSupported(wbMode) {
                    var tempKelvins: Float? = nil
                    if locked {
                        let gains = camera.deviceWhiteBalanceGains
                        if CameraHelper.isWbGainsValid(gains, for: camera) {
                            let colorTemp = camera.temperatureAndTintValues(for: gains)
                            tempKelvins = colorTemp.temperature
                        }
                    }
                    camSettings.colorTemperature = tempKelvins
                }
            }
            camSettings.lockedParameters = lockedParameters
            camSettings.pointOfInterest = point ?? CGPoint(x:0.5, y: 0.5)
            do {
                try camera.lockForConfiguration()
                CameraHelper.setLockedParams(camera: camera, params: camSettings)
                camera.unlockForConfiguration()
                self.delegate?.notification(notification: .LockModeChanged)
            } catch {
                LogError("can't lock video device for configuration: \(error)")
            }
        }
    }

    internal func defaultFocus(camera: AVCaptureDevice?) {
        guard let camera = camera else { return }
        let params = cameraConfig.get(camera.position)
        CameraHelper.setLockedParams(camera: camera, params: params)
        //lockedParameters = []
    }
    
    func findMaxZoom(camera: AVCaptureDevice, format: AVCaptureDevice.Format) -> CGFloat {
        if camera.position != .back {
            return 1
        }
        let zoom = min(format.videoMaxZoomFactor, 16.0)
        return zoom
    }

    internal func toggleFlash(camera: AVCaptureDevice?) -> Bool {
        guard let camera = camera else {
            return false
        }
        return CameraHelper.toggleFlash(camera: camera)
    }
    
    //MARK: SilenceGeneratorDelegate
    func putEmptyVideo(_ buffer: CVPixelBuffer, time: CMTime) {
        engine.didOutputVideoPixelBuffer(buffer, withPresentationTime: time)
    }
    
    func putEmptyAudio(_ buffer: CMSampleBuffer) {
        engine.didOutputAudioSampleBuffer(buffer)
    }
   
    
    //MARK: CompositeImageLayerDelegate
    public func onImageLoadComplete() {
        DispatchQueue.main.async {
            guard let layer = self.imageLayerPreview else {
                return
            }
            let image = self.imageLayer.outputImage
            let cgImage = image?.cgImage
            layer.setImage(cgImage)
        }
    }
    
    public func onDownloadFinish(layer: ImageLayer, location: URL, suggestedFilename: String) -> URL? {
        return delegate?.overlayDownloaded(location: location, suggestedFilename: suggestedFilename, layer: layer)
    }
    
    public func onLoadError(layer: ImageLayer, error: ImageLayerError) {
        delegate?.overlayError(error: error, layer: layer)
    }


}
