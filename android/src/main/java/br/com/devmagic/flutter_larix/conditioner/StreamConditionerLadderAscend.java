package br.com.devmagic.flutter_larix.conditioner;

import android.content.Context;

import com.wmspanel.libstream.Streamer;

class StreamConditionerLadderAscend extends StreamConditionerBase {

    private static final long NORMALIZATION_DELAY = 2_000; //Ignore lost frames during this time after bitrate change
    private static final long LOST_ESTIMATE_INTERVAL = 10_000; //Period for lost frames count
    private static final long LOST_BANDWITH_TOLERANCE_FRAC = 300_000;
    private static final double[] BANDWITH_STEPS = {0.2, 0.25, 1.0 / 3.0, 0.450, 0.600, 0.780, 1.000};
    private static final long[] RECOVERY_ATTEMPT_INTERVALS = {15_000, 60_000, 60_000 * 3};
    private static final long DROP_MERGE_INTERVAL = BANDWITH_STEPS.length * NORMALIZATION_DELAY * 2; //Period for bitrate drop duration

    private int mStep;

    @Override
    protected long checkInterval() {
        return 2000;
    }

    @Override
    protected long checkDelay() {
        return 2000;
    }

    StreamConditionerLadderAscend(Context context) {
        super(context);
    }

    @Override
    public void start(Streamer streamer, int bitrate) {
        mFullBitrate = bitrate;
        mStep = 2;
        int startBitrate = (int) Math.round(bitrate * BANDWITH_STEPS[mStep]);
        super.start(streamer, startBitrate);
        changeBitrateQuiet(startBitrate);
        if (TEST_MODE) {
            mSimulateLoss = false;
        }
    }

    @Override
    protected void check(long audioLost, long videoLost) {
        long curTime = System.currentTimeMillis();
        LossHistory prevLost = ListUtils.getLast(mLossHistory);
        BitrateHistory prevBitrate = ListUtils.getLast(mBitrateHistory);
        if (prevLost.audio != audioLost || prevLost.video != videoLost) {
            long dtChange = curTime - prevBitrate.ts;
            mLossHistory.add(new LossHistory(curTime, audioLost, videoLost));
            if (mStep == 0 || dtChange < NORMALIZATION_DELAY) {
                return;
            }
            long estimatePeriod = Math.max(prevBitrate.ts + NORMALIZATION_DELAY, curTime - LOST_ESTIMATE_INTERVAL);
            long lostTolerance = prevBitrate.bitrate / LOST_BANDWITH_TOLERANCE_FRAC;
            if (countLostForInterval(estimatePeriod) >= lostTolerance) {
                long newBitrate = Math.round(mFullBitrate * BANDWITH_STEPS[--mStep]);

                changeBitrate(newBitrate);
                if (TEST_MODE && mStep == 0) {
                    mSimulateLoss = false;
                }

            }
        } else if (prevBitrate.bitrate < mFullBitrate && canTryToRecover()) {
            long newBitrate = Math.round(mFullBitrate * BANDWITH_STEPS[++mStep]);

            changeBitrate(newBitrate);
            if (TEST_MODE && mStep == BANDWITH_STEPS.length - 1) {
                mSimulateLoss = true;
            }
        }
    }

    private boolean canTryToRecover() {
        long curTime = System.currentTimeMillis();
        int len = mBitrateHistory.size();
        int numDrops = 0;
        int numIntervals = RECOVERY_ATTEMPT_INTERVALS.length;
        long prevDropTime = 0;
        for (int i = len - 1; i > 0; i--) {
            BitrateHistory last = mBitrateHistory.get(i);
            BitrateHistory prev = mBitrateHistory.get(i - 1);
            long dt = curTime - last.ts;
            if (last.bitrate < prev.bitrate) {
                if (prevDropTime != 0 && prevDropTime - last.ts < DROP_MERGE_INTERVAL) {
                    continue;
                }
                if (dt <= RECOVERY_ATTEMPT_INTERVALS[numDrops]) {
                    return false;
                }
                numDrops++;
                prevDropTime = last.ts;
            }

            if (numDrops == numIntervals || curTime - last.ts >= RECOVERY_ATTEMPT_INTERVALS[numIntervals - 1]) {
                break;
            }
        }
        return true;
    }

}
