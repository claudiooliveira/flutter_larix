package com.wmspanel.libcommon;

import android.content.Context;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.MediaCodec;
import android.os.Build;
import android.util.Log;
import android.util.Range;
import android.util.Rational;
import android.util.Size;
import android.util.SizeF;

import androidx.annotation.RequiresApi;

import com.wmspanel.libstream.Streamer;

import java.util.ArrayList;
import java.util.List;

import static java.lang.Math.atan;

@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
public final class CameraRegistry21 extends CameraRegistry {
    private static final String TAG = "CameraRegistry21";

    @Override
    List<CameraInfo> getCameraList(final Context context) {
        final List<CameraInfo> cameraList = new ArrayList<>();
        try {
            final CameraManager cameraManager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
            final String[] cameraIdList = cameraManager.getCameraIdList();
            for (String cameraId : cameraIdList) {
                final CameraInfo camera = getCameraInfo(context, cameraId);
                if (camera == null) {
                    continue;
                }
                cameraList.add(camera);
            }
        } catch (CameraAccessException e) {
            Log.e(TAG, Log.getStackTraceString(e));
        }
        return cameraList;
    }

    @Override
    CameraInfo getCameraInfo(final Context context, final String cameraId) {
        CameraInfo cameraInfo = new CameraInfo();
        cameraInfo.cameraId = cameraId;

        try {
            final CameraManager cameraManager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
            final CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraId);

            final StreamConfigurationMap map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
            if (map != null) {
                final Size[] recordSizes = map.getOutputSizes(MediaCodec.class);
                if (recordSizes != null) {
                    for (Size recordSize : recordSizes) {
                        cameraInfo.recordSizes.add(new Streamer.Size(recordSize.getWidth(), recordSize.getHeight()));
                    }
                }
            }

            if (cameraInfo.recordSizes.size() == 0) {
                addDefaultResolutions(cameraInfo.recordSizes);
            }

            final Range<Integer>[] fpsRanges = characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES);
            if (fpsRanges != null) {
                for (Range<Integer> fpsRange : fpsRanges) {
                    cameraInfo.fpsRanges.add(new Streamer.FpsRange(fpsRange.getLower(), fpsRange.getUpper()));
                }
            }

            final int lensFacing = safeGetInt(characteristics,
                    CameraCharacteristics.LENS_FACING, CameraCharacteristics.LENS_FACING_BACK);
            switch (lensFacing) {
                case CameraCharacteristics.LENS_FACING_BACK:
                    cameraInfo.lensFacing = CameraInfo.LENS_FACING_BACK;
                    break;
                case CameraCharacteristics.LENS_FACING_FRONT:
                    cameraInfo.lensFacing = CameraInfo.LENS_FACING_FRONT;
                    break;
                default:
                    cameraInfo.lensFacing = CameraInfo.LENS_FACING_EXTERNAL;
                    break;
            }

            final Range<Integer> aeRange = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE);
            if (aeRange != null) {
                cameraInfo.minExposure = aeRange.getLower();
                cameraInfo.maxExposure = aeRange.getUpper();
            }
            final Rational aeStep = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP);
            if (aeStep != null) {
                cameraInfo.exposureStep = aeStep.floatValue();
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                final int[] capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES);
                if (capabilities != null) {
                    for (int capability : capabilities) {
                        if (capability == CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA) {
                            // Prior to API level 29, all returned IDs are guaranteed to be returned by
                            // CameraManager#getCameraIdList, and can be opened directly by CameraManager#openCamera.
                            for (String physicalCameraId : characteristics.getPhysicalCameraIds()) {
                                final CameraInfo physicalCamera = getCameraInfo(context, physicalCameraId);
                                if (physicalCamera == null) {
                                    continue;
                                }
                                cameraInfo.physicalCameras.add(physicalCamera);
                            }
                            break;
                        }
                    }
                }
            }

            double angrad = 1.1f;
            final SizeF sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE);
            final float[] focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS);
            if (sensorSize != null && focalLengths != null && focalLengths.length > 0) {
                angrad = 2.0f * atan(sensorSize.getWidth() / (2.0f * focalLengths[0]));
            }
            cameraInfo.fov = (float) Math.toDegrees(angrad);

            cameraInfo.maxZoom = safeGetFloat(characteristics,
                    CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM, 1.0f);
            cameraInfo.isZoomSupported = cameraInfo.maxZoom > 1.0f;

            cameraInfo.isTorchSupported = safeGetBoolean(characteristics,
                    CameraCharacteristics.FLASH_INFO_AVAILABLE, false);

            cameraInfo.minimumFocusDistance = safeGetFloat(characteristics,
                    CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE, 0.0f);

        } catch (/*NullPointerException |*/ CameraAccessException | IllegalArgumentException e) {
            Log.e(TAG, "failed to get camera info, cameraId=" + cameraId);
            cameraInfo = null;
        }
        return cameraInfo;
    }

}
