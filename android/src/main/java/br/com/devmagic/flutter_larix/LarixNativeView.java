package br.com.devmagic.flutter_larix;

import android.Manifest;
import android.content.pm.PackageManager;
import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.res.Configuration;
import android.media.MediaCodecList;
import android.media.MediaCodecInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.wmspanel.libstream.AudioConfig;
import com.wmspanel.libstream.CameraConfig;
import com.wmspanel.libstream.ConnectionConfig;
import com.wmspanel.libstream.Streamer;
import com.wmspanel.libstream.StreamerGL;
import com.wmspanel.libstream.StreamerGLBuilder;
import com.wmspanel.libstream.VideoConfig;

import org.json.JSONObject;

import br.com.devmagic.flutter_larix.camera.CameraInfo;
import br.com.devmagic.flutter_larix.camera.CameraPermissions;
import br.com.devmagic.flutter_larix.camera.CameraPermissions.PermissionsRegistry;
import br.com.devmagic.flutter_larix.camera.CameraRegistry;
import br.com.devmagic.flutter_larix.camera.CameraSettings;
import io.flutter.Log;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

class LarixNativeView implements PlatformView, Streamer.Listener, Application.ActivityLifecycleCallbacks, MethodChannel.MethodCallHandler {
    @NonNull private final LinearLayout container;

    private static final String TAG = "StreamerFragment";

    private StreamerGL mStreamerGL;
    private final PermissionsRegistry permissionsRegistry;
    private final CameraPermissions cameraPermissions;
    private List<CameraInfo> cameraList;
    private CameraInfo activeCameraInfo;
    private String mCameraId;
    private Streamer.Size mSize;
    private String mUri;
    protected boolean mIsMuted;
    private Handler mHandler;

    private Streamer.CaptureState mVideoCaptureState = Streamer.CaptureState.FAILED;
    private Streamer.CaptureState mAudioCaptureState = Streamer.CaptureState.FAILED;

    protected AspectFrameLayout mPreviewFrame;

    private SurfaceView mSurfaceView;
    private SurfaceHolder mHolder;
    @NonNull
    StreamerGLBuilder builder;
    int connectionId = 0;

    private @NonNull Context mContext;
    private @NonNull Activity activity;

    private MethodChannel methodChannel;

    LarixNativeView(BinaryMessenger messenger, PermissionsRegistry permissionsAdder, CameraPermissions cameraPermissions ,Activity activity, @NonNull Context context, int id, @Nullable Map<String, Object> creationParams) {
        mContext = context;

        this.activity = activity;
        this.cameraPermissions = cameraPermissions;
        this.permissionsRegistry = permissionsAdder;

        mCameraId = "0";

        mHandler = new Handler(Looper.getMainLooper());
        String cameraType = creationParams.get("type").toString();

        switch (cameraType) {
            case "BACK":
                mCameraId = "0";
                break;
            case "FRONT":
                mCameraId = "1";
                break;
        }

        mSize = getResolution(creationParams);
        mUri = creationParams.get("url").toString();
        FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT);
        container = new LinearLayout(context);
        container.setOrientation(LinearLayout.VERTICAL);
        container.setLayoutParams(layoutParams);

        methodChannel = new MethodChannel(messenger, "br.com.devmagic.flutter_larix/nativeview_controller");
        methodChannel.setMethodCallHandler(this);

        ViewGroup root = (ViewGroup) LayoutInflater.from(activity).inflate(R.layout.afl_surface, container, true);

