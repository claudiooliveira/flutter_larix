import Foundation
import AVFoundation
import LarixSupport

@objc public protocol AudioSessionStateObserver {
    func mediaServicesWereLost()
    func mediaServicesWereReset()
}

/**
 AVAudioSession wrapper

 Each app running in iOS has a single audio session, which in turn has a single category. You can change your audio session’s category while your app is running.
 You can refine the configuration provided by the AVAudioSession.Category.playback, AVAudioSession.Category.record, and AVAudioSession.Category.playAndRecord categories by using an audio session mode, as described in Audio Session Modes.
 For details, see [AVAudioSession documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession)
 While AVAudioSessionCategoryRecord works for the builtin mics and other bluetooth devices it did not work with AirPods. Instead, setting the category to AVAudioSessionCategoryPlayAndRecord allows recording to work with the AirPods.

 - Important: Call AudioSession.start() prior to initialize capture session
 */
public class AudioSession: NSObject {
    
    private let session: AVAudioSession
    public var defaultMode: AVAudioSession.Mode = .videoRecording {
        didSet {
            if isActive && defaultMode != session.mode {
                do {
                    try session.setMode(defaultMode)
                } catch {
                    LogWarn("setMode failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc var isActive: Bool
    private weak static var sharedInstance: AudioSession?
    @objc public var observer: AudioSessionStateObserver?
    
    override public init() {
        session = AVAudioSession.sharedInstance()
        isActive = false
        super.init()
        if Self.sharedInstance == nil {
            Self.sharedInstance = self
        }
    }
    
    @objc public static func getInstance() -> AudioSession? {
        return sharedInstance
    }
    
    @objc public func start() {
        observeAudioSessionNotifications(true)
        activateAudioSession()
    }

    func activateAudioSession() {
        do {
            try session.setCategory(.playAndRecord, mode: defaultMode, options: [.allowBluetooth])
            try session.setActive(true)
            isActive = true
        } catch {
            isActive = false
            LogWarn("activateAudioSession: \(error.localizedDescription)")
        }
    }
    
    @objc public func stop() {
        deactivateAudioSession()
        observeAudioSessionNotifications(false)
    }
    
    private func deactivateAudioSession() {
        do {
            try session.setActive(false)
            isActive = false
        } catch {
            LogWarn("deactivateAudioSession: \(error.localizedDescription)")
        }
    }
    
    private func observeAudioSessionNotifications(_ observe:Bool) {
        let audioSession = AVAudioSession.sharedInstance()
        let center = NotificationCenter.default
        if observe {
            center.addObserver(self, selector: #selector(handleAudioSessionInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: audioSession)
            center.addObserver(self, selector: #selector(handleAudioSessionMediaServicesWereLost(notification:)), name: AVAudioSession.mediaServicesWereLostNotification, object: audioSession)
            center.addObserver(self, selector: #selector(handleAudioSessionMediaServicesWereReset(notification:)), name: AVAudioSession.mediaServicesWereResetNotification, object: audioSession)
        } else {
            center.removeObserver(self, name: AVAudioSession.interruptionNotification, object: audioSession)
            center.removeObserver(self, name: AVAudioSession.mediaServicesWereLostNotification, object: audioSession)
            center.removeObserver(self, name: AVAudioSession.mediaServicesWereResetNotification, object: audioSession)
        }
    }
    
    @objc func handleAudioSessionInterruption(notification: Notification) {
        if let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber, let interruptionType = AVAudioSession.InterruptionType(rawValue: UInt(value.intValue)) {
            switch interruptionType {
            case .began:
                deactivateAudioSession()
            case .ended:
                activateAudioSession()
            default:
                break
            }
        }
    }
    
    /** MARK: Respond to the media server crashing and restarting
     - See also: [QA1749]( https://developer.apple.com/library/archive/qa/qa1749/_index.html)
     */
    @objc func handleAudioSessionMediaServicesWereLost(notification: Notification) {
        observer?.mediaServicesWereLost()
    }
    
    @objc func handleAudioSessionMediaServicesWereReset(notification: Notification) {
        deactivateAudioSession()
        activateAudioSession()
        observer?.mediaServicesWereReset()
    }
}
