import Foundation
import AVFoundation

extension AVCaptureDevice.DeviceType {
    var shortName: String {
        if #available(iOS 13, *) {
            switch self {
            case .builtInWideAngleCamera:
                return "wide"
            case .builtInTelephotoCamera:
                return "tele"
            case .builtInDualCamera, .builtInDualWideCamera:
                return "dual"
            case .builtInUltraWideCamera:
                return "ultrawide"
            case .builtInTripleCamera:
                return "triple"
            default:
                return "?"
            }

        } else {
            switch self {
            case .builtInWideAngleCamera:
                return "wide"
            case .builtInTelephotoCamera:
                return "tele"
            case .builtInDualCamera:
                return "dual"
            default:
                return "?"

            }
        }
    }
}

extension AVCaptureDevice.Position {
    var shortName: String {
        switch self {
        case .unspecified:
            return "?"
        case .back:
            return "back"
        case .front:
            return "front"
        @unknown default:
            return "?"
        }
    }
}

public class CameraManager: NSObject {
    @objc public func getCameraList() -> [CameraInfo] {
        let cameras: [AVCaptureDevice.DeviceType]
        if #available(iOS 13, *) {
            cameras = [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera, .builtInDualWideCamera, .builtInTripleCamera]
        } else {
            cameras = [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInDualCamera]
        }
        let discovery = AVCaptureDevice.DiscoverySession.init(deviceTypes: cameras, mediaType: .video, position: .unspecified)
        let info: [CameraInfo] = discovery.devices.map { Self.getCameraInfo(for: $0) }
        return info
    }
    
    @objc public func getCameraListObj() -> [NSString: Any] {
        let cameras: [AVCaptureDevice.DeviceType]
        if #available(iOS 13, *) {
            cameras = [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera, .builtInDualWideCamera, .builtInTripleCamera]
        } else {
            cameras = [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInDualCamera]
        }
        let discovery = AVCaptureDevice.DiscoverySession.init(deviceTypes: cameras, mediaType: .video, position: .unspecified)
        let info: [NSDictionary] = discovery.devices.map { Self.getCameraInfo(for: $0).toDictionary() }
        let data = [
            "cameraInfo": info
        ] as [NSString: Any]
        return data

    }
    
    @objc public static func getCameraInfo(for device: AVCaptureDevice) -> CameraInfo {
        let camId = device.uniqueID
        let info = CameraInfo(cameraId: camId)
        var ranges: Set<FpsRange> = []
        var recordSizes: Set<CMVideoDimensions> = []
        
       device.formats.forEach { format in
           let desc = format.formatDescription
           let mediaType = CMFormatDescriptionGetMediaType(desc)
           let pixelFormat = CMFormatDescriptionGetMediaSubType(desc)
           if mediaType != kCMMediaType_Video || pixelFormat != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange {
               return
           }
           let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
           for fps in format.videoSupportedFrameRateRanges {
               let fpsRange = FpsRange(fpsMin: fps.minFrameRate, fpsMax: fps.maxFrameRate)
               ranges.insert(fpsRange)
           }
           recordSizes.insert(dimensions)
            
        }
        info.recordSizes = Array(recordSizes).sorted()
        if #available(iOS 13.0, *) {
            if device.isVirtualDevice {
                info.physicalCameras = device.constituentDevices.map(\.uniqueID)
                info.physicalZoomFactors = device.virtualDeviceSwitchOverVideoZoomFactors.map { $0.floatValue }
            }
        }
        info.lensFacing = device.position.shortName
        info.deviceType = device.deviceType.shortName
        info.fpsRanges = Array(ranges)
        info.maxZoom = Float(device.maxAvailableVideoZoomFactor)
        info.isTorchSupported = device.hasTorch && device.isTorchAvailable
        return info
    }

    public static func getActiveCameraInfo(for device: AVCaptureDevice) -> ActiveCameraInfo {
        let camId = device.uniqueID
        let info = ActiveCameraInfo(cameraId: camId)
        let desc = device.activeFormat.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
        if #available(iOS 13.0, *) {
            if device.isVirtualDevice {
                info.physicalCameras = device.constituentDevices.map(\.uniqueID)
                info.physicalZoomFactors = device.virtualDeviceSwitchOverVideoZoomFactors.map { $0.floatValue }
            }
        }
        let duration = device.activeVideoMaxFrameDuration
        info.lensFacing = device.position.shortName
        info.deviceType = device.deviceType.shortName
        info.recordSize = dimensions
        
        info.fps = Double(duration.timescale) / Double(duration.value)
        info.maxZoom = Float(device.maxAvailableVideoZoomFactor)
        info.isTorchSupported = device.hasTorch && device.isTorchAvailable
        return info
    }
    
    static func probeCam(camera: AVCaptureDevice, videoSize: CMVideoDimensions, fps: Double, multiCam: Bool) -> Bool {
        if multiCam && camera.position == .back {
            if checkMulticam(backCamera: camera, frontCamera: getDefaultFrontCamera()) == false {
                return false
            }
        }
        let supported = camera.formats.contains { (format) in
            let camResolution = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let camFps = format.videoSupportedFrameRateRanges
            var valid = CMFormatDescriptionGetMediaType(format.formatDescription) == kCMMediaType_Video &&
                camResolution.width >= videoSize.width && camResolution.height >= videoSize.height &&
                camFps.contains{ (range) in
                    range.minFrameRate <= fps && fps <= range.maxFrameRate }
            if #available(iOS 13.0, *) {
                if multiCam && !format.isMultiCamSupported {
                    valid = false
                }
                NSLog("format: \(camResolution.width)x\(camResolution.height) multi: \(format.isMultiCamSupported)")
            }
            return valid
        }
        return supported
    }
    
    private static func checkMulticam(backCamera: AVCaptureDevice?, frontCamera: AVCaptureDevice?) -> Bool {
        guard #available(iOS 13.0, *) else {
            return false
        }
        
        guard  let backCamera = backCamera, let frontCamera = frontCamera else {
            return false
        }

        let discovery = AVCaptureDevice.DiscoverySession.init(deviceTypes: [backCamera.deviceType, frontCamera.deviceType], mediaType: .video, position: .unspecified)
        let multicam = discovery.supportedMultiCamDeviceSets
        let supported = multicam.contains { (devices) -> Bool in
            devices.contains(frontCamera) && devices.contains(backCamera)
        }
        return supported
    }

    
    public static func getDefaultBackCamera(videoSize: CMVideoDimensions, fps: Double, isMultCam: Bool = false) -> AVCaptureDevice? {
        var camera: AVCaptureDevice?

        if #available(iOS 13.0, *) {
            camera = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
            if let tripleCamera = camera, probeCam(camera: tripleCamera, videoSize: videoSize, fps: fps, multiCam: isMultCam) == true {
                return tripleCamera
            }
            camera = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            if let dualCamera = camera, probeCam(camera: dualCamera, videoSize: videoSize, fps: fps, multiCam: isMultCam) == true {
                return dualCamera
            }
        }
        camera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
        if let dualCamera = camera, probeCam(camera: dualCamera, videoSize: videoSize, fps: fps, multiCam: isMultCam) == true {
            return dualCamera
        }
        camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        return camera
    }
    

    
    public static func getDefaultFrontCamera() -> AVCaptureDevice? {
        let defaultType = AVCaptureDevice.DeviceType.builtInWideAngleCamera
        return  AVCaptureDevice.default(defaultType, for: .video, position: .front)

    }

    
}
