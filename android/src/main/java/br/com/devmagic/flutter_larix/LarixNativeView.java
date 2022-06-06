package br.com.devmagic.flutter_larix;

import android.app.ActionBar;
import android.Manifest;
import android.content.pm.PackageManager;
import android.app.Activity;
import android.app.Application;
import android.app.FragmentManager;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.OrientationEventListener;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.core.app.ActivityCompat;

import com.wmspanel.libstream.AudioConfig;
import com.wmspanel.libstream.CameraConfig;
import com.wmspanel.libstream.ConnectionConfig;
import com.wmspanel.libstream.Streamer;
import com.wmspanel.libstream.StreamerGL;
import com.wmspanel.libstream.StreamerGLBuilder;
import com.wmspanel.libstream.VideoConfig;

import org.json.JSONObject;

import br.com.devmagic.flutter_larix.camera.CameraInfo;
import br.com.devmagic.flutter_larix.camera.CameraListHelper;
import br.com.devmagic.flutter_larix.camera.CameraPermissions;
import br.com.devmagic.flutter_larix.camera.CameraPermissions.PermissionsRegistry;
import br.com.devmagic.flutter_larix.camera.CameraRegistry;
import br.com.devmagic.flutter_larix.camera.CameraSettings;
import io.flutter.Log;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

class LarixNativeView implements PlatformView, Streamer.Listener, Application.ActivityLifecycleCallbacks, MethodChannel.MethodCallHandler {
    @NonNull private final LinearLayout container;

    private static final String TAG = "StreamerFragment";

    private static final int REQUEST_LAUNCHV21 = 0;
    private static final String[] PERMISSION_LAUNCHV21 = new String[] {"android.permission.CAMERA","android.permission.RECORD_AUDIO","android.permission.WRITE_EXTERNAL_STORAGE"};
    private static final int REQUEST_LAUNCHV29 = 1;
    private static final String[] PERMISSION_LAUNCHV29 = new String[] {"android.permission.CAMERA","android.permission.RECORD_AUDIO"};

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
        int width = Integer.parseInt(creationParams.get("width").toString());
        int height = Integer.parseInt(creationParams.get("height").toString());
        String cameraType = creationParams.get("type").toString();

        switch (cameraType) {
            case "BACK":
                mCameraId = "0";
                break;
            case "FRONT":
                mCameraId = "1";
                break;
        }

