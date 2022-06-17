import Foundation
import AVFoundation


/**
Statistics for connection
 
 */
public class ConnectionStatistics {
    /// true for UDP-baset streams (SRT/RIST), false for RTMP/RTSP
    public var isUdp: Bool = false
    
    ///Stream start time
    var startTime: CFTimeInterval = CACurrentMediaTime()
    ///Last statistics update time
    var prevTime: CFTimeInterval = CACurrentMediaTime()
    /// Connection duration
    public var duration: CFTimeInterval = 0
    /// Number of bytes sent for UDP or queued to be sent for TCP
    public var prevBytesSent: UInt64 = 0
    /// Number of bytes sent
    public var prevBytesDelivered: UInt64 = 0
    ///Calculated bitrate (in bits per second)
    public var bps: Double = 0
    ///Calculated latency (number of bytes unsent divied by bitrate)
    public var latency: Double = 0
    /// Number of packets lost (for SRT/RIST)
    public var packetsLost: UInt64 = 0

    //Duraton in h:mm:ss format
    public var durationStr: String {
        return Self.timeToString(time: Int(duration))
    }
    
    //Traffic with KB/Mb/Gb suffix
    public var trafficStr: String {
        return Self.trafficToString(bytes: prevBytesDelivered)
    }
    
    //Bandwidth with Kbps/Mbps/Gbps suffix
    public var bandwidthStr: String {
        return Self.bandwidthToString(bps: bps)
    }
    
    public static func timeToString(time: Int) -> String {
        let sec = Int(time % 60)
        let min = Int((time / 60) % 60)
        let hrs = Int(time / 3600)
        let str = String.localizedStringWithFormat(NSLocalizedString("%02d:%02d:%02d", comment: ""), hrs, min, sec)
        return str
    }
    
    public static func trafficToString(bytes: UInt64) -> String {
        if bytes < 1024 {
            // b
            return String.localizedStringWithFormat(NSLocalizedString("%4dB", comment: ""), bytes)
        } else if bytes < 1024 * 1024 {
            // Kb
            return String.localizedStringWithFormat(NSLocalizedString("%3.1fKB", comment: ""), Double(bytes) / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            // Mb
            return String.localizedStringWithFormat(NSLocalizedString("%3.1fMB", comment: ""), Double(bytes) / (1024 * 1024))
        } else {
            // Gb
            return String.localizedStringWithFormat(NSLocalizedString("%3.1fGB", comment: ""), Double(bytes) / (1024 * 1024 * 1024))
        }
    }
    
    public static func bandwidthToString(bps: Double) -> String {
        if bps < 1000 {
            // b
            return String.localizedStringWithFormat(NSLocalizedString("%4dbps", comment: ""), Int(bps))
        } else if bps < 1000 * 1000 {
            // Kb
            return String.localizedStringWithFormat(NSLocalizedString("%3.1fKbps", comment: ""), bps / 1000)
        } else if bps < 1000 * 1000 * 1000 {
            // Mb
            return String.localizedStringWithFormat(NSLocalizedString("%3.1fMbps", comment: ""), bps / (1000 * 1000))
        } else {
            // Gb
            return String.localizedStringWithFormat(NSLocalizedString("%3.1fGbps", comment: ""), bps / (1000 * 1000 * 1000))
        }
    }
    
}
