package br.com.devmagic.flutter_larix;

import android.Manifest;
import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
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
import android.hardware.camera2.CaptureRequest;

import com.wmspanel.libstream.AudioConfig;
import com.wmspanel.libstream.CameraConfig;
import com.wmspanel.libstream.ConnectionConfig;
import com.wmspanel.libstream.Streamer;
import com.wmspanel.libstream.StreamerGL;
import com.wmspanel.libstream.StreamerGLBuilder;
import com.wmspanel.libstream.VideoConfig;
import com.wmspanel.libstream.FocusMode;

import org.json.JSONObject;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

import br.com.devmagic.flutter_larix.camera.CameraInfo;
import br.com.devmagic.flutter_larix.camera.CameraPermissions;
import br.com.devmagic.flutter_larix.camera.CameraPermissions.PermissionsRegistry;
import br.com.devmagic.flutter_larix.camera.CameraRegistry;
import br.com.devmagic.flutter_larix.camera.CameraSettings;
import br.com.devmagic.flutter_larix.conditioner.StreamConditionerBase;
import br.com.devmagic.flutter_larix.libcommon.ConnectionStatistics;
import io.flutter.Log;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

class LarixNativeView implements PlatformView, Streamer.Listener, Application.ActivityLifecycleCallbacks, MethodChannel.MethodCallHandler {
    @NonNull private final LinearLayout container;

    private static final String TAG = "StreamerFragment";

    private StreamerGL mStreamerGL;
    private StreamConditionerBase mConditioner;
    private final PermissionsRegistry permissionsRegistry;
    private final CameraPermissions cameraPermissions;
    private List<CameraInfo> cameraList;
    private CameraInfo activeCameraInfo;
    private String mCameraId;
    private Streamer.Size mSize;
    private String mUri;
    protected boolean mIsMuted;
    private Handler mHandler;
    private final Map<Integer, ConnectionStatistics> mConnectionStatistics = new HashMap();
    private final Map<Integer, Streamer.ConnectionState> mConnectionState = new HashMap<>();
    protected int mCurrentBitrate;
    private boolean recording = false;

    protected float mScaleFactor;

    private Streamer.CaptureState mVideoCaptureState = Streamer.CaptureState.FAILED;
    private Streamer.CaptureState mAudioCaptureState = Streamer.CaptureState.FAILED;

    protected AspectFrameLayout mPreviewFrame;

    private SurfaceView mSurfaceView;
    private SurfaceHolder mHolder;
    private Timer mUpdateStatisticsTimer;

    private final FocusMode mFocusMode = new FocusMode();

    int bitRateValue = 2000;

    @NonNull
    StreamerGLBuilder builder;
    int connectionId = 0;

    private @NonNull Context mContext;
    private @NonNull Activity activity;

    private MethodChannel methodChannel;