        Log.e("LARIX_API", "WIDTH: " + width + "; HEIGHT: " + height);
        mSize = new Streamer.Size(1280, 720);
        mUri = creationParams.get("url").toString();
        FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT);
        container = new LinearLayout(context);
        container.setOrientation(LinearLayout.VERTICAL);
        container.setLayoutParams(layoutParams);

        methodChannel = new MethodChannel(messenger, "br.com.devmagic.flutter_larix/nativeview_" + id);
        methodChannel.setMethodCallHandler(this);

        ViewGroup root = (ViewGroup) LayoutInflater.from(activity).inflate(R.layout.afl_surface, container, true);

        mPreviewFrame = root.findViewById(R.id.preview_afl);
        mSurfaceView = root.findViewById(R.id.surface_view);
        mSurfaceView.getHolder().addCallback(mPreviewHolderCallback);

    }

    private final SurfaceHolder.Callback mPreviewHolderCallback = new SurfaceHolder.Callback() {
        @Override
        public void surfaceCreated(SurfaceHolder holder) {
            android.util.Log.v(TAG, "surfaceCreated()");

            if (mHolder != null) {
                android.util.Log.e(TAG, "SurfaceHolder already exists"); // should never happens
                return;
            }

            mHolder = holder;
//            launchWithPermissionCheck();
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
                        //mStreamerGL.flip();
                    }
                };
            }
            mOrientationListener.enable();
        }

        @Override
        public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            android.util.Log.v(TAG, "surfaceChanged() " + width + "x" + height);
            if (mStreamerGL != null) {
                mStreamerGL.setSurfaceSize(new Streamer.Size(width, height));
            }
        }

        @Override
        public void surfaceDestroyed(SurfaceHolder holder) {
            android.util.Log.v(TAG, "surfaceDestroyed()");
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

    private void launchWithPermissionCheck() {
//        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
//            LaunchActivityPermissionsDispatcher.launchV21WithPermissionCheck(this);
//        } else {
//            LaunchActivityPermissionsDispatcher.launchV29WithPermissionCheck(this);
//        }
//        HashMap<String, Boolean> permission = checkPermissions();
//         if (!permission.get("cameraAllowed") || !permission.get("audioAllowed")) {
//             String[] permissions = new String[2];
//             int n = 0;
//             if (!permission.get("cameraAllowed")) {
//                 permissions[n++] = Manifest.permission.CAMERA;
//             }
//             if (!permission.get("audioAllowed")) {
//                 permissions[n] = Manifest.permission.RECORD_AUDIO;
//             }
//             ActivityCompat.requestPermissions(
//                     activity,
//                     permissions,
//                     REQUEST_LAUNCHV21
//             );
//         }
    }

//    @Override
//    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
//        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
//        android.util.Log.v("kkk", "teste oque esta viendo no bangue");
//
//        if (requestCode == REQUEST_LAUNCHV21) {
//            for (int result : grantResults) {
//                android.util.Log.v("kkk", "teste oque esta viendo no bangue" + result);
//
//                if (result == PackageManager.PERMISSION_DENIED) {
//                    android.util.Log.v("kkk", "teste oque esta viendo deu ruim" + result);
//
//                    return;
//                }
//                else if (result == PackageManager.PERMISSION_GRANTED) {
//                    android.util.Log.v("kkk", "teste oque esta viendo deu bom" + result);
//                    createStreamer();
//
//                }
//            }
//        }
//    }


    private void createStreamer() {
        android.util.Log.v(TAG, "createStreamer()");
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
        final VideoConfig videoConfig = new VideoConfig();
        videoConfig.videoSize = mSize;
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
        mStreamerGL.release();
        mStreamerGL = null;
    }

    private boolean isPortrait() {
        return mContext.getResources().getConfiguration().orientation == Configuration.ORIENTATION_PORTRAIT;
    }

    private int videoOrientation() {
        android.util.Log.v("STREAM", "ORIENTATION? " + (isPortrait() ? "PORTRAIT" : "LANDSCAPE"));
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
        android.util.Log.d(TAG, "onAudioCaptureStateChanged, state=" + state);
        mAudioCaptureState = state;
        //maybeCreateStream();
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

        Log.e("LARIX_API", "connectionState >>>> " + connectionState.toString());

        Map<String, Object> data = new HashMap<>();
        data.put("connectionState", connectionState.name());
        methodChannel.invokeMethod("streamChanged", data);

    }

    private void maybeCreateStream() {
        if (mStreamerGL != null
                && mVideoCaptureState == Streamer.CaptureState.STARTED
                && mAudioCaptureState == Streamer.CaptureState.STARTED) {
            // audio+video encoding is running -> create stream
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
        android.util.Log.e(TAG, "onVideoCaptureStateChanged, state=" + state);
        mVideoCaptureState = state;
        //maybeCreateStream();
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
        Log.e("LARIX_METHOD_CHANNEL", "Call >>>>>>> " + call.method);
        Log.e("LARIX_METHOD_CHANNEL", "ARGUMENTS >>>>>>> " + call.arguments);

        switch(call.method) {
            case "startStream":
                maybeCreateStream();
                HashMap<String, Object> map = (HashMap<String, Object>) call.arguments;
                Log.i("MyTag", "map = " + map.get("cameraWidth")); // {key=value}
                result.success("true");
                break;
            case "stopStream":
                mStreamerGL.releaseConnection(connectionId);
                break;
            case "flip":
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
                                Log.e("LARIX_METHOD_CHANNEL", "Call >>>>>>> " + errCode +" error"+  errDesc);
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
                mStreamerGL.release();
                mStreamerGL = null;
                break;
            default:
                result.notImplemented();
        }

    }

//    @Override
//    public void onDetected(List<Map<String, Object>> data) {
//
//        context.runOnUiThread(new Runnable() {
//
//            @Override
//            public void run() {
//
//                methodChannel.invokeMethod("onDetected", data);
//            }
//        });
//    }
}