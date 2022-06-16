import Foundation
import AVKit
import Photos
import LarixSupport


@objc public enum PermissionCheckItem: Int {
    case camera = 1
    case microphone = 2
    case photoLibrary = 4 //Photo Library is requested, but deviceAuthorized doesn't count it (check photoLibStatus to determine status)
}

@objc public protocol PermissionCheckerDelegate: AnyObject {
    func permissionsGranted()
    func permissionsMissing(_ item: PermissionCheckItem)
}

public class PermissionChecker: NSObject {
    private var items: Set<PermissionCheckItem> = [PermissionCheckItem.camera, PermissionCheckItem.microphone]
    private var delegate: PermissionCheckerDelegate? = nil
    private var checkInProgress: Bool = false
    
    @objc override public init() {
        super.init()
        self.items = [PermissionCheckItem.camera, PermissionCheckItem.microphone]
    }
    
    @objc public init(mode: Int) {
        super.init()
        var items: Set<PermissionCheckItem> = []
        if (mode & PermissionCheckItem.camera.rawValue) != 0 {
            items.insert(.camera)
        } else {
            cameraAuthorized = true
        }
        if (mode & PermissionCheckItem.microphone.rawValue) != 0 {
            items.insert(.microphone)
        } else {
            micAuthorized = true
        }
        if (mode & PermissionCheckItem.photoLibrary.rawValue) != 0 {
            items.insert(.photoLibrary)
        } else {
            photoLibStatus = .authorized
        }

        self.items = items
    }
    
    public init(_ items: Set<PermissionCheckItem>) {
        super.init()
        self.items = items

        if !self.items.contains(.camera) {
            cameraAuthorized = true
        }
        if !self.items.contains(.microphone) {
            micAuthorized = true
        }
        if !self.items.contains(.photoLibrary) {
            photoLibStatus = .authorized
        }

    }
    
    @objc public func setDelegate(_ delegate: PermissionCheckerDelegate?) {
        self.delegate = delegate
    }
    
    var cameraAuthorized: Bool = false {
        // Swift has a simple and classy solution called property observers, and it lets you execute code whenever a property has changed. To make them work, you need to declare your data type explicitly (in our case we need an Bool), then use either didSet to execute code when a property has just been set, or willSet to execute code before a property has been set.
        didSet {
            if cameraAuthorized {
                self.checkMic()
            } else {
                checkResult(false)
            }
        }
    }
    var micAuthorized: Bool = false {
        didSet {
            if micAuthorized {
                self.checkPhotoLibrary()
            } else {
                checkResult(false)
            }
        }
    }
    
    public var deviceAuthorized: Bool {
        return cameraAuthorized && micAuthorized
    }

    public var photoLibStatus: PHAuthorizationStatus = .notDetermined


    //Check for camera and microphone authoization. In case of sucess onGranted will be called
    @objc public func check() {
        if checkInProgress {
            LogWarn("Permission check already started")
            return
        }
        checkInProgress = true
        if deviceAuthorized {
            checkResult(true)
            return
        }
        let status: AVAuthorizationStatus = cameraAuthorized ? .authorized:  AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        
        switch (status) {
        case AVAuthorizationStatus.authorized:
            cameraAuthorized = true
        case AVAuthorizationStatus.notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: {
                self.cameraAuthorized = $0
            })
        default:
            cameraAuthorized = false
        }
    }
    
    private func checkMic() {
        
        let status: AVAuthorizationStatus = micAuthorized ? .authorized:  AVCaptureDevice.authorizationStatus(for: AVMediaType.audio)

        switch (status) {
        case AVAuthorizationStatus.authorized:
            micAuthorized = true
        case AVAuthorizationStatus.notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: {
                self.micAuthorized = $0
            })
        default:
            micAuthorized = false
        }
    }
    
    private func checkPhotoLibrary() {
        if photoLibStatus == .notDetermined {
            if #available(iOS 14, *) {
                photoLibStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            } else {
                photoLibStatus = PHPhotoLibrary.authorizationStatus()
            }
        }
        if photoLibStatus == .notDetermined {
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { self.updatePhotoLibStatus($0) }
            } else {
                PHPhotoLibrary.requestAuthorization()  { self.updatePhotoLibStatus($0) }
            }
        } else {
            checkResult(deviceAuthorized)
        }
    }
    
    private func updatePhotoLibStatus(_ status: PHAuthorizationStatus) {
        self.photoLibStatus = status
        self.checkResult(self.deviceAuthorized)
    }
        
    
    private func checkResult(_ allowed: Bool) {
        DispatchQueue.main.async { [weak self] in
            if allowed {
                self?.delegate?.permissionsGranted()
            } else {
                if self?.cameraAuthorized == false {
                    self?.delegate?.permissionsMissing(.camera)
                } else if self?.micAuthorized == false {
                    self?.delegate?.permissionsMissing(.microphone)
                }
            }
            self?.checkInProgress = false
        }
    }
}
