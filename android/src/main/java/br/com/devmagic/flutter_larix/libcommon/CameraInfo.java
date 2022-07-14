package com.wmspanel.libcommon;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.wmspanel.libstream.Streamer;

import java.util.ArrayList;
import java.util.List;

public final class CameraInfo {
    public static final int LENS_FACING_FRONT = 0;
    public static final int LENS_FACING_BACK = 1;
    public static final int LENS_FACING_EXTERNAL = 2;

    public String cameraId;
    public final List<Streamer.Size> recordSizes = new ArrayList<>();
    public int lensFacing;
    public final List<Streamer.FpsRange> fpsRanges = new ArrayList<>();
    public int minExposure;
    public int maxExposure;
    public float exposureStep;
    public List<CameraInfo> physicalCameras = new ArrayList<>();
    public float fov;
    public boolean isZoomSupported;
    public float maxZoom = 1.0f;
    public boolean isTorchSupported;
    public float minimumFocusDistance;

    @NonNull
    @Override
    public String toString() {
        final StringBuilder sb = new StringBuilder(1024);

        sb.append("cameraId=").append(cameraId);

        switch (lensFacing) {
            case LENS_FACING_FRONT:
                sb.append(" (FRONT)");
                break;
            case LENS_FACING_BACK:
                sb.append(" (BACK)");
                break;
            case LENS_FACING_EXTERNAL:
                sb.append(" (EXTERNAL)");
                break;
            default:
                break;
        }

        sb.append(", isMultiCamera=").append(physicalCameras.size() > 0).append(";");

        sb.append("\nrecordSizes=");
        for (Streamer.Size size : recordSizes) {
            sb.append(size).append(";");
        }

        sb.append("\nfpsRanges=");
        for (Streamer.FpsRange range : fpsRanges) {
            sb.append(range).append(";");
        }

        sb.append("\nexposure=(").append(minExposure).append("..").append(maxExposure).append(");")
                .append("step=").append(exposureStep).append(";");

        sb.append("\nfov=").append(fov).append(";");

        sb.append("\nisZoomSupported=").append(isZoomSupported)
                .append(", maxZoom=").append(maxZoom).append(";");

        sb.append("\nminimumFocusDistance=").append(minimumFocusDistance).append(";");

        return sb.toString();
    }

    @Nullable
    public Streamer.FpsRange findFpsRange(final Streamer.FpsRange targetRange) {
        if (targetRange == null || fpsRanges.size() < 2) {
            // old devices usually provide single fps range per camera
            // so app don't need to set it explicitly
            return null;
        }
        for (Streamer.FpsRange range : fpsRanges) {
            if (range.equals(targetRange)) {
                return range;
            }
        }
        // sometimes front camera's ranges set doesn't match back camera's ranges set
        // use default fps range
        return null;
    }

    // Find best matching FPS range
    // (fpsMax is much important to be closer to target, so we squared it)
    // In strict mode targetFps will be exact within range, otherwise just as close as possible
    @Nullable
    public Streamer.FpsRange findNearestFpsRange(final float targetFps,
                                                 final boolean strict) {
        // Find best matching FPS range
        // (fpsMax is much important to be closer to target, so we squared it)
        float minDistance = 1e10f;
        Streamer.FpsRange range = null;
        for (Streamer.FpsRange r : fpsRanges) {
            if (strict && (r.fpsMin > targetFps || r.fpsMax < targetFps)) {
                continue;
            }
            float distance = ((r.fpsMax - targetFps) * (r.fpsMax - targetFps) + Math.abs(r.fpsMin - targetFps));
            if (distance < minDistance) {
                range = r;
                if (distance < 0.01f) {
                    break;
                }
                minDistance = distance;
            }
        }
        return range;
    }

    // Set the same video size for both cameras
    // If not possible (for example front camera has no FullHD support)
    // try to find video size with the same aspect ratio
    @NonNull
    public Streamer.Size findVideoSize(final Streamer.Size targetSize) {
        Streamer.Size supportedSize = null;

        // If secondary camera supports same resolution, use it
        for (Streamer.Size size : recordSizes) {
            if (size.equals(targetSize)) {
                supportedSize = size;
                break;
            }
        }

        // If same resolution not found, search for same aspect ratio
        if (supportedSize == null) {
            final double targetAspectRatio = (double) targetSize.width / targetSize.height;
            for (Streamer.Size size : recordSizes) {
                if (size.width < targetSize.width) {
                    final double aspectRatio = (double) size.width / size.height;
                    final double aspectDiff = targetAspectRatio / aspectRatio - 1;
                    if (Math.abs(aspectDiff) < 0.01) {
                        supportedSize = size;
                        break;
                    }
                }
            }
        }

        // Same aspect ratio not found, search for less or similar frame sides
        if (supportedSize == null) {
            for (Streamer.Size size : recordSizes) {
                if (size.height <= targetSize.height && size.width <= targetSize.width) {
                    supportedSize = size;
                    break;
                }
            }
        }

        // Nothing found, use default
        if (supportedSize == null) {
            supportedSize = recordSizes.get(0);
        }

        return supportedSize;
    }

}
