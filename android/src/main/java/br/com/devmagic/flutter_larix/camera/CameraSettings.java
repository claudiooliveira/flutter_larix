package br.com.devmagic.flutter_larix.camera;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;

import com.wmspanel.libstream.Streamer;

import java.util.List;

public class CameraSettings {
    private static final String TAG = "CameraSettings";

    public static final int API_CAMERA = 1;
    public static final int API_CAMERA2 = 2;



    public static CameraInfo getActiveCameraInfo(final Context context,String cameraId,
                                                 final List<CameraInfo> cameraList) {
        if (cameraList == null || cameraList.size() == 0) {
            Log.e(TAG, "no camera found");
            return null;
        }

        if (DeepLink.getInstance().hasImportedActiveCamera()) {
            final CameraInfo info = DeepLink.getInstance().getActiveCameraInfo(context, cameraList);
            if (info != null) {
                return info;
            }
        }


        CameraInfo cameraInfo = CameraListHelper.findById(cameraId, cameraList);
        if (cameraInfo == null) {
            cameraInfo = cameraList.get(0);
        }
        return cameraInfo;
    }

    public static Streamer.Size getVideoSize(final Context context,
                                             final CameraInfo cameraInfo) {

        Streamer.Size videoSize = null;

        if ( 0 >= cameraInfo.recordSizes.size()) {
            videoSize = cameraInfo.recordSizes.get(0);
        }
        // Reduce 4K to FullHD, because some encoders can fail with 4K frame size.
        // https://source.android.com/compatibility/android-cdd.html#5_2_video_encoding
        // Video resolution: 320x240px, 720x480px, 1280x720px, 1920x1080px.
        // If no FullHD support found, leave video size as is.
        if (videoSize != null && videoSize.width > 1280 || videoSize.height > 720) {
            int newIndex = 0;
            for (Streamer.Size size : cameraInfo.recordSizes) {
                if (size.width == 1920 && (size.height == 1080 || size.height == 1088)) {
                    videoSize = size;
                    break;
                }
                newIndex++;
            }
        }
        return videoSize;
    }




}