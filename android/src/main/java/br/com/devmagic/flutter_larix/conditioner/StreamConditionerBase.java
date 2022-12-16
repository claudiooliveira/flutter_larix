package br.com.devmagic.flutter_larix.conditioner;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import com.wmspanel.libstream.RistStats;
import com.wmspanel.libstream.SrtStats;
import com.wmspanel.libstream.Streamer;
import com.wmspanel.libstream.TcpStats;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;

import br.com.devmagic.flutter_larix.camera.CameraInfo;

public abstract class StreamConditionerBase {

    protected static final String TAG = "StreamConditioner";

    private final Handler mHandler;

    private int mSettingsBitrate;
    protected int mCurrentBitrate;
    protected int mFullBitrate;
    protected final List<LossHistory> mLossHistory = new ArrayList<>();
    protected final List<BitrateHistory> mBitrateHistory = new ArrayList<>();
    protected final Map<Integer, StreamStats> mStreamStats = new HashMap<>();
    protected double mCurrentFps;
    protected Streamer.FpsRange mCurrentRange = new Streamer.FpsRange(30, 30);
    protected final Context mContext;

    protected CameraInfo mCameraInfo;
    protected double mMaxFps = 30.0;

    private Streamer mStreamer;
    protected final Set<Integer> mConnectionId = new HashSet<>();
    private Timer mCheckTimer;

    protected final boolean TEST_MODE = false;
    protected boolean mSimulateLoss = false; // Used by test mode to simulate packet loss

    protected long checkInterval() {
        return 500;
    }

    protected long checkDelay() {
        return 1000;
    }

    abstract void check(long audioLost, long videoLost);

    StreamConditionerBase(Context context) {
        mContext = context;
        mHandler = new Handler(Looper.getMainLooper());
    }

    public static StreamConditionerBase newInstance(Context context,
                                                    int bitrate,
                                                    @NonNull CameraInfo info) {

        StreamConditionerBase conditioner = conditioner = new StreamConditionerLadderAscend(context);

        if (conditioner != null) {
            conditioner.mSettingsBitrate = bitrate;
            conditioner.setCameraInfo(info);
        }
        return conditioner;
    }

    public void start(Streamer streamer) {
        start(streamer, mSettingsBitrate);
    }

    protected void start(Streamer streamer, int bitrate) {
        mStreamer = streamer;
        final long curTime = System.currentTimeMillis();
        mLossHistory.clear();
        mLossHistory.add(new LossHistory(curTime, 0, 0));
        mBitrateHistory.clear();
        mBitrateHistory.add(new BitrateHistory(curTime, bitrate));
        mCurrentBitrate = bitrate;
        mCurrentFps = 30.0;
        runTask();
    }

    public void stop() {
        cancelTask();
        if (mFullBitrate > 0) {
            updateFps(mFullBitrate);
        }
        mCurrentBitrate = 0;
        mStreamer = null;
        mConnectionId.clear();
        mStreamStats.clear();
    }

    public void pause() {
        cancelTask();
    }

    public void resume() {
        if (mCurrentBitrate == 0) {
            return;
        }
        mCurrentBitrate = mFullBitrate;

            mMaxFps = 30.0;
            mCurrentRange = new Streamer.FpsRange(30, 30);

        mCurrentFps = mMaxFps;
        runTask();
        mStreamer.changeBitRate(mFullBitrate);
    }

    public void addConnection(int connectionId) {
        final int capacity = 5_000 / (int) checkDelay();
        mStreamStats.put(connectionId, new StreamStats(capacity));
        mConnectionId.add(connectionId);
    }

    public void removeConnection(int connectionId) {
        mConnectionId.remove(connectionId);
        mStreamStats.remove(connectionId);
    }

    public void setCameraInfo(final CameraInfo info) {

        if (mCameraInfo != null) {
            mCameraInfo = info;
        }
    }

