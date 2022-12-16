package br.com.devmagic.flutter_larix.libcommon;

import android.annotation.TargetApi;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.media.MediaFormat;
import android.os.Build;

import com.wmspanel.libstream.Streamer;

public class MediaCodecUtils {

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    public static MediaCodecInfo selectCodec(final String mimeType) {
        final MediaCodecList mediaCodecList = new MediaCodecList(MediaCodecList.REGULAR_CODECS);
        for (MediaCodecInfo codecInfo : mediaCodecList.getCodecInfos()) {
            if (!codecInfo.isEncoder()) {
                continue;
            }
            for (String type : codecInfo.getSupportedTypes()) {
                if (type.equalsIgnoreCase(mimeType)) {
                    return codecInfo;
                }
            }
        }
        return null;
    }

    public static Streamer.Size verifyResolution(final String type,
                                                 final Streamer.Size videoSize) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            final MediaCodecInfo info = MediaCodecUtils.selectCodec(type);
            final MediaCodecInfo.CodecCapabilities capabilities = info.getCapabilitiesForType(type);
            final MediaCodecInfo.VideoCapabilities videoCapabilities = capabilities.getVideoCapabilities();
            if (!videoCapabilities.isSizeSupported(videoSize.width, videoSize.height)) {
                // 1280x720 should be supported by every device running Android 4.1+
                // https://source.android.com/compatibility/4.1/android-4.1-cdd.pdf [chapter 5.2]
                return new Streamer.Size(1280, 720);
            }
        }
        return videoSize;
    }

    public static int recommendedBitrateKbps(final String type,
                                             final int height,
                                             final float fps) {
        int bitRate;
        if (height > 1088) {
            bitRate = 4500; // 2160p
        } else if (height > 720) {
            bitRate = 3000; // 1080p
        } else if (height > 540) {
            bitRate = 2000; // 720p
        } else if (height > 480) {
            bitRate = 1500; // 540p
        } else if (height > 360) {
            bitRate = 1000; // 480p
        } else if (height > 288) {
            bitRate = 700; // 360p
        } else if (height > 144) {
            bitRate = 500; // 280p
        } else {
            bitRate = 300; // 144p
        }
        // HEVC promises a 50% storage reduction as its algorithm uses efficient coding by encoding
        // video at the lowest possible bit rate while maintaining a high image quality level.
        if (MediaFormat.MIMETYPE_VIDEO_HEVC.equals(type)) {
            bitRate /= 2;
        }
        // Set bitrate to 1.6x for 50+ FPS modes
        if (fps > 49.0) {
            bitRate = bitRate * 16 / 10;
        }
        return bitRate;
    }

}
