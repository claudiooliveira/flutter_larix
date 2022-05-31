package br.com.devmagic.flutter_larix.camera;

import android.annotation.TargetApi;
import android.content.Context;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CameraMetadata;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.wmspanel.libstream.Streamer;

import java.util.List;
import java.util.Optional;

abstract public class CameraRegistry {
    private static final String TAG = "CameraRegistry";

    // Please note: you can't use only Camera, because even if Camera api still
    // works on new devices, it is better to use modern Camera2 api if possible.
    // For example, Nexus 5X must use Camera2:
    // http://www.theverge.com/2015/11/9/9696774/google-nexus-5x-upside-down-camera
    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    public static boolean allowCamera2Support(final Context context) {

        final String manufacturer = Build.MANUFACTURER;
        final String model = Build.MODEL;

        Log.d(TAG, manufacturer + " " + model);

        // Some known camera api dependencies and issues:

        // Moto X Pure Edition, Android 6.0; Screen freeze reported with Camera2
        if (manufacturer.equalsIgnoreCase("motorola") && model.equalsIgnoreCase("clark_retus")) {
            return false;
        }

        /*
         LEGACY Camera2 implementation has problem with aspect ratio.
         Rather than allowing Camera2 API on all Android 5+ devices, we restrict it to
         cases where all cameras have at least LIMITED support.
         (E.g., Nexus 6 has FULL support on back camera, LIMITED support on front camera.)
         For now, devices with only LEGACY support should still use Camera API.
        */
        boolean result = true;
        final CameraManager manager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
        try {
            for (String cameraId : manager.getCameraIdList()) {
                final CameraCharacteristics characteristics = manager.getCameraCharacteristics(cameraId);
                final int support = safeGetInt(characteristics,
                        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL,
                        CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED);

                switch (support) {
                    case CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY:
                        Log.d(TAG, "Camera " + cameraId + " has LEGACY Camera2 support");
                        break;
                    case CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED:
                        Log.d(TAG, "Camera " + cameraId + " has LIMITED Camera2 support");
                        break;
                    case CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_FULL:
                        Log.d(TAG, "Camera " + cameraId + " has FULL Camera2 support");
                        break;
                    default:
                        Log.d(TAG, "Camera " + cameraId + " has LEVEL_3 or greater Camera2 support");
                        break;
                }

                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N
                        && support == CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY) {
                    // Can't use Camera2, bul let other cameras info to log
                    result = false;
                }
            }
        } catch (CameraAccessException | IllegalArgumentException e) {
            Log.e(TAG, Log.getStackTraceString(e));
            result = false;
        }
        return result;
    }

    abstract List<CameraInfo> getCameraList(final Context context);

    abstract CameraInfo getCameraInfo(final Context context, final String cameraId);

    @NonNull
    public static List<CameraInfo> getCameraList(final Context context, final boolean camera2) {
        return getCameraRegistry(camera2).getCameraList(context);
    }

    private static CameraRegistry getCameraRegistry(final boolean camera2) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return new CameraRegistry16();
        } else {
            return camera2 ? new CameraRegistry21() : new CameraRegistry16();
        }
    }

    protected static void addDefaultResolutions(final List<Streamer.Size> recordSizes) {
        // https://source.android.com/compatibility/android-cdd#52_video_encoding
        recordSizes.add(new Streamer.Size(320, 240)); // SD (Low quality)
        recordSizes.add(new Streamer.Size(720, 480)); // SD (High quality)
        recordSizes.add(new Streamer.Size(1280, 720)); // HD 720p
        recordSizes.add(new Streamer.Size(1920, 1080)); // HD 1080p
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    protected static boolean safeGetBoolean(final CameraCharacteristics characteristics,
                                            final CameraCharacteristics.Key<Boolean> key,
                                            final boolean fallback) {
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
            return Optional.ofNullable(characteristics.get(key)).orElse(fallback);
        }
        final Boolean val = characteristics.get(key);
        return val == null ? fallback : val;
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    protected static float safeGetFloat(final CameraCharacteristics characteristics,
                                        final CameraCharacteristics.Key<Float> key,
                                        final float fallback) {
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
            return Optional.ofNullable(characteristics.get(key)).orElse(fallback);
        }
        final Float val = characteristics.get(key);
        return val == null ? fallback : val;
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    protected static int safeGetInt(final CameraCharacteristics characteristics,
                                    final CameraCharacteristics.Key<Integer> key,
                                    final int fallback) {
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
            return Optional.ofNullable(characteristics.get(key)).orElse(fallback);
        }
        final Integer val = characteristics.get(key);
        return val == null ? fallback : val;
    }

}
