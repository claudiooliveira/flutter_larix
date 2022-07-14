package com.wmspanel.libcommon;

import com.wmspanel.libstream.RistStats;
import com.wmspanel.libstream.SrtStats;
import com.wmspanel.libstream.Streamer;
import com.wmspanel.libstream.TcpStats;

public final class ConnectionStatistics {
    private long startTime;
    private long prevTime;
    private long prevBytes;
    private long duration;
    private long bps;
    private long videoSkipped;
    private long audioSkipped;
    private long pktSndDrop;
    private boolean dataLossIncreased;

    public long getBandwidth() {
        return bps;
    }

    public long getDuration() {
        return duration;
    }

    public long getTraffic() {
        return prevBytes;
    }

    public boolean isDataLossIncreasing() {
        return dataLossIncreased;
    }

    public void init() {
        long time = System.currentTimeMillis();
        startTime = time;
        prevTime = time;
    }

    public void update(final Streamer streamer, final int connectionId) {
        if (streamer == null) {
            return;
        }

        final TcpStats tcpStats = streamer.getTcpStats(connectionId);
        final SrtStats srtStats = streamer.getSrtStats(connectionId);
        final RistStats ristStats = streamer.getRistStats(connectionId);

        long bytesSent = 0;
        dataLossIncreased = false;

        if (tcpStats != null) {
            bytesSent = tcpStats.bytesSent;
            if (audioSkipped != tcpStats.audioFramesSkipped ||
                    videoSkipped != tcpStats.videoFramesSkipped) {
                audioSkipped = tcpStats.audioFramesSkipped;
                videoSkipped = tcpStats.videoFramesSkipped;
                dataLossIncreased = true;
            }
        } else if (srtStats != null) {
            bytesSent = srtStats.byteSentUnique - srtStats.pktSentUnique * 44; // Subtract UDT/SRT header size
            if (pktSndDrop != srtStats.pktSndDrop) {
                pktSndDrop = srtStats.pktSndDrop;
                dataLossIncreased = true;
            }
        } else if (ristStats != null) {
            bytesSent = ristStats.sent * 1316;
            if (ristStats.sent > 100 && ristStats.quality < 90) {
                dataLossIncreased = true;
            }
        }

        final long curTime = System.currentTimeMillis();
        final long timeDiff = curTime - prevTime;
        if (timeDiff > 0) {
            bps = 8 * 1000 * (bytesSent - prevBytes) / timeDiff;
        } else {
            bps = 0;
        }
        prevTime = curTime;
        prevBytes = bytesSent;
        duration = (curTime - startTime) / 1000L;
    }

}
