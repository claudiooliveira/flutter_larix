package br.com.devmagic.flutter_larix.libcommon;

import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.BatteryManager;

@SuppressWarnings("MissingPermission")
public class PlatformUtils {

    private static final IntentFilter actionBatteryChanged = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);

    public static boolean isBatteryLevelCritical(final Context context) {
        final Intent status = context.registerReceiver(null, actionBatteryChanged);
        if (status == null) {
            return false;
        }
        final int level = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        final int scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
        final double frac = level / (double) scale;
        //Log.d(TAG, "battery level at: " + frac);
        return frac < .07;
    }

    // https://developer.android.com/training/monitoring-device-state/connectivity-monitoring.html
    public static boolean isConnected(final Context context) {
        final ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) {
            return false;
        }
        final NetworkInfo activeNetwork = cm.getActiveNetworkInfo();
        return activeNetwork != null && activeNetwork.isConnected();
    }

}
