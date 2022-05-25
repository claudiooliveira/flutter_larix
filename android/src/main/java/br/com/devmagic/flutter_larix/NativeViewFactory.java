package br.com.devmagic.flutter_larix;


import android.app.Activity;
import android.content.Context;
import androidx.annotation.Nullable;
import androidx.annotation.NonNull;

import io.flutter.Log;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.util.Map;

class NativeViewFactory extends PlatformViewFactory {

    Activity act;

    //NativeViewFactory(Activity activity) {
    NativeViewFactory() {
        super(StandardMessageCodec.INSTANCE);
        Log.e("LARIX_API", "create native factory");
        //act = activity;
    }

    @NonNull
    @Override
    public PlatformView create(@NonNull Context context, int id, @Nullable Object args) {
        Log.e("LARIX_API", "bora??");
        final Map<String, Object> creationParams = (Map<String, Object>) args;

        return new NativeView(act, context, id, creationParams);
    }
}