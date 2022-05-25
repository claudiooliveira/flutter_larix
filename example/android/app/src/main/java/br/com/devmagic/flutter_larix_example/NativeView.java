package br.com.devmagic.flutter_larix_example;

import android.app.Activity;
import android.app.FragmentManager;
import android.content.Context;
import android.graphics.Color;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.Log;
import io.flutter.plugin.platform.PlatformView;
import java.util.Map;

class NativeView implements PlatformView {
    @NonNull private final LinearLayout container;

    NativeView(Activity activity, @NonNull Context context, int id, @Nullable Map<String, Object> creationParams) {
        Log.e("LARIX_API", "TESTEEEEE");
        container = new LinearLayout(context);
        LayoutInflater.from(context).inflate(R.layout.activity_main, this.container);

        FragmentManager fm = activity.getFragmentManager();
        fm.beginTransaction()
                .replace(R.id.streamer, StreamerFragment.newInstance(
                        "0",
                        1280, 720,
                        "rtmp://origin-v2.vewbie.com:1935/origin/2b866520-11c5-4818-9d2a-6cfdebbb8c8a"))
                .commitAllowingStateLoss();

    }

    @NonNull
    @Override
    public View getView() {
        return container;
    }

    @Override
    public void dispose() {}


}