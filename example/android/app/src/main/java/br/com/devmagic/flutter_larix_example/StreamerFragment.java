package br.com.devmagic.flutter_larix_example;

import android.app.Fragment;
import android.os.Bundle;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

/**
 * A simple {@link Fragment} subclass.
 * Use the {@link StreamerFragment#newInstance} factory method to
 * create an instance of this fragment.
 */
import android.content.res.Configuration;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.OrientationEventListener;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;

import androidx.annotation.NonNull;

import com.wmspanel.libstream.Streamer;
import com.wmspanel.libstream.AudioConfig;
import com.wmspanel.libstream.CameraConfig;
import com.wmspanel.libstream.ConnectionConfig;
import com.wmspanel.libstream.StreamerGL;
import com.wmspanel.libstream.StreamerGLBuilder;
import com.wmspanel.libstream.VideoConfig;

import org.json.JSONObject;

public class StreamerFragment extends Fragment implements Streamer.Listener {

    private static final String TAG = "StreamerFragment";

    private static final String URI = "uri";
    private static final String CAMERA_ID = "camera_id";
    private static final String WIDTH = "width";
    private static final String HEIGHT = "heigth";

    private StreamerGL mStreamerGL;

    private String mCameraId;
    private Streamer.Size mSize;
    private String mUri;

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

    public StreamerFragment() {
        // Required empty public constructor
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        ViewGroup root = (ViewGroup) inflater.inflate(R.layout.afl_surface, container, false);

        mPreviewFrame = root.findViewById(R.id.preview_afl);
        btnFlipCamera = root.findViewById(R.id.btnFlipCamera);

        mSurfaceView = root.findViewById(R.id.surface_view);
        mSurfaceView.getHolder().addCallback(mPreviewHolderCallback);

        Log.e("STREAM", "SALVE FAMILIA");

        btnFlipCamera.setOnClickListener(v -> {
            String newCameraId = "0";
            if (mStreamerGL.getActiveCameraId() == "0") {
                newCameraId = "1";
            }
            Log.e("STREAM", "Camera id " + mStreamerGL.getActiveCameraId());
            final CameraConfig cameraConfig = new CameraConfig();
            cameraConfig.cameraId = newCameraId;
            cameraConfig.videoSize = mSize;

            mStreamerGL.stopVideoCapture();
            mStreamerGL.stopAudioCapture();

            mStreamerGL.changeCameraConfig(cameraConfig);

            mStreamerGL.startVideoCapture();
            mStreamerGL.startAudioCapture();
        });

        return root;
    }