    public int getBitrate() {
        return mCurrentBitrate;
    }

    private final Runnable mCheckNetwork = new Runnable() {
        @Override
        public void run() {

            if (mStreamer == null || mConnectionId.size() == 0) {
                return;
            }

            long audioLost = 0;
            long videoLost = 0;
            for (int id : mConnectionId) {
                final StreamStats stats = mStreamStats.get(id);
                if (stats == null) {
                    continue;
                }

                final TcpStats tcpStats = mStreamer.getTcpStats(id);
                if (tcpStats != null) {
                    audioLost += tcpStats.audioFramesSkipped;
                    videoLost += tcpStats.videoFramesSkipped;
                }

                final SrtStats srtStats = mStreamer.getSrtStats(id);
                if (srtStats != null) {
                    videoLost += srtStats.pktSndDrop;
                    stats.put(srtStats, checkInterval());
                }

                final RistStats ristStats = mStreamer.getRistStats(id);
                if (ristStats != null && ristStats.sent > 100 && ristStats.quality < 90) {
                    videoLost += 90 - ristStats.quality;
                }
            }
            if (TEST_MODE) {
                LossHistory prevLost = ListUtils.getLast(mLossHistory);
                if (mSimulateLoss) {
                    audioLost = prevLost.audio + 3;
                    videoLost = prevLost.video + 3;
                } else {
                    audioLost = prevLost.audio;
                    videoLost = prevLost.video;
                }
            }

            check(audioLost, videoLost);
        }
    };

    private void runTask() {
        if (checkDelay() == 0 || checkInterval() == 0) {
            return;
        }

        cancelTask();
        mCheckTimer = new Timer();
        mCheckTimer.schedule(new TimerTask() {
            @Override
            public void run() {
                mHandler.post(mCheckNetwork);
            }
        }, checkDelay(), checkInterval());
    }

    private void cancelTask() {
        if (mCheckTimer != null) {
            mCheckTimer.cancel();
            mCheckTimer = null;
        }

        mHandler.removeCallbacksAndMessages(null);
    }

    protected long countLostForInterval(long interval) {
        long lost = 0;
        LossHistory last = ListUtils.getLast(mLossHistory);
        for (int i = mLossHistory.size() - 1; i >= 0; i--) {
            if (mLossHistory.get(i).ts < interval) {
                LossHistory h = mLossHistory.get(i);
                lost = (last.video - h.video) + (last.audio - h.audio);
                break;
            }
        }
        return lost;
    }

    protected void changeBitrate(long newBitrate) {
        mBitrateHistory.add(new BitrateHistory(System.currentTimeMillis(), newBitrate));
        mStreamer.changeBitRate((int) newBitrate);
        mCurrentBitrate = (int) newBitrate;
    }

    protected void changeBitrateQuiet(long newBitrate) {
        mStreamer.changeBitRate((int) newBitrate);
    }

    protected void updateFps(long newBitrate) {
        if (mCameraInfo == null || mCameraInfo.fpsRanges.size() == 0) {
            return;
        }
        double bitrateRel = newBitrate * 1.0 / mFullBitrate;
        double relFps = mMaxFps;
        if (bitrateRel < 0.5) {
            relFps = Math.max(15.0, Math.floor(mMaxFps * bitrateRel * 2.0 / 5.0) * 5.0);
        }
        if (Math.abs(relFps - mCurrentFps) < 1.0) {
            return;
        }
        mCurrentFps = relFps;
        Streamer.FpsRange newRange = mCameraInfo.findNearestFpsRange(Math.round(relFps), false);
        if (newRange == null) {
            newRange = new Streamer.FpsRange(0, 0);
        }
        if (newRange.fpsMax == mCurrentRange.fpsMax && newRange.fpsMin == mCurrentRange.fpsMin) {
            return;
        }
        mStreamer.changeFpsRange(newRange);
        mCurrentRange = newRange;
    }

}
