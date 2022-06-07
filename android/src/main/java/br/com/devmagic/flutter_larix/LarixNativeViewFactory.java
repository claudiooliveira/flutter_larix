package br.com.devmagic.flutter_larix;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Map;

import br.com.devmagic.flutter_larix.camera.CameraPermissions;
import io.flutter.Log;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

class LarixNativeViewFactory extends PlatformViewFactory {
    CameraPermissions.PermissionsRegistry permissionsRegistry;
    Activity act;
    @NonNull
    private final BinaryMessenger messenger;

    LarixNativeViewFactory(@NonNull BinaryMessenger messenger, CameraPermissions.PermissionsRegistry permissionsRegistry, Activity activity) {
        super(StandardMessageCodec.INSTANCE);
        this.permissionsRegistry = permissionsRegistry;
        act = activity;
        this.messenger = messenger;
    }

    @NonNull
    @Override
    public PlatformView create(@NonNull Context context, int id, @Nullable Object args) {
        final Map<String, Object> creationParams = (Map<String, Object>) args;
        return new LarixNativeView(messenger, permissionsRegistry,new CameraPermissions(), act, context, id, creationParams);
    }
}