import CoreImage
import UIKit
import AVFoundation
import LarixCore
import LarixSupport
import LarixUI

class StreamerSingleCam: StreamerInternal {
    
    enum CameraSwitchingState {
        case none
        case preparing
        case switching
    }
    
    // video
    private var captureDevice: AVCaptureDevice?
    private var videoIn: AVCaptureDeviceInput?
    private var videoOut: AVCaptureVideoDataOutput?
    private var videoConnection: AVCaptureConnection?
    private var transform: ImageTransform?
    private var cameraSwitching: CameraSwitchingState = .none

    // jpeg capture
    private var imageOut: AVCaptureOutput?

    override var postprocess: Bool {
        let mode = videoConfig?.processingMode ?? .disabled
        return mode != .disabled
    }
    
    override var cameraPosition: AVCaptureDevice.Position {
        guard let camera = captureDevice else {
            if let camId = videoConfig?.cameraID, let cam = AVCaptureDevice(uniqueID: camId) {
                return cam.position
            }
            return .unspecified
        }
        return camera.position
    }


    override func createSession() -> AVCaptureSession? {
        return AVCaptureSession()
    }
   
    override func setupVideoIn() throws {
        // start video input configuration
        guard let session = session else {
            throw StreamerError.SetupFailed("No session")
        }

        if let videoConfig = videoConfig {
            captureDevice = AVCaptureDevice(uniqueID: videoConfig.cameraID)
        }
        
        if captureDevice == nil {
            // wrong cameraID? ok, pick default one
            
            captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        }
        
        guard let captureDevice = captureDevice else {
            LogError("streamer fail: can't open camera device")
            throw StreamerError.SetupFailed("Failed to find camera")
        }
        
        do {
            videoIn = try AVCaptureDeviceInput(device: captureDevice)
        } catch {
            LogError("streamer fail: can't allocate video input: \(error)")
            throw StreamerError.SetupFailed("Failed to allocate video input")
        }
        
        if let input = videoIn, session.canAddInput(input) {
            session.addInput(input)
        } else {
            LogError("streamer fail: can't add video input")
            throw StreamerError.SetupFailed("Failed to add video output")
        }
        baseZoomFactor = CameraHelper.getInitZoomFactor(forDevice: captureDevice)
        // video input configuration completed
    }
    
