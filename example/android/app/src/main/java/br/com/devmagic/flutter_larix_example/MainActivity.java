package br.com.devmagic.flutter_larix_example;

import android.Manifest;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.util.ArrayList;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.GeneratedPluginRegistrant;
import br.com.devmagic.flutter_larix_example.databinding.ActivityMainBinding;

public class MainActivity extends FlutterActivity {

    int CAMERA_REQUEST = 9796;

    ActivityMainBinding viewBinding;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Log.e("LARIX_API", "Let's goooo");

        //viewBinding = ActivityMainBinding.inflate(getLayoutInflater());
        //setContentView(R.layout.activity_main);
        //setContentView(viewBinding.getRoot());



        boolean cameraAllowed = ContextCompat.checkSelfPermission(
                getContext(),
                Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED;

        boolean audioAllowed = ContextCompat.checkSelfPermission(
                getContext(),
                Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED;

        if (!audioAllowed || !cameraAllowed) {
            String[] permissions = new String[2];
            int n = 0;
            if (!cameraAllowed) {
                permissions[n++] = Manifest.permission.CAMERA;
            }
            if (!audioAllowed) {
                permissions[n] = Manifest.permission.RECORD_AUDIO;
            }
            ActivityCompat.requestPermissions(
                this,
                permissions,
                CAMERA_REQUEST
            );
        } else {
            //startCamera()
        }

//        if (savedInstanceState == null) {
//            checkPermissionsThenSetFragment();
//        }



    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        Log.e("LARIX_API", "CONFIGURE FLUTTER ENGINE");
        //GeneratedPluginRegistrant.registerWith(flutterEngine);
        flutterEngine.getPlatformViewsController()
            .getRegistry()
            .registerViewFactory("NativeView", new NativeViewFactory(this));
        Log.e("LARIX_API", "PART 2");
    }

    public void setFragment() {

    }

    public void checkPermissionsThenSetFragment() {
        Log.e("LARIX_API", "REQUEST LEK");
        boolean cameraAllowed = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
        boolean audioAllowed = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;

        if (cameraAllowed && audioAllowed) {
            setFragment();
        } else {
            String[] permissions = new String[2];
            int n = 0;
            if (!cameraAllowed) {
                permissions[n++] = Manifest.permission.CAMERA;
            }
            if (!audioAllowed) {
                permissions[n] = Manifest.permission.RECORD_AUDIO;
            }
            ActivityCompat.requestPermissions(this, permissions, CAMERA_REQUEST);
        }
    }


    @Override
    public void onConfigurationChanged(@NonNull Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        android.util.Log.v("SALVE", "bora bora bora");
        // Checks the orientation of the screen
        if (newConfig.orientation == Configuration.ORIENTATION_LANDSCAPE) {
            android.util.Log.v("SALVE", "landscape");
            //Toast.makeText(this, "landscape", Toast.LENGTH_SHORT).show();
        } else if (newConfig.orientation == Configuration.ORIENTATION_PORTRAIT){
            android.util.Log.v("SALVE", "portrait");
            //Toast.makeText(this, "portrait", Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == CAMERA_REQUEST) {
            for (int result : grantResults) {
                if (result == PackageManager.PERMISSION_DENIED) {
                    return;
                }
            }
            setFragment();
        }
    }

}