    private Timer reconnectTimer;
    private TimerTask reconnectTimerTask = null;


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
                        if(Settings.System.getInt(activity.getContentResolver(), Settings.System.ACCELEROMETER_ROTATION, 0) == 1){
                            if(orientation == Configuration.ORIENTATION_LANDSCAPE && mStreamerGL != null ){
                                mStreamerGL.setVideoOrientation(StreamerGL.Orientations.LANDSCAPE);
                            }else if(orientation == Configuration.ORIENTATION_PORTRAIT && mStreamerGL != null){
                                mStreamerGL.setVideoOrientation(StreamerGL.Orientations.PORTRAIT);
                            }
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

    private void createStreamer(int bitRate) {
        if (mStreamerGL != null) {
            return;
        }
        mCurrentBitrate = bitRate;

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

       if(bitRate != 0){
        videoConfig.bitRate = bitRate;
       }

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

        mConditioner = StreamConditionerBase.newInstance(mContext,
                videoConfig.bitRate, activeCameraInfo);
    }

    @NonNull
    @Override
    public View getView() {
        return container;
    }

    @Override
    public void dispose() {
        if (mUpdateStatisticsTimer != null) {
            mUpdateStatisticsTimer.cancel();
            mUpdateStatisticsTimer = null;
        }
        if (mStreamerGL != null) {
            mStreamerGL.release();
            mStreamerGL = null;
        }
        if (mHandler != null) {
            mHandler.removeCallbacks(mUpdateStatistics);
        }
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
        mConnectionState.put(connectionId, connectionState);
        methodChannel.invokeMethod("streamChanged", data);

    }

    private void maybeCreateStream() {
        if (mStreamerGL != null
                && mVideoCaptureState == Streamer.CaptureState.STARTED
                && mAudioCaptureState == Streamer.CaptureState.STARTED) {
            ConnectionConfig conn = new ConnectionConfig();
            conn.uri = mUri;

            connectionId = mStreamerGL.createConnection(conn);
            if (connectionId != -1) {
                if (mConditioner != null) {
                    mConditioner.addConnection(connectionId);
                    mConditioner.start(mStreamerGL);
                }
            }

            mConnectionStatistics.put(connectionId, new ConnectionStatistics());
            if (mUpdateStatisticsTimer != null) {
                mUpdateStatisticsTimer.cancel();
                mUpdateStatisticsTimer = null;
            }
            mUpdateStatisticsTimer = new Timer();
            mUpdateStatisticsTimer.schedule(new TimerTask() {
                @Override
                public void run() {
                    mHandler.post(mUpdateStatistics);
                }
            }, 2000, 2000);
        }

            Streamer.ConnectionState state = mConnectionState.get(connectionId);
            if (state == Streamer.ConnectionState.RECORD) {
                ConnectionStatistics statistics = mConnectionStatistics.get(connectionId);
                if (statistics != null) {
                    statistics.update(mStreamerGL, connectionId);
                    Map<String, Object> data = new HashMap<>();
                    data.put("bandwidth", statistics.getBandwidth());
                    data.put("traffic", statistics.getTraffic());

                    methodChannel.invokeMethod("connectionStatistics", data);
                }
            }

    }


    String startRecord(String fileName){
        if (recording) {
            return "";
        }
        recording = true;
        File recordFile = createVideoPath(mContext, fileName);
        if (recordFile != null && mStreamerGL != null) {
            mStreamerGL.startRecord(recordFile);
        }
        return recordFile.getPath();
    }

    void stopRecord() {
        if (!recording) {
            return;
        }
        recording = false;
        mStreamerGL.stopRecord();
    }


    public static File createVideoPath(Context context, String fileName) {
        File imageThumbsDirectory = context.getExternalFilesDir("FOLDER");
        if (imageThumbsDirectory != null) {
            if (!imageThumbsDirectory.exists()) {
                imageThumbsDirectory.mkdir();
            }
        }
        String appDir = context.getExternalFilesDir(Environment.DIRECTORY_PICTURES).getAbsolutePath();
        File file = new File(appDir, fileName);
        return file;
    }

    protected final Runnable mUpdateStatistics = new Runnable() {
        @Override
        public void run() {

            if (mStreamerGL == null) {
                return;
            }

            if (connectionId == 0) {
                return;
            }

            Streamer.ConnectionState state = mConnectionState.get(connectionId);
            //Log.e("STATE", "Value: " + state);
            if (state == Streamer.ConnectionState.RECORD) {
                ConnectionStatistics statistics = mConnectionStatistics.get(connectionId);
                if (statistics != null) {
                    statistics.update(mStreamerGL, connectionId);
                    Map<String, Object> data = new HashMap<>();
                    data.put("bandwidth", statistics.getBandwidth());
                    data.put("traffic", statistics.getTraffic());
                    methodChannel.invokeMethod("connectionStatistics", data);

                    if (statistics.getBandwidth() > 0) {
                        connectionStatus(true);
                        if (reconnectTimerTask != null) {
                            Log.e("STREAM GL", "CANCEL!!!!!!");
                            reconnectTimerTask.cancel();
                            reconnectTimerTask = null;
                            reconnectTimer.cancel();
                            reconnectTimer = null;
                        }
                    }
                }
            }else if (state == Streamer.ConnectionState.IDLE || state == Streamer.ConnectionState.DISCONNECTED) {
                ConnectionStatistics statistics = mConnectionStatistics.get(connectionId);
                if (statistics != null) {
                    statistics.update(mStreamerGL, connectionId);
                    Map<String, Object> data = new HashMap<>();
                    data.put("bandwidth", statistics.getBandwidth());
                    data.put("traffic", statistics.getTraffic());
                }
                connectionStatus(false);

                if (reconnectTimerTask == null) {
                    reconnectTimerTask = new TimerTask() {
                        @Override
                        public void run() {
                            Log.e("STREAM GL", "RECONNECT TIMER.....");
                            if (mStreamerGL != null) {
                                mStreamerGL.releaseConnection(connectionId);
                            }
                            if (mConditioner != null) {
                                mConditioner.removeConnection(connectionId);
                            }
                            maybeCreateStream();
                        }
                    };
                }
                if (reconnectTimer == null) {
                    reconnectTimer = new Timer();
                    reconnectTimer.schedule(reconnectTimerTask, 10000, 10000);
                }

            }
        }
    };

    void connectionStatus(boolean connected) {
        Map<String, Object> data = new HashMap<>();
        data.put("isConnected", connected);
        methodChannel.invokeMethod("connectionStatus", data);
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
                if (mConditioner != null) {
                    mConditioner.removeConnection(connectionId);
                }
                mStreamerGL.releaseConnection(connectionId);
                mConnectionState.remove(connectionId);

                result.success(connectionId);
                break;
            case "startRecord":
                String fileName = call.arguments.toString();
                String filePath = startRecord(fileName);
                result.success(filePath);
                break;
            case "stopRecord":
                stopRecord();
                break;
            case "isRecording":
                result.success(recording);
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
            case "getRotatePermission":
                boolean permissionRotate = Settings.System.getInt(activity.getContentResolver(), Settings.System.ACCELEROMETER_ROTATION, 0) == 1;
                result.success(permissionRotate);
                break;
            case "setDisplayRotation":
                int value = new Integer(call.arguments.toString());
                mStreamerGL.setDisplayRotation(value);
                result.success("true");
                break;
            case "setZoom":
                final double zoom = call.argument("zoom");
                final boolean isManual = call.argument("isManual");
                Double D = new Double(zoom);
                double zoomResult = zoom(D.floatValue(), isManual);
                result.success(zoomResult);
                break;
            case "getZoomMax":
                Float maxZoom = new Float(mStreamerGL.getMaxZoom());
                result.success(maxZoom.doubleValue());
                break;
            case "setFocus":
                HashMap<String, Object> focus = (HashMap<String, Object>) call.arguments;
                Boolean autoFocus = (Boolean)focus.get("isAutoFocus");
                Float focusDistance = new Float(focus.get("distanceFocus").toString());
                changeFocusMode(autoFocus, focusDistance);
                result.success(focus);
                break;
            case "getCameraInfo":
                List<HashMap<String, Object>> camerasList = new ArrayList<>();
                for (CameraInfo info : cameraList) {
                    HashMap<String, Object> camera = new HashMap();
                    camera.put("minimumFocusDistance", info.minimumFocusDistance);
                    camera.put("isTorchSupported", info.isTorchSupported);
                    camera.put("maxZoom", info.maxZoom);
                    camera.put("isZoomSupported",info.isZoomSupported);
                    camera.put("maxExposure",info.maxExposure);
                    camera.put("minExposure",info.minExposure);
                    camera.put("lensFacing",info.lensFacing);
                    camera.put("cameraId",info.cameraId);
                    camerasList.add(camera);
                }
                result.success(camerasList);
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
            case "setBitRate":
                if (mStreamerGL == null) {
                    return;
                }
                int bitRate = new Integer(call.arguments.toString());
                mStreamerGL.changeBitRate(bitRate);
                break;
            case "getBitRate":
                result.success(mCurrentBitrate);
                break;
            case "reconnect":
                if (mStreamerGL == null) {
                    createStreamer(bitRateValue);
                    return;
                }
                if (mConditioner != null) {
                    mConditioner.removeConnection(connectionId);
                }
                mStreamerGL.releaseConnection(connectionId);
                maybeCreateStream();
                result.success("true");
                break;
            case "stopAutomaticBitRate":
                mConditioner.stop();
                break;
            case "startAutomaticBitRate":
                int bitrate = new Integer(call.arguments.toString());
                mConditioner.addConnection(connectionId);
                mConditioner.start(mStreamerGL);
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
                bitRateValue = new Integer(call.arguments.toString());
                
                HashMap<String, Boolean> permission = checkPermissions();
                if (permission.get("cameraAllowed") && permission.get("audioAllowed")) {
                    createStreamer(bitRateValue);
                    result.success("camera started");
                } else {
                    result.success("camera without permission");
                }
                break;
            case "disposeCamera":
                if (mConditioner != null) {
                    mConditioner.removeConnection(connectionId);
                }
                if (mStreamerGL != null) {
                    mStreamerGL.release();
                    mStreamerGL = null;
                }
                break;
            default:
                result.notImplemented();
        }

    }

    protected double zoom(float scaleFactor, boolean isManual) {
        if (mStreamerGL == null || mVideoCaptureState != Streamer.CaptureState.STARTED) {
            return 0.0;
        }

        mStreamerGL.zoomTo(scaleFactor);

        // Float zoomFloat = new Float(Math.round(mScaleFactor));

        return scaleFactor; // consume touch event
    }

    protected void changeFocusMode(boolean isAutoFocus, float focusDistance ) {
        if(isAutoFocus == false) {
            mFocusMode.focusMode = CaptureRequest.CONTROL_AF_MODE_OFF;
            mFocusMode.focusDistance = focusDistance;
        }
        else {
            mFocusMode.focusMode = CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO;
            mFocusMode.focusDistance = 0;
        }

        mStreamerGL.focus(mFocusMode);
    }

}