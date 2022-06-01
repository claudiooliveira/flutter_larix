package br.com.devmagic.flutter_larix;

import android.app.ActionBar;
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
import android.view.Gravity;
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
    private StreamerGL mStreamerGL;

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
    private Button btnFlipCamera;
    private OrientationEventListener orientationEventListener;
    int currentOrientation = 0;
    @NonNull
    StreamerGLBuilder builder;
    int connectionId = 0;

    private @NonNull Context mContext;
    private @NonNull Activity activity;

    private MethodChannel methodChannel;

    LarixNativeView(BinaryMessenger messenger, Activity activity, @NonNull Context context, int id, @Nullable Map<String, Object> creationParams) {
        mContext = context;
        this.activity = activity;
        mCameraId = "0";
        mHandler = new Handler(Looper.getMainLooper());
        mSize = new Streamer.Size(1280, 720);
        mUri = creationParams.get("url").toString();
        container = new LinearLayout(context);
        container.setOrientation(LinearLayout.VERTICAL);

        methodChannel = new MethodChannel(messenger, "br.com.devmagic.flutter_larix/nativeview_" + id);
        methodChannel.setMethodCallHandler(this);

        int textViewId = View.generateViewId();
        int frameLayoutId = View.generateViewId();

        FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT);

        TextView textView = new TextView(context);
        textView.setId(textViewId);
        textView.setTextSize(22);
        textView.setBackgroundColor(Color.rgb(255, 255, 255));
        textView.setText("Rendered on a native Android view (id: " + id + ")");

        FrameLayout frameLayout = new FrameLayout(context);
        frameLayout.setId(frameLayoutId);
        frameLayout.setLayoutParams(layoutParams);
        frameLayout.setBackgroundColor(ContextCompat.getColor(context, R.color.design_default_color_error));

        //container.addView(view);
//        container.addView(textView);
//        container.addView(frameLayout);

        ViewGroup root = (ViewGroup) LayoutInflater.from(activity).inflate(R.layout.afl_surface, container, true);

        mPreviewFrame = root.findViewById(R.id.preview_afl);
        //btnFlipCamera = root.findViewById(R.id.btnFlipCamera);

        mSurfaceView = root.findViewById(R.id.surface_view);
        mSurfaceView.getHolder().addCallback(mPreviewHolderCallback);

        //LayoutInflater.from(activity).inflate(R.layout.activity_main, this.container);

        //activity.addContentView(container, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT));

        Log.e("LARIX_API", "View id " + textViewId + " this id: " + id);
        Log.e("LARIX_API", "Activity details: " + activity.getTaskId());
        Log.e("LARIX_API", "Context details: " + activity.getTaskId());

//        new Handler(Looper.getMainLooper()).postDelayed(
//                new Runnable() {
//                    public void run() {
//                        FragmentManager fm = activity.getFragmentManager();
//                        fm.beginTransaction()
//                                .replace(frameLayoutId, StreamerFragment.newInstance(
//                                        "0",
//                                        1280, 720,
//                                        "rtmp://origin-v2.vewbie.com:1935/origin/2b866520-11c5-4818-9d2a-6cfdebbb8c8a"))
//                                .commit();
//                    }
//                },
//                1000);

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
            // We got surface to draw on, start streamer creation
            createStreamer();
            SimpleOrientationListener mOrientationListener = null;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                mOrientationListener = new SimpleOrientationListener(
                        mContext) {

                    @Override
                    public void onSimpleOrientationChanged(int orientation) {
                        if(orientation == Configuration.ORIENTATION_LANDSCAPE){
                            android.util.Log.e("ORIENTATION", "SALVE ORIENTATION_LANDSCAPE");
                            mStreamerGL.setVideoOrientation(StreamerGL.Orientations.LANDSCAPE);
                        }else if(orientation == Configuration.ORIENTATION_PORTRAIT){
                            android.util.Log.e("ORIENTATION", "SALVE ORIENTATION_PORTRAIT");
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
                Log.e("STOP_CONNECTION", "ID: " + connectionId);
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
                Log.e("LARIX_METHOD_CHANNEL","inicio teste stopVideoCapture");
                mStreamerGL.stopVideoCapture();
                Log.e("LARIX_METHOD_CHANNEL","fim teste stopVideoCapture");
                result.success("true");
                break;
            case "startVideoCapture":
                Log.e("LARIX_METHOD_CHANNEL","inicio teste startVideoCapture");
                mStreamerGL.startVideoCapture();
                Log.e("LARIX_METHOD_CHANNEL","fim teste startVideoCapture");
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
//            case "getActiveCameraId":
//                mStreamerGL.getActiveCameraId();
//                break;
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