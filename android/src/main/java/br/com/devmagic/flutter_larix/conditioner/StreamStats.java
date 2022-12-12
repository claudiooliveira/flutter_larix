package br.com.devmagic.flutter_larix.conditioner;

import com.wmspanel.libstream.SrtStats;

public class StreamStats {
    private final TrafficHistory avgToSend;

    private double requiredBps;
    private double realBps;

    StreamStats(int capacity) {
        avgToSend = new TrafficHistory(capacity);
    }

    void put(SrtStats stats, long checkInterval) {
        avgToSend.put(stats.byteSentUnique - stats.pktSentUnique * 44); // Subtract UDT/SRT header size
        realBps = stats.mbpsBandwidth * 125_000;
        requiredBps = avgToSend.avg() / (checkInterval / 1000.0);
    }

    double getRequiredBps() {
        return requiredBps;
    }

    double getRealBps() {
        return realBps;
    }
}
