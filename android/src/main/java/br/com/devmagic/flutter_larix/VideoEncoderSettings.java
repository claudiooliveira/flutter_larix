package br.com.devmagic.flutter_larix;


import android.annotation.TargetApi;
import android.content.Context;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.os.Build;

import com.wmspanel.libstream.Streamer;
import com.wmspanel.libstream.VideoConfig;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import br.com.devmagic.flutter_larix.libcommon.MediaCodecUtils;

public class VideoEncoderSettings {

    public static final Map<Integer, String> AVC_PROFILES = createAvcProfilesMap();

    private static Map<Integer, String> createAvcProfilesMap() {
        final Map<Integer, String> result = new HashMap<>();
        result.put(MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline, "Baseline");
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.O) {
            result.put(MediaCodecInfo.CodecProfileLevel.AVCProfileConstrainedBaseline, "Constrained Baseline");
            result.put(MediaCodecInfo.CodecProfileLevel.AVCProfileConstrainedHigh, "Constrained High");
        }
        result.put(MediaCodecInfo.CodecProfileLevel.AVCProfileExtended, "Extended");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCProfileHigh, "High");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCProfileHigh10, "High 10");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCProfileHigh422, "High 4:2:2");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCProfileHigh444, "High 4:4:4");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCProfileMain, "Main");
        return Collections.unmodifiableMap(result);
    }

    public static final Map<Integer, String> AVC_LEVELS = createAvcLevelsMap();

    private static Map<Integer, String> createAvcLevelsMap() {
        final Map<Integer, String> result = new HashMap<>();
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel1, "Level1");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel1b, "Level1b");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel11, "Level11");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel12, "Level12");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel13, "Level13");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel2, "Level2");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel21, "Level21");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel22, "Level22");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel3, "Level3");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel31, "Level31");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel32, "Level32");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel4, "Level4");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel41, "Level41");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel42, "Level42");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel5, "Level5");
        result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel51, "Level51");
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.KITKAT_WATCH) {
            result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel52, "Level52");
        }
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.P) {
            result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel6, "Level6");
            result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel61, "Level61");
            result.put(MediaCodecInfo.CodecProfileLevel.AVCLevel62, "Level62");
        }
        return Collections.unmodifiableMap(result);
    }

    public static final Map<Integer, String> HEVC_PROFILES = createHevcProfilesMap();

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    private static Map<Integer, String> createHevcProfilesMap() {
        final Map<Integer, String> result = new HashMap<>();
        result.put(MediaCodecInfo.CodecProfileLevel.HEVCProfileMain, "Main");
        result.put(MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10, "Main 10");
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10, "Main 10 HDR 10");
        }
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.P) {
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10Plus, "Main 10 HDR 10 Plus");
        }
        return Collections.unmodifiableMap(result);
    }

    public static final Map<Integer, String> HEVC_LEVELS = createHevcLevelsMap();

    private static Map<Integer, String> createHevcLevelsMap() {
        final Map<Integer, String> result = new HashMap<>();
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.KITKAT_WATCH) {
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel1, "MainTierLevel1");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel1, "HighTierLevel1");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel2, "MainTierLevel2");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel2, "HighTierLevel2");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel21, "MainTierLevel21");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel21, "HighTierLevel21");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel3, "MainTierLevel3");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel3, "HighTierLevel3");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel31, "MainTierLevel31");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel31, "HighTierLevel31");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel4, "MainTierLevel4");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel4, "HighTierLevel4");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel41, "MainTierLevel41");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel41, "HighTierLevel41");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel5, "MainTierLevel5");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel5, "HighTierLevel5");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel51, "MainTierLevel51");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel51, "HighTierLevel51");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel52, "MainTierLevel52");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel52, "HighTierLevel52");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel6, "MainTierLevel6");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel6, "HighTierLevel6");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel61, "MainTierLevel61");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel61, "HighTierLevel61");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel62, "MainTierLevel62");
            result.put(MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel62, "HighTierLevel62");
        }
        return Collections.unmodifiableMap(result);
    }

    public static VideoConfig newVideoConfig(final Context context,
                                             final Streamer.Size videoSize,
                                             final float fps) {

        final VideoConfig config = new VideoConfig();

        // This is for old Google Nexus 6P (2015) and Google Pixel (2016) devices only
        // Don't set this in your production app
        config.discardCameraTimestamp = false;

        // "video/avc" or "video/hevc"
        config.type = mimeType(context);

        config.videoSize = MediaCodecUtils.verifyResolution(config.type, videoSize);

        // https://developer.android.com/reference/android/media/MediaFormat.html#KEY_FRAME_RATE
        config.fps = fps;

        // https://developer.android.com/reference/android/media/MediaFormat.html#KEY_I_FRAME_INTERVAL
        config.keyFrameInterval = keyFrameInterval(context);

        // http://developer.android.com/reference/android/media/MediaFormat.html#KEY_PROFILE
        // http://developer.android.com/reference/android/media/MediaFormat.html#KEY_LEVEL
        config.profileLevel = profileLevel(context, config.type);

        // https://developer.android.com/reference/android/media/MediaFormat.html#KEY_BIT_RATE
        config.bitRate = bitRate(context, config);

        // https://developer.android.com/reference/android/media/MediaFormat#KEY_BITRATE_MODE
        config.bitRateMode = bitRateMode(context, config.type);

        return config;
    }

    public static String codecDisplayName(final String mimeType) {
        switch (mimeType) {
            case MediaFormat.MIMETYPE_VIDEO_AVC:
                return "H.264";
            case MediaFormat.MIMETYPE_VIDEO_HEVC:
                return "HEVC";
            default:
                return mimeType;
        }
    }


    public static int keyFrameInterval(final Context context) {
        //return Settings.parseIntSafe(context, R.string.key_frame_interval_key, R.string.key_frame_interval_default);
        return 2000;
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    public static MediaCodecInfo.CodecProfileLevel profileLevel(final Context context,
                                                                final String mimeType) {
        // http://developer.android.com/reference/android/media/MediaFormat.html#KEY_PROFILE
        // http://developer.android.com/reference/android/media/MediaFormat.html#KEY_LEVEL
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return null;
        }

//        MediaCodecInfo.CodecProfileLevel test = new MediaCodecInfo.CodecProfileLevel();
//        test.profile = MediaCodecInfo.CodecProfileLevel.AVCProfileHigh;
//        test.level = MediaCodecInfo.CodecProfileLevel.AVCLevel31;
//        return test;

//        final String key = (MediaFormat.MIMETYPE_VIDEO_HEVC.equals(mimeType)) ?
//                context.getString(R.string.hevc_codec_profile_key) : context.getString(R.string.avc_codec_profile_key);
//        final String systemDefault = context.getString(R.string.option_value_none);
//        final SharedPreferences sp = PreferenceManager.getDefaultSharedPreferences(context);
//        final String value = sp.getString(key, systemDefault);
//
//        if (systemDefault.equals(value)) {
//            return null;
//        }

        try {
            final int profile = MediaCodecInfo.CodecProfileLevel.AVCLevel1;
            final MediaCodecInfo info = MediaCodecUtils.selectCodec(mimeType);
            if (info != null) {
                final MediaCodecInfo.CodecCapabilities capabilities = info.getCapabilitiesForType(mimeType);
                for (MediaCodecInfo.CodecProfileLevel profileLevel : capabilities.profileLevels) {
                    if (profileLevel.profile == profile) {
                        return profileLevel;
                    }
                }
                throw new NumberFormatException();
            }
        } catch (NumberFormatException e) {
            //sp.edit().remove(key).apply();
        }
        return null;
    }

    public static int bitRate(final Context context, final VideoConfig config) {
        final int pixels = Math.min(config.videoSize.width, config.videoSize.height);
        int bitRate = MediaCodecUtils.recommendedBitrateKbps(config.type, pixels, config.fps);
        //Log.d(TAG, "video_bitrate=" + bitRate);
        return bitRate * 1000; // Kbps -> bps
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    public static int bitRateMode(Context context, final String mimeType) {
        // https://developer.android.com/reference/android/media/MediaFormat#KEY_BITRATE_MODE
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return -1;
        }

//        final String key = context.getString(R.string.video_bitrate_mode_key);
//        final String systemDefault = context.getString(R.string.option_value_none);
//        final SharedPreferences sp = PreferenceManager.getDefaultSharedPreferences(context);
//        final String value = sp.getString(key, systemDefault);
//
//        if (systemDefault.equals(value)) {
//            return -1;
//        }

        try {
            final int bitrateMode = MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CQ;//Integer.parseInt(value);
            final MediaCodecInfo info = MediaCodecUtils.selectCodec(mimeType);
            if (info != null) {
                final MediaCodecInfo.CodecCapabilities capabilities = info.getCapabilitiesForType(mimeType);
                final MediaCodecInfo.EncoderCapabilities encoderCapabilities = capabilities.getEncoderCapabilities();
                if (encoderCapabilities.isBitrateModeSupported(bitrateMode)) {
                    return bitrateMode;
                }
                throw new NumberFormatException();
            }
        } catch (NumberFormatException e) {
            //sp.edit().remove(key).apply();
        }
        return -1;
    }

    public static String mimeType(final Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return MediaFormat.MIMETYPE_VIDEO_AVC;
        }

//        final SharedPreferences sp = PreferenceManager.getDefaultSharedPreferences(context);
//        final String value = sp.getString(context.getString(R.string.video_codec_key), MediaFormat.MIMETYPE_VIDEO_AVC);
//
//        if (!MediaFormat.MIMETYPE_VIDEO_AVC.equals(value) && !MediaFormat.MIMETYPE_VIDEO_HEVC.equals(value)) {
//            sp.edit().remove(context.getString(R.string.video_codec_key)).commit();
//            return MediaFormat.MIMETYPE_VIDEO_AVC;
//        }
//
//        if (MediaFormat.MIMETYPE_VIDEO_HEVC.equals(value)) {
//            final MediaCodecInfo info = MediaCodecUtils.selectCodec(MediaFormat.MIMETYPE_VIDEO_HEVC);
//            if (info != null) {
//                return MediaFormat.MIMETYPE_VIDEO_HEVC;
//            }
//        }
        return MediaFormat.MIMETYPE_VIDEO_AVC;
    }

}
