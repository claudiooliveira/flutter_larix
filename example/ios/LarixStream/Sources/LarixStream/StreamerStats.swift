import Foundation
import AVFoundation

public class StreamerStats {
    private var connectionStatistics: [Int32:ConnectionStatistics] = [:] // id -> ConnectionStaistics
    
    public init() {
        
    }
    
    public func addConnection(connId: Int32, isUdp: Bool) {
        let stat = ConnectionStatistics()
        stat.isUdp = isUdp
        connectionStatistics[connId] = stat
    }
    
    public func removeConnection(connId: Int32) {
        connectionStatistics.removeValue(forKey: connId)
    }
    
    public func reset(connId: Int32, streamer: Streamer) {
        guard let statistics = connectionStatistics[connId] else {
            return
        }
        let time = CACurrentMediaTime()
        statistics.startTime = time
        statistics.prevTime = time
        statistics.prevBytesDelivered = streamer.bytesDelivered(connection: connId)
        statistics.prevBytesSent = streamer.bytesSent(connection: connId)

    }
    
    public func update(connId: Int32, streamer: Streamer) {
        guard let statistics = connectionStatistics[connId] else {
            return
        }
        let curTime = CACurrentMediaTime()
        statistics.duration = curTime - statistics.prevTime
        
        let bytesDelivered = streamer.bytesDelivered(connection: connId)
        let bytesSent = streamer.bytesSent(connection: connId)
        let delta = bytesDelivered > statistics.prevBytesDelivered ? bytesDelivered - statistics.prevBytesDelivered : 0
        let deltaSent = bytesSent > statistics.prevBytesSent ? bytesSent - statistics.prevBytesSent : 0
        if !statistics.isUdp {
            if deltaSent > 0 {
                statistics.latency =  bytesSent > bytesDelivered ? Double(bytesSent - bytesDelivered) / Double(deltaSent) : 0.0
            }
        } else {
            statistics.packetsLost = streamer.udpPacketsLost(connection: connId)
        }
        let timeDiff = curTime - statistics.prevTime
        if timeDiff > 0 {
            statistics.bps = 8.0 * Double(delta) / timeDiff
        } else {
            statistics.bps = 0
        }
        
        statistics.prevTime = curTime
        statistics.prevBytesDelivered = bytesDelivered
        statistics.prevBytesSent = bytesSent
        
    }
    
    public func get(_ connId: Int32) -> ConnectionStatistics? {
        return connectionStatistics[connId]
    }

}
