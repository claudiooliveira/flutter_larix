import Foundation
import AVFoundation
import LarixSupport

extension CMVideoDimensions {
    func equals(_ other: CMVideoDimensions) -> Bool {
        return self.height == other.height && self.width == other.width
    }
}

/** Utility class for camera-related functions
 */
class CameraHelper {
    /// Apply [CameraParameters] to camera
    static func setLockedParams(camera: AVCaptureDevice, params: CameraParameters) {
        let center = params.pointOfInterest
        let locked = params.lockedParameters
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            if camera.isFocusPointOfInterestSupported {
                //DDLogVerbose("reset focusPointOfInterest")
                camera.focusPointOfInterest = center
            }
        }
        //DDLogVerbose("reset focusMode")
        let focusMode: AVCaptureDevice.FocusMode = locked.contains(.Focus) ? .autoFocus : .continuousAutoFocus
        if camera.isFocusModeSupported(focusMode) {
            camera.focusMode = focusMode
        }
        if camera.isExposurePointOfInterestSupported {
            camera.exposurePointOfInterest = center
        }
        let exposureMode: AVCaptureDevice.ExposureMode = locked.contains(.Exposure) ? .autoExpose : .continuousAutoExposure
        camera.exposureMode = exposureMode
        
        let wbMode: AVCaptureDevice.WhiteBalanceMode = locked.contains(.WhiteBalance) ? .locked : .continuousAutoWhiteBalance
        if camera.isWhiteBalanceModeSupported(wbMode) {
            camera.whiteBalanceMode = wbMode
        }
        //lockedParameters = []
    }
    
    /** Get initial zoom factor; will return 1.0 for regular camera and factor matching
     standard (wide) camera for virtual camera */
    static func getInitZoomFactor(forDevice camera: AVCaptureDevice) -> CGFloat {
        var factor: CGFloat = 1.0
        if #available(iOS 13.0, *) {
            if camera.isVirtualDevice == true {
                //Set initial zoom matching primary (wide angle) camera
                let subDevices = camera.constituentDevices
                if subDevices.count <= 1 { return 1.0 }
                let mainCameraIndex = subDevices.firstIndex { $0.deviceType == .builtInWideAngleCamera }
                guard let index = mainCameraIndex, index > 0 else { return 1.0 }
                let zoom = camera.virtualDeviceSwitchOverVideoZoomFactors[index - 1]
                let fZoom = CGFloat(truncating: zoom)
                LogInfo("Set initial zoom to \(fZoom)")
                factor = fZoom
            }
        }
        return factor
    }

    /// Get switching zoom factors for virtual camera and maximum zoom
    static func getSwitchZoomFactors(forDevice camera: AVCaptureDevice) -> [CGFloat] {
        var factors: [CGFloat] = []
        if #available(iOS 13.0, *) {
            if camera.isVirtualDevice == true {
                let zoom = camera.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0.floatValue) }
                factors.append(contentsOf: zoom)
            }
        }
        return factors
    }
    
    static func toggleFlash(camera: AVCaptureDevice) -> Bool {
        var torchOn = false
        do {
            if !(camera.hasTorch && camera.isTorchAvailable) {
                return false
            }
            torchOn = camera.torchMode != .on
            let newMode = torchOn ? AVCaptureDevice.TorchMode.on : AVCaptureDevice.TorchMode.off
            try camera.lockForConfiguration()
            camera.torchMode = newMode
            camera.unlockForConfiguration()
        } catch {
            LogError("can't set flash: \(error)")
        }
        return torchOn
    }
    
    static func setColorTemperature(camera: AVCaptureDevice, tempK: Float) -> Bool {
        var result = false
        do {
            try camera.lockForConfiguration()
            result = Self.setColorTempInternal(camera: camera, tempK: tempK)
            camera.unlockForConfiguration()
        } catch {
            LogError("can't lock video device for configuration: \(error)")
            return false
        }
        return result
    }
    
    static func setColorTempInternal(camera: AVCaptureDevice, tempK: Float) -> Bool {
        if !camera.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
            if camera.isWhiteBalanceModeSupported(.locked) {
                camera.whiteBalanceMode = .locked
            }
            return false
        }
        let gains: AVCaptureDevice.WhiteBalanceGains
        if (tempK == 0) {
            gains = camera.grayWorldDeviceWhiteBalanceGains
        } else {
            let colorTemp = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: tempK, tint: 0.0)
            gains = camera.deviceWhiteBalanceGains(for: colorTemp)
        }
        if !Self.isWbGainsValid(gains, for: camera) {
            return false
        }
        camera.setWhiteBalanceModeLocked(with: gains)
        return true
    }
    
    static func getColorTemp(camera: AVCaptureDevice) -> Float {
        let gains = camera.deviceWhiteBalanceGains
        if Self.isWbGainsValid(gains, for: camera) {
            let converted = camera.temperatureAndTintValues(for: gains)
            return round(converted.temperature / 10.0) * 10.0
        } else {
            return Consts.ColorTemperatureDefault
        }
    }
    
    static func isWbGainsValid(_ gains: AVCaptureDevice.WhiteBalanceGains, for camera: AVCaptureDevice) -> Bool {
        return gains.redGain >= 1 && gains.redGain <= camera.maxWhiteBalanceGain &&
            gains.greenGain >= 1 && gains.greenGain <= camera.maxWhiteBalanceGain &&
            gains.blueGain >= 1 && gains.blueGain <= camera.maxWhiteBalanceGain
    }
    
    
    static func setVideoStabilizationMode(connection: AVCaptureConnection, camera: AVCaptureDevice, mode: AVCaptureVideoStabilizationMode) {
        let cameraName = camera.localizedName
        if connection.isVideoStabilizationSupported, camera.activeFormat.isVideoStabilizationModeSupported(mode) {
            connection.preferredVideoStabilizationMode = mode
            LogVerbose("\(cameraName) preferred stabilization mode: \(connection.preferredVideoStabilizationMode.rawValue)")
            LogVerbose("\(cameraName) active stabilization mode: \(connection.activeVideoStabilizationMode.rawValue)")
        }
    }
    
    
    /** Find matching format for camera.
    - Parameter camera: camera to find format for
    - Parameter videoConfig: settings (resolution, fps) to can be used with format
    - Parameter validateFn: callback can be used for additional format validation
    - Parameter adjustFps: when true, may reduce videoConfig.fps if desired fps is missing
    - Returns: Camera format when found, nil otherwise
     */
    static func findFormat(camera: AVCaptureDevice,
                           videoConfig: inout VideoConfig?,
                           validateFn: ((_ format: AVCaptureDevice.Format) -> Bool)? = nil,
                           adjustFps: Bool = true) -> AVCaptureDevice.Format? {

        let fps = videoConfig?.fps ?? Consts.videoFramerateDefault
        let videoSize = videoConfig?.videoSize ?? CMVideoDimensions(width: 1920, height: 1080)
        
        let matchFormats = camera.formats.filter { format in
            if validateFn?(format) == false {
                return false
            }
            let resolution = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return resolution.equals(videoSize)
        }
        var centerStageFps = fps
        if let csFormat = Self.findCenterStageFormat(camera: camera, formats: matchFormats, fps: &centerStageFps, adjustFps: adjustFps) {
            videoConfig?.fps = centerStageFps
            return csFormat
        }
        var nearestFps: Double = 0
        var nearestFormat: AVCaptureDevice.Format?
        let matchFormat = matchFormats.first { format in
            let fmtRanges = format.videoSupportedFrameRateRanges
            let match = fmtRanges.contains(where: { $0.minFrameRate <= fps && $0.maxFrameRate >= fps })
            if match {
                return true
            }
            if adjustFps {
                for range in fmtRanges {
                    var marginFps:Double = 0.0
                    if abs(range.maxFrameRate - fps) < abs(range.minFrameRate - fps) {
                        marginFps = range.maxFrameRate
                    } else {
                        marginFps = range.minFrameRate
                    }
                    if abs(marginFps - fps) < abs(nearestFps - fps) {
                        nearestFps = marginFps
                        nearestFormat = format
                    }
                }
            }
            return false
        }
        if matchFormat == nil && nearestFps > 0 && nearestFps != fps {
            LogVerbose("Unsupported fps, reset to: \(nearestFps)")
            videoConfig?.fps = nearestFps
        }
        return matchFormat ?? nearestFormat
    }
    
    /** Find matching format supporting Center Stage
    - Parameter camera: camera to find format for
    - Parameter formats: set of camera formats to be searched
    - Parameter fps: Frame rate
    - Parameter adjustFps: when true, may reduce fps if desored fps is missing in formats
    - Returns: Camera format when found and center stage is active, nil if center stage is turned off or can't find matching format
     */
    static func findCenterStageFormat(camera: AVCaptureDevice,
                                      formats: [AVCaptureDevice.Format],
                                      fps configFps: inout Double,
                                      adjustFps: Bool = true) -> AVCaptureDevice.Format? {
        var activeFormat: AVCaptureDevice.Format? = nil
        guard #available(iOS 14.5, *) else { return nil }
        let centerStageEnabled = AVCaptureDevice.isCenterStageEnabled && camera.isCenterStageActive
        if camera.position == .back || !centerStageEnabled {
            return nil
        }
        LarixLogger.put(message: "Center Stage is enabled", severity: .info, priority: .med)
        let centerStageFormats = formats.filter(\.isCenterStageSupported)

        activeFormat = centerStageFormats.first(where: { (format) -> Bool in
            var currentFps = configFps
            if adjustFps, let maxFps = format.videoFrameRateRangeForCenterStage?.maxFrameRate, maxFps < currentFps {
                currentFps = maxFps
            }
            return format.videoSupportedFrameRateRanges.contains { (range) -> Bool in
                range.maxFrameRate >= currentFps && range.minFrameRate <= currentFps
            }
        })
        var message: String? = nil
        if activeFormat == nil {
                message = NSLocalizedString("No suitable format for Center Stage", comment: "")
            } else if let maxFps = activeFormat?.videoFrameRateRangeForCenterStage?.maxFrameRate,
                      maxFps < configFps {
                message = String.localizedStringWithFormat(NSLocalizedString("Reduced frame rate to %3.0f due to Center Stage is on", comment: ""), maxFps)
                configFps = maxFps
            }
        if let message = message {
            LarixLogger.put(message: message, severity: .warn, priority: .med)
        }
        return activeFormat
    }

}
