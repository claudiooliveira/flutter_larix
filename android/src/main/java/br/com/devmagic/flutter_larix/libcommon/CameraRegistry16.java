package br.com.devmagic.flutter_larix.libcommon;

import android.content.Context;
import android.hardware.Camera;
import android.util.Log;

import com.wmspanel.libstream.Streamer;

import java.util.ArrayList;
import java.util.List;

public final class CameraRegistry16 extends CameraRegistry {
    private static final String TAG = "CameraRegistry16";

    @Override
    List<CameraInfo> getCameraList(final Context context) {
        final List<CameraInfo> cameraInfoList = new ArrayList<>();
        final int numberOfCameras = Camera.getNumberOfCameras();
        for (int i = 0; i < numberOfCameras; i++) {
            final CameraInfo cameraInfo = getCameraInfo(i);
            if (cameraInfo == null) {
                continue;
            }
            cameraInfoList.add(cameraInfo);
        }
        return cameraInfoList;
    }

    @Override
    CameraInfo getCameraInfo(final Context context, final String cameraIdStr) {
        return getCameraInfo(Integer.parseInt(cameraIdStr));
    }

    private CameraInfo getCameraInfo(final int cameraId) {

        CameraInfo cameraInfo;
        Camera camera = null;

        try {

            camera = Camera.open(cameraId);
            final Camera.Parameters param = camera.getParameters();

            cameraInfo = new CameraInfo();
            cameraInfo.cameraId = Integer.toString(cameraId);

            final Camera.CameraInfo info = new Camera.CameraInfo();
            Camera.getCameraInfo(cameraId, info);

            final List<Camera.Size> previewSizes = param.getSupportedPreviewSizes();
            if (null != previewSizes) {
                for (Camera.Size previewSize : previewSizes) {
                    cameraInfo.recordSizes.add(new Streamer.Size(previewSize.width, previewSize.height));
                }
            }

            if (cameraInfo.recordSizes.size() == 0) {
                addDefaultResolutions(cameraInfo.recordSizes);
            }

            final List<int[]> fpsRanges = param.getSupportedPreviewFpsRange();
            if (null != fpsRanges) {
                for (int[] fpsRange : fpsRanges) {
                    cameraInfo.fpsRanges.add(new Streamer.FpsRange(fpsRange[0], fpsRange[1]));
                }
            }

            if (info.facing == Camera.CameraInfo.CAMERA_FACING_BACK) {
                cameraInfo.lensFacing = CameraInfo.LENS_FACING_BACK;
            } else {
                cameraInfo.lensFacing = CameraInfo.LENS_FACING_FRONT;
            }

            cameraInfo.minExposure = param.getMinExposureCompensation();
            cameraInfo.maxExposure = param.getMaxExposureCompensation();
            cameraInfo.exposureStep = param.getExposureCompensationStep();

            cameraInfo.fov = param.getHorizontalViewAngle();

            cameraInfo.maxZoom = 1.0f;
            cameraInfo.isZoomSupported = param.isZoomSupported();

            if (cameraInfo.isZoomSupported) {
                final List<Integer> zoomRatios = param.getZoomRatios();
                if (zoomRatios != null) {
                    cameraInfo.maxZoom = zoomRatios.get(param.getMaxZoom()) / 100.0f;
                }
            }

            cameraInfo.isTorchSupported = false;
            final List<String> supportedFlashModes = param.getSupportedFlashModes();
            if (supportedFlashModes != null) {
                for (String flashMode : supportedFlashModes) {
                    if (flashMode.equals(Camera.Parameters.FLASH_MODE_TORCH)) {
                        cameraInfo.isTorchSupported = true;
                        break;
                    }
                }
            }

        } catch (Exception e) {
            Log.e(TAG, "failed to get camera info, cameraId=" + cameraId);
            cameraInfo = null;

        } finally {
            if (null != camera) {
                camera.release();
            }
        }
        return cameraInfo;
    }

}