        mPreviewFrame = root.findViewById(R.id.preview_afl);
        mSurfaceView = root.findViewById(R.id.surface_view);
        mSurfaceView.getHolder().addCallback(mPreviewHolderCallback);

    }

    private Streamer.Size getResolution(Map creationParams) {
        String resolution = creationParams.get("resolution").toString();
        switch (resolution) {
            case "SD":
                return new Streamer.Size(720, 480);
            case "FULLHD":
                return new Streamer.Size(1920, 1080);
            default:
                return new Streamer.Size(1280, 720);
        }
    }

    private final SurfaceHolder.Callback mPreviewHolderCallback = new SurfaceHolder.Callback() {
        @Override
        public void surfaceCreated(SurfaceHolder holder) {

            if (mHolder != null) {
                return;
            }

            mHolder = holder;
            // We got surface to draw on, start streamer creation

            SimpleOrientationListener mOrientationListener = null;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                mOrientationListener = new SimpleOrientationListener(
                        mContext) {

                    @Override
                    public void onSimpleOrientationChanged(int orientation) {
                        if(orientation == Configuration.ORIENTATION_LANDSCAPE && mStreamerGL != null){
                            mStreamerGL.setVideoOrientation(StreamerGL.Orientations.LANDSCAPE);
                        }else if(orientation == Configuration.ORIENTATION_PORTRAIT && mStreamerGL != null){
                            mStreamerGL.setVideoOrientation(StreamerGL.Orientations.PORTRAIT);
                        }
                    }
                };
            }
            mOrientationListener.enable();
        }

        @Override
        public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            if (mStreamerGL != null) {
                mStreamerGL.setSurfaceSize(new Streamer.Size(width, height));
            }
        }

        @Override
        public void surfaceDestroyed(SurfaceHolder holder) {
            mHolder = null;
            releaseStreamer();
        }

        private void releaseStreamer() {
            if (mStreamerGL != null) {
                mStreamerGL.release();
                mStreamerGL = null;
            }
        }
    };

    private HashMap<String, Boolean> checkPermissions() {
        HashMap<String, Boolean> permissions = new HashMap<String, Boolean>();
        permissions.put("cameraAllowed", ContextCompat.checkSelfPermission(
                mContext,
                Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED);

        permissions.put("audioAllowed", ContextCompat.checkSelfPermission(
                mContext,
                Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED);
        return permissions;
    }

    private void createStreamer() {
        if (mStreamerGL != null) {
            return;
        }

        builder = new StreamerGLBuilder();
        boolean camera2 = CameraRegistry.allowCamera2Support(mContext);
        cameraList = CameraRegistry.getCameraList(mContext, camera2);
        activeCameraInfo = CameraSettings.getActiveCameraInfo(mContext, mCameraId, cameraList);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            builder.setContext(mContext);
        }
        builder.setListener(this);

        // default config: 44.1kHz, Mono, CAMCORDER input
        builder.setAudioConfig(new AudioConfig());

        // default config: h264, 2 mbps, 2 sec. keyframe interval
//        final VideoConfig videoConfig = VideoEncoderSettings.newVideoConfig(
//                mContext, mSize, 30);

        final VideoConfig videoConfig = new VideoConfig();
        videoConfig.videoSize = mSize;
//
//
//        MediaCodecInfo currentCodec = null;
//        MediaCodecInfo.CodecProfileLevel codecProfileLevel = null;
//
//        final MediaCodecList mediaCodecList = new MediaCodecList(MediaCodecList.REGULAR_CODECS);
//        for (MediaCodecInfo codecInfo : mediaCodecList.getCodecInfos()) {
//            System.out.println("mano só os tipos "+ codecInfo.getSupportedTypes());
//            System.out.println("mano qual o nome "+ codecInfo.getName());
//            System.out.println("mano is encoder is here : "+ codecInfo.isEncoder());
//            if (!codecInfo.isEncoder()) {
//                continue;
//            }
//            for (String type : codecInfo.getSupportedTypes()) {
//                System.out.println("tipos de decodec "+ type);
//                if (type.equalsIgnoreCase("video/avc")) {
//                    currentCodec = codecInfo;
//                }
//            }
//        }
//
//        if(currentCodec != null) {
//            final MediaCodecInfo.CodecCapabilities capabilities = currentCodec.getCapabilitiesForType("video/avc");
//
//            for (MediaCodecInfo.CodecProfileLevel profileLevel : capabilities.profileLevels) {
//                if (profileLevel.profile == 65536) {
//
//                    codecProfileLevel =  profileLevel;
//                }
//            }
//        }
//        videoConfig.profileLevel = codecProfileLevel;

        builder.setVideoConfig(videoConfig);
        builder.setCamera2(Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP);

        // preview surface
        builder.setSurface(mHolder.getSurface());
        builder.setSurfaceSize(new Streamer.Size(mSurfaceView.getWidth(), mSurfaceView.getHeight()));


        // we add single default back camera
        final CameraConfig cameraConfig = new CameraConfig();
        cameraConfig.cameraId = mCameraId;
        cameraConfig.videoSize = mSize;

        builder.addCamera(cameraConfig);

        // streamer will start capture from this camera id
        builder.setCameraId(activeCameraInfo.cameraId);
        builder.setVideoOrientation(videoOrientation());
        builder.setDisplayRotation(displayRotation());

        mStreamerGL = builder.build();

        if (mStreamerGL != null) {
            mStreamerGL.startVideoCapture();
            mStreamerGL.startAudioCapture();
        }

        updatePreviewRatio(mPreviewFrame, mSize);
    }

    @NonNull
    @Override
    public View getView() {
        return container;
    }

    @Override
    public void dispose() {
        releaseStreamer();
    }

    private boolean isPortrait() {
        return mContext.getResources().getConfiguration().orientation == Configuration.ORIENTATION_PORTRAIT;
    }

    private int videoOrientation() {
        return isPortrait() ? StreamerGL.Orientations.PORTRAIT : StreamerGL.Orientations.LANDSCAPE;
    }

    private int displayRotation() {
        return activity.getWindowManager().getDefaultDisplay().getRotation();
    }

    private void updatePreviewRatio(AspectFrameLayout frame, Streamer.Size size) {
        if (frame != null && size != null) {
            frame.setAspectRatio(isPortrait() ? size.getVerticalRatio() : size.getRatio());
        }
    }

    @Override
    public void onAudioCaptureStateChanged(Streamer.CaptureState state) {
        mAudioCaptureState = state;
    }

    @Override
    public void onRecordStateChanged(Streamer.RecordState recordState, Uri uri, Streamer.SaveMethod saveMethod) {

    }

    @Override
    public void onSnapshotStateChanged(Streamer.RecordState recordState, Uri uri, Streamer.SaveMethod saveMethod) {

    }

    @Override
    public Handler getHandler() {
        return mHandler;
    }

    @Override
    public void onConnectionStateChanged(int i, Streamer.ConnectionState connectionState, Streamer.Status status, JSONObject jsonObject) {
        Map<String, Object> data = new HashMap<>();
        data.put("connectionState", connectionState.name());
        methodChannel.invokeMethod("streamChanged", data);

    }

    private void maybeCreateStream() {
        if (mStreamerGL != null
                && mVideoCaptureState == Streamer.CaptureState.STARTED
                && mAudioCaptureState == Streamer.CaptureState.STARTED) {
            ConnectionConfig conn = new ConnectionConfig();
            conn.uri = mUri;
            connectionId = mStreamerGL.createConnection(conn);
        }
    }

    protected void mute(boolean mute) {
        if (mStreamerGL == null) {
            return;
        }
        // How to mute audio:
        // Option 1 - stop audio capture and as result stop sending audio packets to server
        // Some players can stop playback if client keeps sending video, but sends no audio packets
        // Option 2 (workaround) - set PCM sound level to zero and encode
        // This produces silence in audio stream
        
        if (mAudioCaptureState == Streamer.CaptureState.STARTED) {
            mIsMuted = mute;
            mStreamerGL.setSilence(mIsMuted);
        }
    }

    @Override
    public void onVideoCaptureStateChanged(Streamer.CaptureState state) {
        mVideoCaptureState = state;
    }

    @Override
    public void onActivityCreated(@NonNull Activity activity, @Nullable Bundle savedInstanceState) {

    }

    @Override
    public void onActivityStarted(@NonNull Activity activity) {

    }

    @Override
    public void onActivityResumed(@NonNull Activity activity) {

    }

    @Override
    public void onActivityPaused(@NonNull Activity activity) {

    }

    @Override
    public void onActivityStopped(@NonNull Activity activity) {

    }

    @Override
    public void onActivitySaveInstanceState(@NonNull Activity activity, @NonNull Bundle outState) {

    }

    @Override
    public void onActivityDestroyed(@NonNull Activity activity) {

    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {

        switch(call.method) {
            case "startStream":
                maybeCreateStream();
                result.success(connectionId);
                break;
            case "stopStream":
                mStreamerGL.releaseConnection(connectionId);
                result.success(connectionId);
                break;
            case "flipCamera":
                for (CameraInfo info : cameraList) {
                    if (!info.cameraId.contains(mCameraId)) {
                        activeCameraInfo = CameraSettings.getActiveCameraInfo(mContext, info.cameraId, cameraList);
                    }
                }
                final CameraConfig flipCameraConfig = new CameraConfig();
                flipCameraConfig.cameraId = activeCameraInfo.cameraId;
                flipCameraConfig.videoSize = mSize;
                builder.addCamera(flipCameraConfig);
                mStreamerGL.flip();
                Map<String, Object> data = new HashMap<>();
                data.put("cameraId", activeCameraInfo.cameraId);
                result.success(data);
                break;
            case "stopAudioCapture":
                mute(true);
                Map<String, Object> dataAudioStop = new HashMap<>();
                dataAudioStop.put("mute", mIsMuted);
                result.success(dataAudioStop);
                break;
            case "startAudioCapture":
                mute(false);
                Map<String, Object> dataAudioStart = new HashMap<>();
                dataAudioStart.put("mute", mIsMuted);
                result.success(dataAudioStart);
                break;
            case "stopVideoCapture":
                mStreamerGL.stopVideoCapture();
                result.success("true");
                break;
            case "startVideoCapture":
                mStreamerGL.startVideoCapture();
                result.success("true");
                break;
            case "setDisplayRotation":
                mStreamerGL.setDisplayRotation(1);
                result.success("true");
                break;
            case "toggleTorch":
                mStreamerGL.toggleTorch();
                result.success(mStreamerGL.isTorchOn() ? "true" : "false");
                break;
            case "getPermissions":
                Map<String, Boolean> permissions = new HashMap();
                permissions.put("hasAudioPermission", cameraPermissions.hasAudioPermission(activity));
                permissions.put("hasCameraPermission", cameraPermissions.hasCameraPermission(activity));
                result.success(permissions);
                break;
            case "requestPermissions":
                cameraPermissions.requestPermissions(
                        activity,
                        permissionsRegistry,
                        (String errCode, String errDesc) -> {
                            if (errCode == null) {
                                try {
                                    Map<String, Boolean> reply = new HashMap();
                                    reply.put("hasCameraPermission", true);
                                    reply.put("hasAudioPermission", true);
                                    result.success(reply);
                                } catch (Exception e) {
                                    result.error("CameraAccess", e.getMessage(), null);
                                }
                            } else {
                                result.error(errCode, errDesc, null);
                            }
                        });
                break;
            case "initCamera":
                HashMap<String, Boolean> permission = checkPermissions();
                if (permission.get("cameraAllowed") && permission.get("audioAllowed")) {
                    createStreamer();
                    result.success("camera started");
                } else {
                    result.success("camera without permission");
                }
                break;
            case "disposeCamera":
                releaseStreamer();
                break;
            default:
                result.notImplemented();
        }

    }
}