    private final SurfaceHolder.Callback mPreviewHolderCallback = new SurfaceHolder.Callback() {
        @Override
        public void surfaceCreated(SurfaceHolder holder) {
            Log.v(TAG, "surfaceCreated()");

            if (mHolder != null) {
                Log.e(TAG, "SurfaceHolder already exists"); // should never happens
                return;
            }

            mHolder = holder;
            // We got surface to draw on, start streamer creation
            createStreamer();
            SimpleOrientationListener mOrientationListener = null;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                mOrientationListener = new SimpleOrientationListener(
                        getContext()) {

                    @Override
                    public void onSimpleOrientationChanged(int orientation) {
                        if(orientation == Configuration.ORIENTATION_LANDSCAPE){
                            Log.e("ORIENTATION", "SALVE ORIENTATION_LANDSCAPE");
                            mStreamerGL.setVideoOrientation(StreamerGL.Orientations.LANDSCAPE);
                        }else if(orientation == Configuration.ORIENTATION_PORTRAIT){
                            Log.e("ORIENTATION", "SALVE ORIENTATION_PORTRAIT");
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
            Log.v(TAG, "surfaceChanged() " + width + "x" + height);
            if (mStreamerGL != null) {
                mStreamerGL.setSurfaceSize(new Streamer.Size(width, height));
            }
        }

        @Override
        public void surfaceDestroyed(SurfaceHolder holder) {
            Log.v(TAG, "surfaceDestroyed()");
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
        Log.v(TAG, "createStreamer()");
        if (mStreamerGL != null) {
            return;
        }

        builder = new StreamerGLBuilder();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            builder.setContext(getContext());
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

        // streamer will start capture from this camera id
        builder.setCameraId(mCameraId);

        // we add single default back camera
        final CameraConfig cameraConfig = new CameraConfig();
        cameraConfig.cameraId = mCameraId;
        cameraConfig.videoSize = mSize;

        builder.addCamera(cameraConfig);

        builder.setVideoOrientation(videoOrientation());
        builder.setDisplayRotation(displayRotation());

        mStreamerGL = builder.build();

        if (mStreamerGL != null) {
            mStreamerGL.startVideoCapture();
            mStreamerGL.startAudioCapture();
        }

        updatePreviewRatio(mPreviewFrame, mSize);
    }

    private boolean isPortrait() {
        return getResources().getConfiguration().orientation == Configuration.ORIENTATION_PORTRAIT;
    }

    private int videoOrientation() {
        Log.v("STREAM", "ORIENTATION? " + (isPortrait() ? "PORTRAIT" : "LANDSCAPE"));
        return isPortrait() ? StreamerGL.Orientations.PORTRAIT : StreamerGL.Orientations.LANDSCAPE;
    }

    private int displayRotation() {
        return getActivity().getWindowManager().getDefaultDisplay().getRotation();
    }

    private void updatePreviewRatio(AspectFrameLayout frame, Streamer.Size size) {
        if (frame != null && size != null) {
            frame.setAspectRatio(isPortrait() ? size.getVerticalRatio() : size.getRatio());
        }
    }

    /**
     * Use this factory method to create a new instance of
     * this fragment using the provided parameters.
     *
     * @param uri Stream uri.
     * @return A new instance of fragment SteamerFragment.
     */
    public static StreamerFragment newInstance(String cameraId, int width, int height, String uri) {
        StreamerFragment fragment = new StreamerFragment();
        Bundle args = new Bundle();
        args.putString(URI, uri);
        args.putInt(WIDTH, width);
        args.putInt(HEIGHT, height);
        args.putString(CAMERA_ID, cameraId);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public void onAudioCaptureStateChanged(Streamer.CaptureState state) {
        Log.d(TAG, "onAudioCaptureStateChanged, state=" + state);
        mAudioCaptureState = state;
        maybeCreateStream();
    }

    @Override
    public void onVideoCaptureStateChanged(Streamer.CaptureState state) {
        Log.e(TAG, "onVideoCaptureStateChanged, state=" + state);
        mVideoCaptureState = state;
        maybeCreateStream();
    }

    private void maybeCreateStream() {
        if (mStreamerGL != null
                && mVideoCaptureState == Streamer.CaptureState.STARTED
                && mAudioCaptureState == Streamer.CaptureState.STARTED) {
            // audio+video encoding is running -> create stream
            ConnectionConfig conn = new ConnectionConfig();
            conn.uri = mUri;
            mStreamerGL.createConnection(conn);
        }
    }

    @Override
    public void onConnectionStateChanged(int connectionId, Streamer.ConnectionState state, Streamer.Status status, JSONObject info) {
        Log.d(TAG, "onConnectionStateChanged, connectionId=" + connectionId + ", state=" + state + ", status=" + status);
    }

    @Override
    public void onRecordStateChanged(Streamer.RecordState state, Uri uri, Streamer.SaveMethod method) {
        Log.d(TAG, "onRecordStateChanged, state=" + state);
    }

    @Override
    public void onSnapshotStateChanged(Streamer.RecordState state, Uri uri, Streamer.SaveMethod method) {
        Log.d(TAG, "onSnapshotStateChanged, state=" + state);
    }

    @Override
    public Handler getHandler() {
        return mHandler;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mHandler = new Handler(Looper.getMainLooper());
        Bundle args = getArguments();
        if (args != null) {
            mCameraId = args.getString(CAMERA_ID);
            mSize = new Streamer.Size(args.getInt(WIDTH), args.getInt(HEIGHT));
            mUri = getArguments().getString(URI);
        }
    }
}