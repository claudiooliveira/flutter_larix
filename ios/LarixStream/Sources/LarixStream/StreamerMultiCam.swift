
import Foundation
import AVFoundation
import CoreImage
import UIKit
import LarixSupport
import LarixUI

@available(iOS 13.0, *)
class StreamerMultiCam: StreamerInternal {
    
    // video
    private weak var backCameraVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    private weak var frontCameraVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    private var backCameraDeviceInput: AVCaptureDeviceInput?
    private var frontCameraDeviceInput: AVCaptureDeviceInput?
    private let backCameraVideoDataOutput = AVCaptureVideoDataOutput()
    private let frontCameraVideoDataOutput = AVCaptureVideoDataOutput()
    private var frontCameraVideoPort: AVCaptureInput.Port?
    private var backCameraVideoPort: AVCaptureInput.Port?
    private var currentPiPSampleBuffer: CMSampleBuffer?
    private var mainTransform: ImageTransform?
    private var pipTransform: ImageTransform?
    
    // jpeg capture
    private var imageOutFront: AVCaptureOutput?
    private var imageOutBack: AVCaptureOutput?
    private var imageOutFrontConnection: AVCaptureConnection?
    private var imageOutBackConnection: AVCaptureConnection?
    private var savedImage: CIImage?
    private var snapshotFormat: AVFileType = .jpg

    override var postprocess: Bool {
        return true
    }
    
    var multiCamConfig: MultiCamConfig?
    private var pipDevicePosition: MultiCamPicturePosition = .off

    override func createSession() -> AVCaptureSession? {
        return AVCaptureMultiCamSession()
    }
    
    override func setupVideoIn() throws {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            LarixLogger.put(message: "MultiCam not supported on this device", severity: .error, priority: .high)
            throw StreamerError.MultiCamNotSupported
        }
        let cameraPos = multiCamConfig?.primaryCameraPosition ?? .back
        let multiCamMode = multiCamConfig?.mode ?? .off
        switch multiCamMode {
        case .pip:
            pipDevicePosition = cameraPos == .back ? .pip_front : .pip_back
        case .sideBySide:
            pipDevicePosition = cameraPos == .back ? .left_back : .left_front
        default:
            pipDevicePosition = .off
        }
        
        guard configureBackCameraIn() else {
           throw StreamerError.SetupFailed("Back camera input error")
        }
        
