package br.com.devmagic.flutter_larix.camera;

import android.content.Context;
import android.util.Log;


import java.util.List;



public class DeepLink {

    private static final String TAG = "DeepLink";

    private static final int IMPORTED_CAMERA_REAR = 0;
    private static final int IMPORTED_CAMERA_FRONT = 1;

    private int mImportedCameraId = -1;

    private static DeepLink instance;


    public static DeepLink getInstance() {
        if (instance == null) {
            instance = new DeepLink();
        }
        return instance;
    }




    public boolean hasImportedActiveCamera() {
        return mImportedCameraId >= 0;
    }

    public CameraInfo getActiveCameraInfo(Context context, List<CameraInfo> cameraList) {
        CameraInfo cameraInfo = null;
        if (!hasImportedActiveCamera()) {
            return null;
        }
        if (cameraList == null || cameraList.size() == 0) {
            Log.e(TAG, "no camera found");
        } else {
            for (CameraInfo cursor : cameraList) {
                if ((mImportedCameraId == IMPORTED_CAMERA_REAR && cursor.lensFacing == CameraInfo.LENS_FACING_BACK) ||
                        (mImportedCameraId == IMPORTED_CAMERA_FRONT && cursor.lensFacing == CameraInfo.LENS_FACING_FRONT)) {
                    cameraInfo = cursor;
                    break;
                }
            }

            mImportedCameraId = -1;
            if (cameraInfo == null) {
                cameraInfo = cameraList.get(0);
            }
        }
        return cameraInfo;
    }

}
