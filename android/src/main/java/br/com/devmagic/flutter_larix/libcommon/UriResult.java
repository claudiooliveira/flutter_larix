package br.com.devmagic.flutter_larix.libcommon;

import android.util.Log;
import java.net.URI;
import java.net.URISyntaxException;

public class UriResult {

    public enum Error {
        INVALID_URI,
        MISSING_URI,
        MISSING_HOST,
        MISSING_SCHEME,
        UNSUPPORTED_SCHEME,
        MISSING_APP_STREAM,
        MISSING_PORT,
        STREAMID_FOUND,
        USERINFO_FOUND
    }

    public String uri;
    public String scheme;
    public String host;
    public int port;
    public UriResult.Error error = Error.INVALID_URI;
    public URISyntaxException syntaxException;
    public boolean isPlayback;

    public static boolean isRtmp(final String s) {
        return "rtmp".equalsIgnoreCase(s) || "rtmps".equalsIgnoreCase(s);
    }

    public static boolean isRtsp(final String s) {
        return "rtsp".equalsIgnoreCase(s) || "rtsps".equalsIgnoreCase(s);
    }

    public static boolean isSrt(final String s) {
        return "srt".equalsIgnoreCase(s);
    }

    public static boolean isRist(final String s) {
        return "rist".equalsIgnoreCase(s);
    }

    public static boolean isHttp(final String s) {
        return "http".equalsIgnoreCase(s) || "https".equalsIgnoreCase(s);
    }

    public static boolean isSldp(final String s) {
        return "ws".equalsIgnoreCase(s) || "wss".equalsIgnoreCase(s)
                || "sldp".equalsIgnoreCase(s) || "sldps".equalsIgnoreCase(s);
    }

    public static boolean isSupported(final String s) {
        return isRtmp(s) || isRtsp(s) || isSrt(s) || isRist(s);
    }

    public static boolean isPlayable(final String s) {
        return isRtmp(s) || isSrt(s) || isSldp(s) || isHttp(s);
    }

    public static boolean isSupported(final String s, boolean playback) {
        return playback ? isPlayable(s) : isSupported(s);
    }

    public boolean isRtmp() {
        return isRtmp(scheme);
    }

    public boolean isRtsp() {
        return isRtsp(scheme);
    }

    public boolean isSrt() {
        return isSrt(scheme);
    }

    public boolean isRist() {
        return isRist(scheme);
    }

    public boolean isHttp() {
        return isHttp(scheme);
    }

    public boolean isSldp() {
        return isSldp(scheme);
    }

    public static UriResult parseUri(final String originalUri, boolean playback) {
        final UriResult connection = new UriResult();
        connection.isPlayback = playback;

        if (originalUri == null || originalUri.isEmpty()) {
            connection.error = Error.MISSING_URI;
            return connection;
        }

        String newUri = originalUri;

        // android.net.Uri breaks IPv6 addresses in the wrong places, use Java’s own URI class
        final URI uri;
        try {
            uri = new URI(originalUri);
        } catch (URISyntaxException e) {
            connection.syntaxException = e;
            return connection;
        }

        final String host = uri.getHost();
        if (host == null) {
            connection.error = Error.MISSING_HOST;
            return connection;
        }
        connection.host = host;

        final String scheme = uri.getScheme();
        if (scheme == null) {
            connection.error = Error.MISSING_SCHEME;
            return connection;
        }

        connection.scheme = scheme;
        if (!UriResult.isSupported(scheme, playback)) {
            connection.error = Error.UNSUPPORTED_SCHEME;
            return connection;
        }

        if (connection.isRtmp()) {
            final String[] splittedPath = originalUri.split("/");
            if (splittedPath.length < 5) {
                connection.error = Error.MISSING_APP_STREAM;
                return connection;
            }
        }

        final int port = uri.getPort();
        if ((connection.isSrt() || connection.isRist()) && port <= 0) {
            connection.error = Error.MISSING_PORT;
            return connection;
        }
        connection.port = port;

        if (connection.isSrt()) {
            final String query = uri.getQuery();
            if (query != null && query.contains("streamid=")) {
                connection.error = Error.STREAMID_FOUND;
                return connection;
            }
            try {
                final URI builder = new URI(
                        scheme,
                        null,
                        host,
                        port,
                        null,
                        null,
                        null);
                newUri = builder.toString();
            } catch (URISyntaxException e) {
                connection.syntaxException = e;
                return connection;
            }

        } else {
            final String userInfo = uri.getUserInfo();
            if (userInfo != null) {
                connection.error = Error.USERINFO_FOUND;
                return connection;
            }
        }

        connection.uri = newUri;
        connection.error = null;
        return connection;
    }

}