    override func setupVideoOut() throws {
        guard let captureDevice = captureDevice,
              let format = setCameraParams(camera: captureDevice),
              let videoConfig = videoConfig,
              let session = session else {
            throw StreamerError.SetupFailed("Failed to configure camera")
        }
        maxZoomFactor = findMaxZoom(camera: captureDevice, format: format)
        let mode = videoConfig.processingMode
        let videoOut = AVCaptureVideoDataOutput()
        let pixelFormat = mode == .metal ? Consts.PixelFormat_RGB : Consts.PixelFormat_YUV
        videoOut.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String) : NSNumber(value: pixelFormat)]
        videoOut.alwaysDiscardsLateVideoFrames = true
        videoOut.setSampleBufferDelegate(self, queue: workQueue)
        
        if session.canAddOutput(videoOut) {
            session.addOutput(videoOut)
        } else {
            LogError("streamer fail: can't add video output")
            throw StreamerError.SetupFailed("Failed to add video output")
        }
        
        guard let videoConnection = videoOut.connection(with: AVMediaType.video) else {
            LogError("streamer fail: can't allocate video connection")
            throw StreamerError.SetupFailed("Failed to allocate video connection")
        }
        videoConnection.videoOrientation = self.videoOrientation
        videoConnection.automaticallyAdjustsVideoMirroring = false
        videoConnection.isVideoMirrored = false
        setVideoStabilizationMode(connection: videoConnection, camera: captureDevice)
        
        self.videoOut = videoOut
        self.videoConnection = videoConnection
        
        if mode != .disabled {
            let videoSize = CMVideoDimensions(width: Int32(streamWidth), height: Int32(streamHeight))
            let transform = ImageTransform(size: videoSize)
            transform.portraitVideo = videoConfig.portrait
            transform.postion = captureDevice.position
            if let cfg = videoConfig.cameraWindow {
                transform.alignX = cfg.alignX
                transform.alignY = 1.0-cfg.alignY
                transform.scalePipX = cfg.scale
                transform.scalePipY = cfg.scale
            }
            self.transform = transform
        }
        // video output configuration completed
    }
    
    override func setupMetal() {
        MetalCore.startup()
        if let metal = MetalCore.instance {
            metal.videoSize = CGSize(width: streamWidth, height: streamHeight)
        }
    }
    

    override func isValidFormat(_ format: AVCaptureDevice.Format) -> Bool {
        return CMFormatDescriptionGetMediaType(format.formatDescription) == kCMMediaType_Video &&
        CMFormatDescriptionGetMediaSubType(format.formatDescription) == Consts.PixelFormat_YUV
    }

    override func setupStillImage() throws {
        guard let session = session else {
            throw StreamerError.SetupFailed("No session")
        }

        imageOut = AVCapturePhotoOutput()

        if session.canAddOutput(imageOut!) {
            session.addOutput(imageOut!)
        } else {
            LogError("streamer fail: can't add still image output")
            throw StreamerError.SetupFailed("Failed to configure photo output")
        }
    }
    
    override func stopCapture() {
        silenceGenerator?.stop()
        super.stopCapture()
    }
    
    override func releaseCapture() {
        // detach compression sessions and mp4 recorder
        videoOut?.setSampleBufferDelegate(nil, queue: nil)

        super.releaseCapture()
        
        videoConnection = nil
        videoIn = nil
        videoOut = nil
        imageOut = nil
        captureDevice = nil
        ciContext = nil
        session = nil
        transform = nil
    }
    
    override func changeCamera(to newCamera: AVCaptureDevice?) {
        guard cameraSwitching == .none else {
            return
        }
        cameraSwitching = .preparing
        
        workQueue.async {
            guard let session = self.session, let captureDevice = self.captureDevice, let videoConfig = self.videoConfig,
                  self.videoIn != nil, self.videoOut != nil else {
                return
            }
            
            var preferredPosition: AVCaptureDevice.Position = .front
            let currentPosition: AVCaptureDevice.Position = captureDevice.position
            
            // find next camera
            switch (currentPosition) {
            case .unspecified, .front:
                preferredPosition = .back
            case .back:
                preferredPosition = .front
            @unknown default: break
            }
            var videoDevice: AVCaptureDevice? = newCamera
            if videoDevice == nil {
                if preferredPosition == .back {
                    videoDevice = CameraManager.getDefaultBackCamera(videoSize: videoConfig.videoSize, fps: videoConfig.fps, isMultCam: false)
                } else {
                    videoDevice = CameraManager.getDefaultFrontCamera()
                }
            }
            guard let newDevice = videoDevice else {
                LogError("next camera not found, this is impossible")
                self.delegate?.notification(notification: StreamerNotification.ChangeCameraFailed)
                self.cameraSwitching = .none
                return
            }
            if newDevice.uniqueID == self.captureDevice?.uniqueID {
                LogWarn("Already using this camera")
                return
            }

            // check that next camera can produce same resolution and fps as active camera
            guard let newFormat = CameraHelper.findFormat(camera: newDevice,
                                                          videoConfig: &self.videoConfig,
                                                          validateFn: self.isValidFormat,
                                                          adjustFps: false) else {
                self.delegate?.notification(notification: StreamerNotification.ChangeCameraFailed)
                self.cameraSwitching = .none
                return
            }
            let fps = videoConfig.fps
            self.cameraSwitching = .switching
            self.silenceGenerator?.start(fps: fps, withAudio: false)
            LogInfo("cameraSwitching start")

            do {
                try newDevice.lockForConfiguration()
                newDevice.activeFormat = newFormat
                
                // https://developer.apple.com/library/content/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/04_MediaCapture.html
                // If you change the focus mode settings, you can return them to the default configuration as follows:
                if newDevice.isFocusModeSupported(.continuousAutoFocus) {
                    if newDevice.isFocusPointOfInterestSupported {
                        //DDLogVerbose("reset focusPointOfInterest")
                        newDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                    }
                    //DDLogVerbose("reset focusMode")
                    newDevice.focusMode = .continuousAutoFocus
                }
                let initZoom: CGFloat
                self.baseZoomFactor = CameraHelper.getInitZoomFactor(forDevice: newDevice)
                let backZoom = self.cameraConfig.get(.back).zoom
                if newDevice.position == .back && backZoom > 0 {
                    initZoom = backZoom
                } else {
                    initZoom = self.baseZoomFactor
                }
                newDevice.videoZoomFactor = initZoom
                self.maxZoomFactor = self.findMaxZoom(camera: newDevice, format: newFormat)
                self.defaultFocus(camera: newDevice)
                self.restoreWhiteBalance(camera: newDevice)
                newDevice.unlockForConfiguration()
                
                session.beginConfiguration()
                session.removeInput(self.videoIn!)
                
                self.captureDevice = newDevice
                let position = newDevice.position
                self.transform?.postion = position
                self.videoIn = try AVCaptureDeviceInput(device: self.captureDevice!)
                
                if session.canAddInput(self.videoIn!) {
                    session.addInput(self.videoIn!)
                } else {
                    throw StreamerError.SetupFailed("Failed to add video input")
                }
                
                guard let videoConnection = self.videoOut?.connection(with: AVMediaType.video) else {
                    LogError("streamer fail: can't allocate video connection")
                    throw StreamerError.SetupFailed("Failed to add video output")
                }
                videoConnection.videoOrientation = self.videoOrientation
                self.videoConnection = videoConnection
                self.setVideoStabilizationMode(connection: self.videoConnection!, camera: self.captureDevice!)
                
                // On iOS, the receiver's activeVideoMinFrameDuration resets to its default value if receiver's activeFormat changes; Should first change activeFormat, then set fps
                try newDevice.lockForConfiguration()
                newDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
                newDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
                newDevice.videoZoomFactor = initZoom
                newDevice.unlockForConfiguration()
                session.commitConfiguration()
                self.cameraSwitching = .none
                LogInfo("cameraSwitching done")
                LarixLogger.put(message: "Selected camera \(newDevice.localizedName)", severity: .info, priority: .med)

            } catch {
                LarixLogger.put(message: "can't change camera: \(error)", severity: .error, priority: .high)
                self.delegate?.captureStateDidChange(state: CaptureState.failed, status: error)
            }
            self.updateAudio(cameraPosition: newDevice.position)
            //self.lockedParameters = []
            self.delegate?.notification(notification: StreamerNotification.ActiveCameraDidChange)
        }
    }
    
    override func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput) {
        if videoDataOutput != videoOut {
            return
        }
        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        //DDLogVerbose("didOutput sampleBuffer: video \(sampleTime.seconds)")
        if paused {
            silenceGenerator?.outputBlackFrame(withPresentationTime: sampleTime)
        }
        if self.cameraSwitching != .switching {
            self.silenceGenerator?.stop()
        }
        if silenceGenerator?.handleVideoSampleBuffer(sampleBuffer) == false {
            return
        }
        let canEncode = encodingStarted || externalEncodingMode
        if let pixelBuffer = delegate?.processVideoSampleBuffer(sampleBuffer, cameraPosition: cameraPosition) {
            if canEncode {
                engine.didOutputVideoPixelBuffer(pixelBuffer, withPresentationTime: sampleTime)
            }
            return
        }

        if paused || !canEncode {
            return
        }
        let mode = videoConfig?.processingMode ?? .disabled
        let hasOverlays = imageLayer.outputImage != nil || webViews.contains(where: \.hasImage)
        switch mode {
            case .metal where MetalCore.instance != nil:
                rotateAndEncodeMetal(sampleBuffer: sampleBuffer)
        case .coreImage:
            rotateAndEncode(sampleBuffer: sampleBuffer)
        case .disabled where hasOverlays:
            encodeWithOverlays(sampleBuffer: sampleBuffer)
        default:
            engine.didOutputVideoSampleBuffer(sampleBuffer)

        }
    }

    // MARK: jpeg capture
    override func captureStillImage(fileUrl: URL, format: AVFileType? = nil) {
        guard cameraSwitching == .none else {
            return
        }
        if photoFileUrl != nil {
            LogError("Capture already in progress")
            self.delegate?.snapshotStateDidChange(state: .failed, fileUrl: nil)
            return
        }
        let fileName = fileUrl.lastPathComponent
        if fileName.isEmpty {
            LogError("No filename provided")
            self.delegate?.snapshotStateDidChange(state: .failed, fileUrl: nil)
            return
        }
        let snapshotFormat: AVFileType
        if format == nil {
            snapshotFormat = fileUrl.pathExtension.caseInsensitiveCompare(".heic") == .orderedSame ? .heic : .jpg
        } else {
            snapshotFormat = format!
        }
        guard let out = self.imageOut as? AVCapturePhotoOutput else {
            LogError("No photo output configured")
            self.delegate?.snapshotStateDidChange(state: .failed, fileUrl: nil)
            return
        }
        photoFileUrl = fileUrl
        var codecs: [AVVideoCodecType] = []
        if snapshotFormat == .heic {
            codecs = out.supportedPhotoCodecTypes(for: .heic)
            if codecs.isEmpty {
                LogWarn("HEIC is not available, fallback to JPEG")
                let newUrl = fileUrl.deletingPathExtension().appendingPathExtension(".jpg")
                photoFileUrl = newUrl
            }
        }
        if codecs.isEmpty {
            codecs = out.supportedPhotoCodecTypes(for: .jpg)
        }
        if let codec = codecs.first {
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey:codec])
            let videoConnection = out.connection(with: .video)
            videoConnection?.videoOrientation = self.orientation

            out.capturePhoto(with: settings, delegate: self)
        }

    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error == nil, let imageData = photo.fileDataRepresentation(), let url = photoFileUrl {
            do {
                try imageData.write(to: url, options: .atomic)
                self.delegate?.snapshotStateDidChange(state: .stopped, fileUrl: url)
                LogVerbose("save photo to \(url.absoluteString)")
            } catch {
                LogError("failed to photo jpeg: \(error)")
                self.delegate?.snapshotStateDidChange(state: .failed, fileUrl: nil)

            }
        }
        photoFileUrl = nil
    }

    // MARK: Live rotation
    private func rotateAndEncode(sampleBuffer: CMSampleBuffer) {
        
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let outputBuffer = bufferPool?.createOutputBuffer(with: formatDescription) else {
            LogError("error in CVPixelBufferCreate")
            return
        }

        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        let sourceBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        transform?.orientation = orientation
       
        let sourceImage = CIImage(cvPixelBuffer: sourceBuffer, options: [CIImageOption.colorSpace: NSNull()])
        let bounds = CGRect(x: 0, y: 0, width: streamWidth, height: streamHeight)
        if let cfg = videoConfig?.cameraWindow {
            transform?.alignX = cfg.alignX
            transform?.alignY = 1.0-cfg.alignY
            transform?.scalePipX = cfg.scale
            transform?.scalePipY = cfg.scale
        } else {
            transform?.alignX = 0.5
            transform?.alignY = 0.5
            transform?.scalePipX = 1.0
            transform?.scalePipY = 1.0
        }
        guard let transformMatrix = transform?.getMatrix(extent: bounds) else {
            LogError("Failed to get transformation")
            return
        }
        var outputImage = sourceImage.transformed(by: transformMatrix)

        outputImage = combineWithOverlay(sourceImage: outputImage)
        
        if let context = ciContext {
            context.render(outputImage, to: outputBuffer, bounds: outputImage.extent, colorSpace: nil)
            engine.didOutputVideoPixelBuffer(outputBuffer, withPresentationTime:sampleTime)
        }
    }
    
    private func rotateAndEncodeMetal(sampleBuffer: CMSampleBuffer) {
        guard let metal = MetalCore.instance else {
            return
        }
        
        
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let outputBuffer = bufferPool?.createOutputBuffer(with: formatDescription) else {
            LogError("error in CVPixelBufferCreate")
            return
        }

        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            LogError("no image buffer")
            return
        }

        if let srcTexture = metal.makeTexture(from: sourceBuffer),
           let destTexture = bufferPool?.createOutputTexture(from: outputBuffer) {

            if overlayTexture == nil, let overlayImage = imageLayer.outputImage {
                overlayTexture = metal.imageToTexture(overlayImage)
            }
            let bounds = CGRect(x: 0, y: 0, width: streamWidth, height: streamHeight)
            let transformMatrix: CGAffineTransform
//            if postprocess {
                guard let transform = transform else {
                    LogError("Failed to get transformation")
                    return
                }
                transform.orientation = orientation
                transformMatrix = transform.getMatrix(extent: bounds, flipped: orientation == .portrait)
//            } else {
//                //Use matrix with zero transformation if live rotation is turned off
//                transformMatrix = CGAffineTransform(translationX: 0, y: 0)
//            }

            metal.rotateAndEncode(source: srcTexture, overlay: overlayTexture, output: destTexture, transform: transformMatrix) { bufferHandler in
                if bufferHandler.status == .completed {
                    self.engine.didOutputVideoPixelBuffer(outputBuffer, withPresentationTime:sampleTime)
                } else if bufferHandler.status == .error {
                    if MetalCore.instance != nil {
                        LarixLogger.put(message: "GPU processing failed, switched to CoreImage processing", severity: .warn, priority: .high)
                        MetalCore.shutdown()
                        self.videoConfig?.processingMode = .coreImage
                    }
                    self.rotateAndEncode(sampleBuffer: sampleBuffer)
                }
            }
            
        }

    }
    
    private func encodeWithOverlays(sampleBuffer: CMSampleBuffer) {
        
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let outputBuffer = bufferPool?.createOutputBuffer(with: formatDescription) else {
            LogError("error in CVPixelBufferCreate")
            return
        }

        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
       
        let sourceImage = CIImage(cvPixelBuffer: sourceBuffer, options: [CIImageOption.colorSpace: NSNull()])
        let outputImage = combineWithOverlay(sourceImage: sourceImage)

        if let context = ciContext {
            context.render(outputImage, to: outputBuffer, bounds: outputImage.extent, colorSpace: nil)
            engine.didOutputVideoPixelBuffer(outputBuffer, withPresentationTime:sampleTime)
        }
    }
    

    func combineWithOverlay(sourceImage: CIImage) -> CIImage {
        var outputImage = sourceImage
        webViews.forEach { webView in
            webView.withOutputImage { webImage in
                outputImage = webImage.composited(over: outputImage)
            }
        }
        
        if let layerImage = imageLayer.outputImage, layerImage.extent.size != CGSize.zero {
            outputImage = layerImage.composited(over: outputImage)
        }
        return outputImage

    }
    
    func todayString() -> String {
        let date = Date()
        let calender = Calendar.current
        let components = calender.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
        
        let year = components.year
        let month = components.month
        let day = components.day
        let hour = components.hour
        let minute = components.minute
        let second = components.second
        
        return String(year!) + "-" + String(month!) + "-" + String(day!) + " " + String(hour!)  + ":" + String(minute!) + ":" +  String(second!)
    }
    
    // MARK: Autofocus
    override func continuousMetering(at focusPoint: CGPoint?,
                                  position: AVCaptureDevice.Position = .unspecified,
                                  parameters: CameraMeteringParameters = [.Focus]) {
        setMetering(camera: captureDevice, at: focusPoint, locked: false, parameters: parameters)
    }
    
    override func fixedMetering(at focusPoint: CGPoint?,
                                           position: AVCaptureDevice.Position = .unspecified,
                                           parameters: CameraMeteringParameters = [.Focus]) {
        setMetering(camera: captureDevice, at: focusPoint, locked: true, parameters: parameters)
    }
    
    override func canPointTo(position: AVCaptureDevice.Position = .unspecified,
                           parameters: CameraMeteringParameters = [.Focus]) -> Bool {
        return pointOfInterestSupported(camera: captureDevice, parameters: parameters)
    }

    override func canSetColorTemperature(position: AVCaptureDevice.Position = .unspecified) -> Bool {
        return captureDevice?.isLockingWhiteBalanceWithCustomDeviceGainsSupported ?? false
    }

    override public func getColorTemperatureK(position: AVCaptureDevice.Position = .unspecified) -> Float {
        guard let camera = captureDevice else {
            return 0
        }
        return CameraHelper.getColorTemp(camera: camera)
    }


    override public func setColorTemperature(tempKelvins: Float = 0, position: AVCaptureDevice.Position = .unspecified) {
        setColorTemperature(tempKelvins: tempKelvins, camera: captureDevice)
    }
    
    override func resetFocus() {
        workQueue.async {
            if let camera = self.captureDevice {
                do {
                    try camera.lockForConfiguration()
                    self.defaultFocus(camera: camera)
                    camera.unlockForConfiguration()
                } catch {
                    LogError("can't lock video device for configuration: \(error)")
                }
            }
        }
    }

    override func zoomTo(factor: CGFloat) {
        workQueue.async {
            if let camera = self.captureDevice {
                do {
                    if factor > camera.activeFormat.videoMaxZoomFactor || factor < 1.0 {
                        return
                    }
                    try camera.lockForConfiguration()
                    camera.videoZoomFactor = factor
                    camera.unlockForConfiguration()
                    self.cameraConfig.get(camera.position).zoom = factor
                } catch {
                    LogError("can't lock video device for configuration: \(error)")
                }
            } else {
                LogError("No camera")
            }
        }
    }
    
    override func getCurrentZoom() -> CGFloat {
        return self.captureDevice?.videoZoomFactor ?? 1.0
    }
    
    override func updateFps(_ fps: Double) {
        guard let camera = captureDevice else {
            return
        }
        if abs(fps - currentFps) < 1.0 {
            return
        }

        var relFps = fps
        let format = camera.activeFormat
        let ranges = format.videoSupportedFrameRateRanges
        var newFormat: AVCaptureDevice.Format?
//        for range in ranges {
//            NSLog("Range \(range.minFrameRate) - \(range.maxFrameRate) FPS")
//        }
        if !ranges.contains(where:{ $0.maxFrameRate >= relFps && $0.minFrameRate <= relFps } ) {
            //Need to switch to another format
            var newConfig = videoConfig
            newConfig?.fps = fps
            newFormat = CameraHelper.findFormat(camera: camera, videoConfig: &newConfig, validateFn: isValidFormat)
            relFps = newConfig?.fps ?? fps
        }
        do {
            try camera.lockForConfiguration()
            if let format = newFormat {
                camera.activeFormat = format
            }
            camera.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(relFps))
            camera.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(relFps))
            camera.unlockForConfiguration()
            currentFps = relFps
        } catch {
            LogError("can't lock video device for configuration: \(error)")
        }
    }
    
    override func toggleFlash() -> Bool {
        guard cameraSwitching == .none else {
            return false
        }
        guard let captureDevice = captureDevice else {
            return false
        }
        return CameraHelper.toggleFlash(camera: captureDevice)
    }
    
    override func setExposureCompensation(_ ev: Float, position: AVCaptureDevice.Position = .unspecified) {
        guard let camera = captureDevice else { return }
        do {
            try camera.lockForConfiguration()
            camera.setExposureTargetBias(ev)
            camera.unlockForConfiguration()
        } catch {
            LogError("can't lock video device for configuration: \(error)")
        }
    }
    
    override func getExposureCompensation(position: AVCaptureDevice.Position = .unspecified) -> Float {
        return captureDevice?.exposureTargetBias ??  0.0
    }

    override func supportFlash() -> Bool {
        guard let camera = captureDevice else { return false}
        return camera.hasTorch && camera.isTorchAvailable
    }
    
    override func flashOn() -> Bool {
        guard let camera = captureDevice else { return false}
        return camera.hasTorch && camera.isTorchAvailable && camera.torchMode == .on
    }
    
    override func getSwitchZoomFactors() -> [CGFloat] {
        guard let camera = captureDevice else { return []}
        return CameraHelper.getSwitchZoomFactors(forDevice: camera)
    }
    
    override public func onImageLoadComplete() {
        overlayTexture = nil
        super.onImageLoadComplete()
    }

    override func createPreviewLayer(parentView: UIView) -> PreviewLayer? {
        guard let session = session else {
            return nil
        }
        let preview = PreviewLayerSingleCam(parent: parentView)
        preview.createPreview(session: session)
        if let camView = videoConfig?.cameraWindow {
            preview.previewRect = PipPosition(scale: camView.scale, alignX: camView.alignX, alignY: camView.alignY)
        }
        preview.getCameraPosition = {
            self.cameraPosition
        }
        return preview
    }
    
    override func getActiveCameraInfo() -> [ActiveCameraInfo] {
        guard let camera = captureDevice else {
            return []
        }
        let info = CameraManager.getActiveCameraInfo(for: camera)
        return [info]
    }


    
}
