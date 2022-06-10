import AVFoundation

/**
    Audio encoding parameters
 */
public struct AudioConfig {
    /// Audio sample rate; use 0 for auto
    public var sampleRate: Double
    /// Audio channels: 1 - mono, 2 - stereo
    public var channelCount: Int
    /// Bitrate for encoded audio; 0 for auto
    public var bitrate: Int
    /// Preferred audio input; use default input when unassigned
    public var preferredInput: AVAudioSession.Port?

    /// Preferred position for built-in microphone; .unspecified will follow camera
    public var micPosition: AVCaptureDevice.Position

    public init(sampleRate: Double, channelCount: Int, bitrate: Int,
                micPosition: AVCaptureDevice.Position = .unspecified) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitrate = bitrate
        self.micPosition = micPosition
    }
    
}
