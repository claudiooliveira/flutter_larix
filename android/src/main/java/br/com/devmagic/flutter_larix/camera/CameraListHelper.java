package br.com.devmagic.flutter_larix.camera;

import androidx.annotation.Nullable;

import java.util.List;

public class CameraListHelper {
    @Nullable
    public static CameraInfo findById(final String id, final List<CameraInfo> cameraList) {
        if (cameraList != null ) {
            for (CameraInfo info : cameraList) {
                if (info.cameraId.equals(id)) {
                    return info;
                }
            }
        }
        return null;
    }
}