        guard configureFrontCameraIn() else {
            throw StreamerError.SetupFailed("Front camera input error")
        }
    }
    
    override func setupVideoOut() throws {
        guard configureBackCameraOut() else {
           throw StreamerError.SetupFailed("Back camera output error")
        }
        
        guard configureFrontCameraOut() else {
            throw StreamerError.SetupFailed("Front camera output error")
        }
    }
    
    override func setupMetal() {
        MetalCore.startup(dual: true)
        if let metal = MetalCore.instance {
            metal.videoSize = CGSize(width: self.streamWidth, height: self.streamHeight)
        }
    }

    private func configureBackCameraIn() -> Bool {
        guard let session = session as? AVCaptureMultiCamSession else {return false}
        
        guard let pipConfig = multiCamConfig else {
            return false
        }

        // Find the back camera
        guard let backCamera = AVCaptureDevice(uniqueID: pipConfig.backCameraID), backCamera.position == .back else {
            LogError("Could not find the back camera")
            return false
        }
        
        self.backCamera = backCamera
        
        // Add the back camera input to the session
        do {
            backCameraDeviceInput = try AVCaptureDeviceInput(device: backCamera)
            
            guard let backCameraDeviceInput = backCameraDeviceInput,
                session.canAddInput(backCameraDeviceInput) else {
                    LogError("Could not add back camera device input")
                    return false
            }
            session.addInputWithNoConnections(backCameraDeviceInput)
        } catch {
            LogError("Could not create back camera device input: \(error)")
            return false
        }
        
        // Find the back camera device input's video port
        guard let backCameraDeviceInput = backCameraDeviceInput,
            let backCameraVideoPort = backCameraDeviceInput.ports(for: .video,
                                                              sourceDeviceType: backCamera.deviceType,
                                                              sourceDevicePosition: backCamera.position).first else {
                                                                LogError("Could not find the back camera device input's video port")
                                                                return false
        }
        
        // Add the back camera video data output
        guard session.canAddOutput(backCameraVideoDataOutput) else {
            LogError("Could not add the back camera video data output")
            return false
        }
        session.addOutputWithNoConnections(backCameraVideoDataOutput)
        backCameraVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(Consts.PixelFormat_RGB)]
        backCameraVideoDataOutput.alwaysDiscardsLateVideoFrames = true
        backCameraVideoDataOutput.setSampleBufferDelegate(self, queue: workQueue)
        
        self.backCameraVideoPort = backCameraVideoPort
        self.baseZoomFactor = CameraHelper.getInitZoomFactor(forDevice: backCamera)

        return true
    }
    
    static func probeMultiCam(videoConfig: VideoConfig, cameraConfig: MultiCamConfig) -> Bool {
        guard let backCamera = AVCaptureDevice(uniqueID: cameraConfig.backCameraID),
              let frontCamera = AVCaptureDevice(uniqueID: cameraConfig.frontCameraID) else {
            return false
        }
        let discovery = AVCaptureDevice.DiscoverySession.init(deviceTypes: [backCamera.deviceType, frontCamera.deviceType], mediaType: .video, position: .unspecified)
        let multicam = discovery.supportedMultiCamDeviceSets
        let fps = videoConfig.fps
        let size = videoConfig.videoSize
        var supported = multicam.contains { (devices) -> Bool in
            devices.contains(frontCamera) && devices.contains(backCamera)
        }
        if !supported {
            return false
        }
        let validateFn: (AVCaptureDevice.Format) -> Bool = { (format) in
            let camResolution = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let camFps = format.videoSupportedFrameRateRanges
            return CMFormatDescriptionGetMediaType(format.formatDescription) == kCMMediaType_Video &&
            format.isMultiCamSupported &&
            camResolution.width >= size.width && camResolution.height >= size.height &&
            camFps.contains{ (range) in
                range.minFrameRate <= fps && fps <= range.maxFrameRate }
        }
        supported = backCamera.formats.contains(where: validateFn) && frontCamera.formats.contains(where: validateFn)
        return supported
    }
    
    private func configureBackCameraOut() -> Bool {

        guard let session = session as? AVCaptureMultiCamSession,
            let backCamera = self.backCamera,
            let backCameraVideoPort = self.backCameraVideoPort else {return false}

        // Connect the back camera device input to the back camera video data output
        let backCameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [backCameraVideoPort], output: backCameraVideoDataOutput)
        guard session.canAddConnection(backCameraVideoDataOutputConnection) else {
            LogError("Could not add a connection to the back camera video data output")
            return false
        }
        session.addConnection(backCameraVideoDataOutputConnection)
        backCameraVideoDataOutputConnection.videoOrientation = .landscapeLeft
        backCameraVideoDataOutputConnection.automaticallyAdjustsVideoMirroring = false
        backCameraVideoDataOutputConnection.isVideoMirrored = false

        guard let format = setCameraParams(camera: backCamera) else {
            return false
        }
        setVideoStabilizationMode(connection: backCameraVideoDataOutputConnection, camera: backCamera)

        self.maxZoomFactor = findMaxZoom(camera: backCamera, format: format)
        
        return true
    }
    
    private func configureFrontCameraIn() -> Bool {
        guard let session = session as? AVCaptureMultiCamSession else {return false}
        
        guard let pipConfig = multiCamConfig else {
            return false
        }

        // Find the front camera
        guard let frontCamera = AVCaptureDevice(uniqueID: pipConfig.frontCameraID), frontCamera.position == .front else {
            LogError("Could not find the front camera")
            return false
        }
        self.frontCamera = frontCamera
        
        // Add the front camera input to the session
        do {
            frontCameraDeviceInput = try AVCaptureDeviceInput(device: frontCamera)
            
            guard let frontCameraDeviceInput = frontCameraDeviceInput,
                session.canAddInput(frontCameraDeviceInput) else {
                    LogError("Could not add front camera device input")
                    return false
            }
            session.addInputWithNoConnections(frontCameraDeviceInput)
        } catch {
            LogError("Could not create front camera device input: \(error)")
            return false
        }
        
        // Find the front camera device input's video port
        guard let frontCameraDeviceInput = frontCameraDeviceInput,
            let frontCameraVideoPort = frontCameraDeviceInput.ports(for: .video,
                                                                    sourceDeviceType: frontCamera.deviceType,
                                                                    sourceDevicePosition: frontCamera.position).first else {
            LogError("Could not find the front camera device input's video port")
            return false
        }
        self.frontCameraVideoPort = frontCameraVideoPort
        
        return true
    }
        
    private func configureFrontCameraOut() -> Bool {
        guard let session = session as? AVCaptureMultiCamSession,
        let frontCamera = self.frontCamera,
        let frontCameraVideoPort = self.frontCameraVideoPort else {return false}

        // Add the front camera video data output
        guard session.canAddOutput(frontCameraVideoDataOutput) else {
            LogError("Could not add the front camera video data output")
            return false
        }
        session.addOutputWithNoConnections(frontCameraVideoDataOutput)
        frontCameraVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(Consts.PixelFormat_RGB)]
        frontCameraVideoDataOutput.alwaysDiscardsLateVideoFrames = true
        frontCameraVideoDataOutput.setSampleBufferDelegate(self, queue: workQueue)
        
        // Connect the front camera device input to the front camera video data output
        let frontCameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [frontCameraVideoPort], output: frontCameraVideoDataOutput)
        guard session.canAddConnection(frontCameraVideoDataOutputConnection) else {
            LogError("Could not add a connection to the front camera video data output")
            return false
        }
        self.frontCameraVideoPort = frontCameraVideoPort
        session.addConnection(frontCameraVideoDataOutputConnection)
        frontCameraVideoDataOutputConnection.videoOrientation = .landscapeLeft
        frontCameraVideoDataOutputConnection.automaticallyAdjustsVideoMirroring = false
        frontCameraVideoDataOutputConnection.isVideoMirrored = false

        guard setCameraParams(camera: frontCamera) != nil else {
            return false
        }
        setVideoStabilizationMode(connection: frontCameraVideoDataOutputConnection, camera: frontCamera)

        return true
    }
    
    
    override func isValidFormat(_ format: AVCaptureDevice.Format) -> Bool {
        return CMFormatDescriptionGetMediaType(format.formatDescription) == kCMMediaType_Video && format.isMultiCamSupported
    }

    override func setupStillImage() throws {
        guard let session = self.session else {
            return
        }
        let imageOutFront = AVCapturePhotoOutput()
        session.addOutputWithNoConnections(imageOutFront)
        
        // Connect the front camera device input to the front camera photo output
        let imageOutFrontConnection = AVCaptureConnection(inputPorts: [frontCameraVideoPort!], output: imageOutFront)
        imageOutFrontConnection.videoOrientation = orientation
        imageOutFrontConnection.automaticallyAdjustsVideoMirroring = false
        imageOutFrontConnection.isVideoMirrored = false

        guard session.canAddConnection(imageOutFrontConnection) else {
            LogError("Could not add a connection to the front camera video data output")
            throw StreamerError.SetupFailed("Failed to add front photo output")
        }
        session.addConnection(imageOutFrontConnection)
        self.imageOutFront = imageOutFront
        self.imageOutFrontConnection = imageOutFrontConnection
        
        let imageOutBack = AVCapturePhotoOutput()
        session.addOutputWithNoConnections(imageOutBack)
        
        // Connect the back camera device input to the front camera photo output
        let imageOutBackConnection = AVCaptureConnection(inputPorts: [backCameraVideoPort!], output: imageOutBack)
        imageOutBackConnection.videoOrientation = orientation
        imageOutBackConnection.automaticallyAdjustsVideoMirroring = false
        imageOutBackConnection.isVideoMirrored = false

        guard session.canAddConnection(imageOutBackConnection) else {
            LogError("Could not add a connection to the back camera photo data output")
            throw StreamerError.SetupFailed("Failed to add back photo output")
        }
        session.addConnection(imageOutBackConnection)
        self.imageOutBack = imageOutBack
        self.imageOutBackConnection = imageOutBackConnection

    }
    
    internal func connectPreview(back: AVCaptureVideoPreviewLayer, front: AVCaptureVideoPreviewLayer) -> Bool {
        guard let session = self.session, let frontCamPort = self.frontCameraVideoPort, let backCamPort = self.backCameraVideoPort else {
            return false
        }
        
        // Connect the front camera device input to the front camera video preview layer
        frontCameraVideoPreviewLayer = front
        let frontCameraVideoPreviewLayerConnection = AVCaptureConnection(inputPort: frontCamPort, videoPreviewLayer: front)
        guard session.canAddConnection(frontCameraVideoPreviewLayerConnection) else {
            LogError("Could not add a connection to the front camera video preview layer")
            return false
        }
        session.addConnection(frontCameraVideoPreviewLayerConnection)
        frontCameraVideoPreviewLayerConnection.automaticallyAdjustsVideoMirroring = false
        frontCameraVideoPreviewLayerConnection.isVideoMirrored = true
        
        // Connect the back camera device input to the back camera video preview layer
        backCameraVideoPreviewLayer = back
        let backCameraVideoPreviewLayerConnection = AVCaptureConnection(inputPort: backCamPort, videoPreviewLayer: back)
        guard session.canAddConnection(backCameraVideoPreviewLayerConnection) else {
            LogError("Could not add a connection to the back camera video preview layer")
            return false
        }
        session.addConnection(backCameraVideoPreviewLayerConnection)
        backCameraVideoPreviewLayerConnection.automaticallyAdjustsVideoMirroring = false
        backCameraVideoPreviewLayerConnection.isVideoMirrored = false
        return true
    }

    override func releaseCapture() {
        // detach compression sessions and mp4 recorder
        frontCameraVideoDataOutput.setSampleBufferDelegate(nil, queue: nil)
        backCameraVideoDataOutput.setSampleBufferDelegate(nil, queue: nil)

        super.releaseCapture()
        backCameraDeviceInput = nil
        frontCameraDeviceInput = nil
        frontCameraVideoPort = nil
        backCameraVideoPort = nil
        backCamera = nil
        frontCamera = nil

        currentPiPSampleBuffer = nil
        mainTransform = nil
        pipTransform = nil
    }

    override func changeCamera(to _: AVCaptureDevice?) {
        pipDevicePosition = pipDevicePosition.opposite
        currentPiPSampleBuffer = nil
    }
    
    override func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput) {
        if videoDataOutput != frontCameraVideoDataOutput && videoDataOutput != backCameraVideoDataOutput {
            return
        }
        
        // will be true either if PiP is front and got back camera sample, or PiP is back and got front camera sample
        let isFullScreenBuffer = (pipDevicePosition == .pip_front || pipDevicePosition == .left_back) == (videoDataOutput == backCameraVideoDataOutput)
        if pauseMode != .off {
            if isFullScreenBuffer {
                let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                silenceGenerator?.outputBlackFrame(withPresentationTime: sampleTime)
            }
            return
        }
        let camPos: AVCaptureDevice.Position = videoDataOutput == frontCameraVideoDataOutput ? .front : .back
        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let canEncode = encodingStarted || externalEncodingMode
        if let pixelBuffer = delegate?.processVideoSampleBuffer(sampleBuffer, cameraPosition: camPos) {
            if canEncode {
                engine.didOutputVideoPixelBuffer(pixelBuffer, withPresentationTime: sampleTime)
            }
            return
        }
        if !canEncode {
            return
        }

        if isFullScreenBuffer {
            processFullScreenSampleBuffer(sampleBuffer)
        } else {
            processPiPSampleBuffer(sampleBuffer)
        }
    }
    
    private func processFullScreenSampleBuffer(_ fullScreenSampleBuffer: CMSampleBuffer) {
        
        guard let fullScreenPixelBuffer = CMSampleBufferGetImageBuffer(fullScreenSampleBuffer) else {
            return
        }

        guard let pipSampleBuffer = currentPiPSampleBuffer,
            let pipPixelBuffer = CMSampleBufferGetImageBuffer(pipSampleBuffer) else {
                return
        }
        
        let sampleTime = CMSampleBufferGetPresentationTimeStamp(fullScreenSampleBuffer)
        guard let formatDescription = CMSampleBufferGetFormatDescription(fullScreenSampleBuffer) else {
            LogError("Bad buffer")
            return
        }
        updateMainTransform()
        if MetalCore.instance != nil {
            rotateAndEncodeMetal(fullScreenPixelBuffer: fullScreenPixelBuffer,
                                        pipPixelBuffer: pipPixelBuffer,
                                        sampleTime: sampleTime,
                                        with: formatDescription)
        } else  {
            guard let outputImage = rotateAndEncode(fullScreenPixelBuffer: fullScreenPixelBuffer,
                                                 pipPixelBuffer: pipPixelBuffer,
                                                 with: formatDescription) else {
                LogError("Unable to combine video")
                return
            }
            engine.didOutputVideoPixelBuffer(outputImage, withPresentationTime:sampleTime)
        }
    }
    
    private func updateMainTransform() {
        if mainTransform == nil {
            mainTransform = ImageTransform(size: CMVideoDimensions(width: Int32(streamWidth), height: Int32(streamHeight)))
        }
        guard let transform = mainTransform else {
            return
        }
        transform.orientation = orientation
        transform.portraitVideo = videoConfig!.portrait
        transform.postion = (pipDevicePosition == .pip_front || pipDevicePosition == .left_back) ? .back : .front
        if let cfg = videoConfig?.cameraWindow {
            transform.alignX = cfg.alignX
            transform.alignY = 1.0-cfg.alignY
            transform.scalePipX = cfg.scale
            transform.scalePipY = cfg.scale
        }
    }
    
    private func processPiPSampleBuffer(_ pipSampleBuffer: CMSampleBuffer) {
        updatePipTransform()
        currentPiPSampleBuffer = pipSampleBuffer
    }
    
    private func updatePipTransform() {
        if pipTransform == nil {
            guard let videoConfig = videoConfig, let pipConfig = multiCamConfig else {
                return
            }
            let videoSize = CMVideoDimensions(width: Int32(streamWidth), height: Int32(streamHeight))
            pipTransform = ImageTransform(size: videoSize, scale: pipConfig.pipScale)
            pipTransform?.alignX = pipConfig.alignX
            pipTransform?.alignY = 1.0 - pipConfig.alignY
            pipTransform?.portraitVideo = videoConfig.portrait
        }
        pipTransform?.orientation = orientation
        pipTransform?.postion = (pipDevicePosition == .pip_front || pipDevicePosition == .left_back) ? .front : .back    }
    
    // MARK: jpeg capture
    override func captureStillImage(fileUrl: URL, format: AVFileType? = nil) {
        if photoFileUrl != nil {
            LogError("Capture already in progress")
            return
        }
        photoFileUrl = fileUrl
        
        if format == nil {
            snapshotFormat = fileUrl.pathExtension.caseInsensitiveCompare("heic") == .orderedSame ? .heic : .jpg
        } else {
            snapshotFormat = format!
        }

        guard let outFront = self.imageOutFront as? AVCapturePhotoOutput,
            let outBack = self.imageOutBack as? AVCapturePhotoOutput else { return }

        let settings = AVCapturePhotoSettings(format: [String(kCVPixelBufferPixelFormatTypeKey):Consts.PixelFormat_RGB])
        outFront.capturePhoto(with: settings, delegate: self)
        outBack.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let fileUrl = photoFileUrl else {
            LogError("No file URL provided")
            self.delegate?.snapshotStateDidChange(state: .failed, fileUrl: nil)
            return
        }
        guard error == nil, let imageData = photo.cgImageRepresentation() else {
            LogError("Failed to store image: \(error?.localizedDescription ?? "(Unknown)" )")
            self.delegate?.snapshotStateDidChange(state: .failed, fileUrl: nil)
            return
        }
        let srcImage: CIImage
        #if swift(>=5.5)
            srcImage = CIImage(cgImage: imageData)
        #else
            srcImage = CIImage(cgImage: imageData.takeUnretainedValue())
        #endif
        if savedImage == nil {
            savedImage = srcImage
            return
        }
        defer {
            savedImage = nil
            photoFileUrl = nil
        }
        let isFullScreenBuffer = (pipDevicePosition == .pip_front || pipDevicePosition == .left_back) == (output == imageOutBack)
        let mainImageSrc: CIImage? = isFullScreenBuffer ? srcImage : savedImage
        let pipImageSrc: CIImage? = isFullScreenBuffer ? savedImage : srcImage
        
        let bounds = CGRect(x: 0, y: 0, width: streamWidth, height: streamHeight)
        
        let mainMirror = !(pipDevicePosition == .pip_front || pipDevicePosition == .left_back)
        let pipMirror = (pipDevicePosition == .pip_front || pipDevicePosition == .left_back)
        updateMainTransform()
        updatePipTransform()
        guard let transformMatrix = mainTransform?.getMatrix(extent: bounds, flipped: mainMirror),
            let pipMatrix = pipTransform?.getMatrix(extent: bounds, flipped: pipMirror) else {
            return
        }
        guard let context = ciContext else {
            LogError("No graphics context")
            return
        }
        guard let mainImage = mainImageSrc?.transformed(by: transformMatrix),
                let pipImage = pipImageSrc?.transformed(by: pipMatrix)
               else {
                  LogError("Bad source images")
                  return
              }
        let outImage = pipImage.composited(over: mainImage)
        let color = mainImage.colorSpace
        let options: [CIImageRepresentationOption: Any] = [:]
        do {
            if snapshotFormat == .heic {
                if let tmpImage = context.createCGImage(outImage, from: bounds) {
                    // Do some magic with image conversion - writeHEIF fails with saving outImage directly
                    let fixedImage = CIImage(cgImage: tmpImage)
                    try context.writeHEIFRepresentation(of: fixedImage, to: fileUrl, format: .BGRA8, colorSpace: color!, options: options)
                }
            } else {
                try context.writeJPEGRepresentation(of: outImage, to: fileUrl, colorSpace: color!, options: options)
            }
            self.delegate?.snapshotStateDidChange(state: .stopped, fileUrl: fileUrl)
            photoFileUrl = nil
        } catch {
            LogError("failed to save jpeg: \(error)")
            self.delegate?.snapshotStateDidChange(state: .failed, fileUrl: nil)
        }
    }
    
    // MARK: Live rotation
    private func rotateAndEncode(fullScreenPixelBuffer: CVPixelBuffer,
                                 pipPixelBuffer: CVPixelBuffer,
                                 with inputFormatDescription: CMFormatDescription) -> CVPixelBuffer? {
        guard let outputBuffer = bufferPool?.createOutputBuffer(with: inputFormatDescription) else {
            LogError("error in CVPixelBufferCreate")
            return nil
        }
        
        updateTransform()
        
        let sourceImage = CIImage(cvPixelBuffer: fullScreenPixelBuffer, options: [CIImageOption.colorSpace: NSNull()])
        var pipImage = CIImage(cvPixelBuffer: pipPixelBuffer, options: [CIImageOption.colorSpace: NSNull()])
        let bounds = CGRect(x: 0, y: 0, width: streamWidth, height: streamHeight)

        guard let transformMatrix = mainTransform?.getMatrix(extent: bounds, flipped: true), let pipMatrix = pipTransform?.getMatrix(extent: bounds, flipped: true) else {
            return nil
        }

        var outputImage = sourceImage.transformed(by: transformMatrix)
        pipImage = pipImage.transformed(by: pipMatrix)

        if let context = ciContext {
            outputImage = pipImage.composited(over: outputImage)
            
            webViews.forEach { webView in
                webView.withOutputImage { webImage in
                    outputImage = webImage.composited(over: outputImage)
                }
            }
            
            if let layerImage = imageLayer.outputImage, layerImage.extent.size != CGSize.zero  {
                outputImage = layerImage.composited(over: outputImage)
            }
            context.render(outputImage, to: outputBuffer, bounds: bounds, colorSpace: nil)

        }
        return outputBuffer
        
    }
    
    private func rotateAndEncodeMetal(fullScreenPixelBuffer: CVPixelBuffer,
                                      pipPixelBuffer: CVPixelBuffer,
                                      sampleTime: CMTime,
                                      with inputFormatDescription: CMFormatDescription) {
        guard let metal = MetalCore.instance else {
            LogError("Metal device not initalized")
            return
        }
        guard let outputBuffer = bufferPool?.createOutputBuffer(with: inputFormatDescription) else {
            LogError("error in CVPixelBufferCreate")
            return
        }
        updateTransform()

        guard let fullTexture = metal.makeTexture(from: fullScreenPixelBuffer),
              let pipTexture = metal.makeTexture(from: pipPixelBuffer),
              let destTexture = bufferPool?.createOutputTexture(from: outputBuffer) else {
            LogError("Can't allocate texture")
            return
        }
        
        if overlayTexture == nil, let overlayImage = imageLayer.outputImage {
            overlayTexture = metal.imageToTexture(overlayImage)
        }
        
        let bounds = CGRect(x: 0, y: 0, width: streamWidth, height: streamHeight)
        let flip = orientation != .portrait
        if let mainMatrix = mainTransform?.getMatrix(extent: bounds, flipped: flip, invertY: true),
           let pipMatrix = pipTransform?.getMatrix(extent: bounds, flipped: flip, invertY: true) {
            metal.rotateAndEncodeDual(main: fullTexture,
                                      pip: pipTexture,
                                      overlay: overlayTexture,
                                      output: destTexture,
                                      mainTransform: mainMatrix,
                                      pipTransform: pipMatrix) {bufferHandler in
                    if bufferHandler.status == .completed {
                        self.engine.didOutputVideoPixelBuffer(outputBuffer, withPresentationTime:sampleTime)
                    } else if bufferHandler.status == .error {
                        LarixLogger.put(message: "GPU processing failed, switched to CoreImage processing", severity: .warn, priority: .high)
                        self.videoConfig?.processingMode = .coreImage
                        MetalCore.shutdown()
                    }
            }
        }
    }
    
    private func updateTransform() {
        let w = CGFloat(streamWidth)
        let h = CGFloat(streamHeight)
        guard let videoConfig = videoConfig, let pipConfig = multiCamConfig else {
            return
        }
        let multiCamMode = pipConfig.mode
        if multiCamMode == .pip && videoConfig.cameraWindow == nil {
            if videoConfig.portrait == false && (orientation == .portrait || orientation == .portraitUpsideDown) {
                let boxW = h * h / w
                let pipW = boxW * pipConfig.pipScale
                let pipL = w * 0.5 - pipW * pipConfig.alignX + boxW * (pipConfig.alignX - 0.5)

                pipTransform?.alignX = pipL / (w - pipW)
            } else if videoConfig.portrait == true && (orientation == .landscapeLeft || orientation == .landscapeRight) {
                let boxH = w * w / h
                let pipH = boxH * pipConfig.pipScale
                let pipT = h * 0.5 + pipH * (pipConfig.alignY - 1.0) + boxH * (0.5 - pipConfig.alignY)
 
                pipTransform?.alignY = pipT / (h - pipH)
            } else {
                pipTransform?.alignX = pipConfig.alignX
                pipTransform?.alignY = 1.0 - pipConfig.alignY
            }
        } else if multiCamMode == .sideBySide {
            if videoConfig.portrait {
                mainTransform?.alignX = 0.5
                pipTransform?.alignX = 0.5
                if orientation == .landscapeLeft || orientation == .landscapeRight {
                    pipTransform?.setScale(1.0)
                    mainTransform?.setScale(1.0)
                    let Ω = (w * w)/(h * h)
                    let y = (0.5 - Ω)/(1.0 - Ω)
                    mainTransform?.alignY = 1 - y
                    pipTransform?.alignY = y
                } else {
                    pipTransform?.setScale(0.5)
                    mainTransform?.setScale(0.5)
                    mainTransform?.alignY = 1.0
                    pipTransform?.alignY = 0.0
                }
            } else  {
                mainTransform?.alignY = 0.5
                pipTransform?.alignY = 0.5
                if orientation == .portrait || orientation == .portraitUpsideDown {
                    pipTransform?.setScale(1.0)
                    mainTransform?.setScale(1.0)
                    mainTransform?.alignX = h / w * 0.5
                    pipTransform?.alignX = 1 - h / w * 0.5
                } else {
                    mainTransform?.setScale(0.5)
                    pipTransform?.setScale(0.5)
                    mainTransform?.alignX = 0.0
                    pipTransform?.alignX = 1.0
                }
            }
        }
    }
    
    // MARK: Autofocus
    override func continuousMetering(at focusPoint: CGPoint?,
                                  position: AVCaptureDevice.Position = .unspecified,
                                  parameters: CameraMeteringParameters = [.Focus]) {
        let camera = position == .front ? frontCamera : backCamera
        setMetering(camera: camera, at: focusPoint, locked: false, parameters: parameters)

    }

    override func fixedMetering(at focusPoint: CGPoint?,
                            position: AVCaptureDevice.Position = .unspecified,
                            parameters: CameraMeteringParameters = [.Focus]) {
        let camera = position == .front ? frontCamera : backCamera
        setMetering(camera: camera, at: focusPoint, locked: true, parameters: parameters)
    }
    
    
    override func canPointTo(position: AVCaptureDevice.Position = .unspecified,
                           parameters: CameraMeteringParameters = [.Focus]) -> Bool {
        let camera = position == .front ? frontCamera : backCamera
        return pointOfInterestSupported(camera: camera, parameters: parameters)
    }
    
    override func canSetColorTemperature(position: AVCaptureDevice.Position = .unspecified) -> Bool {
        let camera = position == .front ? frontCamera : backCamera
        return camera?.isLockingWhiteBalanceWithCustomDeviceGainsSupported ?? false
    }
    
    
    override func getColorTemperatureK(position: AVCaptureDevice.Position = .unspecified) -> Float {
        guard let camera = position == .front ? frontCamera : backCamera else {
            return 0.0
        }
        return CameraHelper.getColorTemp(camera: camera)
    }

    override func setColorTemperature(tempKelvins: Float = 0, position: AVCaptureDevice.Position = .unspecified) {
        let camera = position == .front ? frontCamera : backCamera
        setColorTemperature(tempKelvins: tempKelvins, camera: camera)
    }
    
    
    override public func getLockedParameters() -> CameraMeteringParameters {
        let frontParams = cameraConfig.get(.front).lockedParameters
        let backParams = cameraConfig.get(.back).lockedParameters
        return frontParams.union(backParams)
    }

    override func resetFocus() {
        workQueue.async {
            do {
                if let camera = self.frontCamera {
                    try camera.lockForConfiguration()
                    self.defaultFocus(camera: camera)
                    camera.unlockForConfiguration()
                }
                if let camera = self.backCamera {
                    try camera.lockForConfiguration()
                    self.defaultFocus(camera: camera)
                    camera.unlockForConfiguration()
                }
            }
            catch {
                LogError("can't lock video device for configuration: \(error)")
            }
        }
    }
    
    override func zoomTo(factor: CGFloat) {
        workQueue.async {
            if let camera = self.backCamera {
                do {
                    if factor > camera.activeFormat.videoMaxZoomFactor || factor < 1.0 {
                        return
                    }
                    try camera.lockForConfiguration()
                    camera.videoZoomFactor = factor
                    camera.unlockForConfiguration()
                    self.cameraConfig.get(.back).zoom = factor
                } catch {
                    LogError("can't lock video device for configuration: \(error)")
                }
            }
        }
    }
    
    override func getCurrentZoom() -> CGFloat {
        return backCamera?.videoZoomFactor ?? 1.0
    }

    
    override func updateFps(_ fps: Double) {
        if abs(fps - currentFps) < 1.0 {
            return
        }
        guard let frontCamera = frontCamera, let backCamera = backCamera else {
            return
        }

        var relFps = fps

        let cameras = [frontCamera, backCamera]
        for camera in cameras {
            let format = camera.activeFormat
            let ranges = format.videoSupportedFrameRateRanges
            var newFormat: AVCaptureDevice.Format?
            if !ranges.contains(where:{ $0.maxFrameRate >= relFps && $0.minFrameRate <= relFps } ) {
                //Need to switch to another format
                var newConfig = videoConfig
                newConfig?.fps = fps
                newFormat = CameraHelper.findFormat(camera: camera, videoConfig: &newConfig, validateFn: isValidFormat)
                relFps = newConfig?.fps ?? fps
            }
            do {
                try camera.lockForConfiguration()
                if newFormat != nil {
                    camera.activeFormat = newFormat!
                }
                camera.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(relFps))
                camera.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(relFps))
                camera.unlockForConfiguration()
                currentFps = relFps
            } catch {
                LogError("can't lock video device for configuration: \(error)")
            }
        }
    }
        
    
    override func toggleFlash() -> Bool {
        guard let captureDevice = backCamera else {
            return false
        }
        return CameraHelper.toggleFlash(camera: captureDevice)
    }
    
    override func supportFlash() -> Bool {
        guard let camera = backCamera else { return false}
        return camera.hasTorch && camera.isTorchAvailable
    }
    
    override func flashOn() -> Bool {
        guard let camera = backCamera else { return false}
        return camera.hasTorch && camera.isTorchAvailable && camera.torchMode == .on
    }
    
    override func setExposureCompensation(_ ev: Float, position: AVCaptureDevice.Position = .unspecified) {
        guard let camera = position == .front ? frontCamera : backCamera else { return }
        do {
            try camera.lockForConfiguration()
            camera.setExposureTargetBias(ev)
            camera.unlockForConfiguration()
        } catch {
            LogError("can't lock video device for configuration: \(error)")
        }
    }
    
    override func getExposureCompensation(position: AVCaptureDevice.Position = .unspecified) -> Float {
        guard let camera = position == .front ? frontCamera: backCamera else {return 0.0}
        return camera.exposureTargetBias
    }

    override func getSwitchZoomFactors() -> [CGFloat] {
        guard let camera = backCamera else { return []}
        return CameraHelper.getSwitchZoomFactors(forDevice: camera)
    }

    
    override func onImageLoadComplete() {
        overlayTexture = nil
        super.onImageLoadComplete()
    }
    
    override func createPreviewLayer(parentView: UIView) -> PreviewLayer? {
        guard let session = session, let videoConfig = videoConfig, let pipConfig = multiCamConfig else {
            return nil
        }
        let preview = PreviewLayerMultiCam(parent: parentView)
        preview.createPreview(session: session)
        preview.portraitMode = videoConfig.portrait
        if videoConfig.videoSize.height > 0 {
            preview.aspectRatio = CGFloat(videoConfig.videoSize.width) / CGFloat(videoConfig.videoSize.height)
        }
        if let camView = videoConfig.cameraWindow {
            preview.previewRect = PipPosition(scale: camView.scale, alignX: camView.alignX, alignY: camView.alignY)
        }
        let previewConfig = PipPosition(scale: pipConfig.pipScale,
                                        alignX: pipConfig.alignX,
                                        alignY: pipConfig.alignY)

        preview.pipPosition = previewConfig
        guard let backLayer = preview.backPreviewLayer, let frontLayer = preview.frontPreviewLayer,
              connectPreview(back: backLayer, front: frontLayer) else {
                  LogError("Failed to connect multi-camera preview")
                  return nil
              }
        preview.getCameraPosition = {
            self.pipDevicePosition
        }

        return preview
    }
    
    override func getActiveCameraInfo() -> [ActiveCameraInfo] {
        guard let frontCamera = frontCamera, let backCamera = backCamera else {
            return []
        }
        let frontInfo = CameraManager.getActiveCameraInfo(for: frontCamera)
        let backInfo = CameraManager.getActiveCameraInfo(for: backCamera)
        if pipDevicePosition == .left_back || pipDevicePosition == .pip_front {
            return [backInfo, frontInfo]
        } else {
            return [frontInfo, backInfo]
        }
    }
    
}
