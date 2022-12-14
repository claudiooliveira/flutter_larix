package br.com.devmagic.flutter_larix.libcommon;

import android.annotation.TargetApi;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract;
import android.provider.MediaStore;
import android.provider.OpenableColumns;
import android.util.Log;

import androidx.annotation.Nullable;

import com.wmspanel.libstream.Streamer;
import com.wmspanel.libstream.StreamerGL;

import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

public class MediaFileUtils {
    private static final String TAG = "MediaFileUtils";

    private static final Map<Bitmap.CompressFormat, String> EXT_MAP = createExtMap();

    private static Map<Bitmap.CompressFormat, String> createExtMap() {
        Map<Bitmap.CompressFormat, String> result = new HashMap<>();
        result.put(Bitmap.CompressFormat.JPEG, ".jpg");
        result.put(Bitmap.CompressFormat.PNG, ".png");
        result.put(Bitmap.CompressFormat.WEBP, ".webp");
        return Collections.unmodifiableMap(result);
    }

    private static final Map<Bitmap.CompressFormat, String> MIME_MAP = createMimeMap();

    private static Map<Bitmap.CompressFormat, String> createMimeMap() {
        Map<Bitmap.CompressFormat, String> result = new HashMap<>();
        result.put(Bitmap.CompressFormat.JPEG, "image/jpg");
        result.put(Bitmap.CompressFormat.PNG, "image/png");
        result.put(Bitmap.CompressFormat.WEBP, "image/webp");
        return Collections.unmodifiableMap(result);
    }

    private static boolean isExternalStorageWritable() {
        return Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState());
    }

    public static File getDirectory(final String dirname) {
        File dir = null;
        if (isExternalStorageWritable()) {
            final File dcim = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM);
            dir = new File(dcim, dirname);
            if (!dir.exists()) {
                dir.mkdirs();
            }
        }
        return dir;
    }

    private static String createImageFilename(final String basename,
                                              final Bitmap.CompressFormat format) {
        final String extension = EXT_MAP.get(format);
        return extension != null ? basename.concat(extension) : basename.concat(".jpg");
    }

    private static String createRecordFilename(final String basename,
                                               final Streamer.Mode mode) {
        return basename.concat(mode == Streamer.Mode.AUDIO_ONLY ? ".m4a" : ".mp4");
    }

    @Nullable
    public static File newImageFile(final String dirname,
                                    final String basename,
                                    final Bitmap.CompressFormat format) {
        final File f = MediaFileUtils.getDirectory(dirname);
        if (f != null) {
            return new File(f, createImageFilename(basename, format));
        }
        return null;
    }

    @Nullable
    private static File newMp4File(final String dirname,
                                   final String basename,
                                   final Streamer.Mode mode) {
        final File f = getDirectory(dirname);
        if (f != null) {
            return new File(f, createRecordFilename(basename, mode));
        }
        return null;
    }

    public static boolean startRecordDCIM(final Context context,
                                          final Streamer streamer,
                                          final String dirname,
                                          final String basename,
                                          final Streamer.Mode mode,
                                          final boolean split) {
        boolean result = false;

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            final File f = newMp4File(dirname, basename, mode);
            if (f != null) {
                if (split) {
                    result = streamer.splitRecord(f);
                } else {
                    result = streamer.startRecord(f);
                }
            }
        } else {
            try {
                final ContentResolver resolver = context.getContentResolver();

                final Uri mime;
                final String parent;
                if (mode == Streamer.Mode.AUDIO_ONLY) {
                    mime = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
                    parent = Environment.DIRECTORY_PODCASTS;
                } else {
                    mime = MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
                    parent = Environment.DIRECTORY_DCIM;
                }

                final ContentValues contentValues = new ContentValues();
                contentValues.put(MediaStore.MediaColumns.DISPLAY_NAME, createRecordFilename(basename, mode));
                contentValues.put(MediaStore.MediaColumns.RELATIVE_PATH, parent.concat("/").concat(dirname));
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 1);

                final Uri recordUri = resolver.insert(mime, contentValues);
                if (recordUri != null) {
                    final ParcelFileDescriptor parcel = resolver.openFileDescriptor(recordUri, "rw");
                    if (parcel != null && parcel.getFileDescriptor() != null) {
                        if (split) {
                            result = streamer.splitRecord(parcel, recordUri, Streamer.SaveMethod.MEDIA_STORE);
                        } else {
                            result = streamer.startRecord(parcel, recordUri, Streamer.SaveMethod.MEDIA_STORE);
                        }
                    }
                }
            } catch (SecurityException | IOException e) {
                Log.e(TAG, Log.getStackTraceString(e));
            }
        }
        return result;
    }

    @TargetApi(Build.VERSION_CODES.O)
    public static boolean startRecordSAF(final Context context,
                                         final Streamer streamer,
                                         final String safUri,
                                         final String basename,
                                         final Streamer.Mode mode,
                                         final boolean split) {
        boolean result = false;

        try {
            final ContentResolver resolver = context.getContentResolver();

            final Uri treeUri = Uri.parse(safUri);
            final String documentId = DocumentsContract.getTreeDocumentId(treeUri);
            final Uri docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId);
            if (resolver != null && docUri != null) {
                final String mimeType = mode == Streamer.Mode.AUDIO_ONLY ? "audio/mp4" : "video/mp4";
                final String displayName = createRecordFilename(basename, mode);
                final Uri recordUri = DocumentsContract.createDocument(resolver, docUri, mimeType, displayName);
                if (recordUri != null) {
                    final ParcelFileDescriptor parcel = resolver.openFileDescriptor(recordUri, "rw");
                    if (parcel != null && parcel.getFileDescriptor() != null) {
                        if (split) {
                            result = streamer.splitRecord(parcel, recordUri, Streamer.SaveMethod.SAF);
                        } else {
                            result = streamer.startRecord(parcel, recordUri, Streamer.SaveMethod.SAF);
                        }
                    }
                }
            }
        } catch (IOException | IllegalArgumentException | IllegalStateException | SecurityException
                | UnsupportedOperationException e) {
            Log.e(TAG, Log.getStackTraceString(e));
        }
        return result;
    }

    public static void takeSnapshotDCIM(final Context context,
                                        final StreamerGL streamer,
                                        final String dirname,
                                        final String basename,
                                        final Bitmap.CompressFormat format,
                                        final int quality) {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                final File file = newImageFile(dirname, basename, format);
                if (file != null) {
                    streamer.takeSnapshot(file, format, quality, false);
                }
            } else {
                final ContentResolver resolver = context.getContentResolver();

                final ContentValues contentValues = new ContentValues();
                contentValues.put(MediaStore.MediaColumns.DISPLAY_NAME, createImageFilename(basename, format));
                contentValues.put(MediaStore.MediaColumns.RELATIVE_PATH,
                        Environment.DIRECTORY_DCIM.concat("/").concat(dirname));
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 1);

                final Uri imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues);
                if (imageUri != null) {
                    final OutputStream os = resolver.openOutputStream(imageUri);
                    if (os != null) {
                        streamer.takeSnapshot(os, imageUri, Streamer.SaveMethod.MEDIA_STORE, format, quality, false);
                    }
                }
            }
        } catch (SecurityException | IOException e) {
            Log.e(TAG, Log.getStackTraceString(e));
        }
    }

    @TargetApi(Build.VERSION_CODES.O)
    public static boolean takeSnapshotSAF(final Context context,
                                          final StreamerGL streamer,
                                          final String safUri,
                                          final String basename,
                                          final Bitmap.CompressFormat format,
                                          final int quality) {

        boolean result = false;

        try {
            final ContentResolver resolver = context.getContentResolver();

            final Uri treeUri = Uri.parse(safUri);
            final String documentId = DocumentsContract.getTreeDocumentId(treeUri);
            final Uri docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId);
            if (resolver != null && docUri != null) {
                final String mimeType = MIME_MAP.getOrDefault(format, "image/jpg");
                final String displayName = createImageFilename(basename, format);
                final Uri imageUri = DocumentsContract.createDocument(resolver, docUri, mimeType, displayName);
                if (imageUri != null) {
                    final OutputStream os = resolver.openOutputStream(imageUri);
                    if (os != null) {
                        streamer.takeSnapshot(os, imageUri, Streamer.SaveMethod.SAF, format, quality, false);
                    }
                    result = true;
                }
            }
        } catch (IOException | IllegalArgumentException | IllegalStateException | SecurityException
                | UnsupportedOperationException e) {
            Log.e(TAG, Log.getStackTraceString(e));
        }
        return result;
    }

    @Nullable
    public static String onCompleted(final Context context,
                                     final Uri uri,
                                     final Streamer.SaveMethod method,
                                     final MediaScannerConnection.OnScanCompletedListener callback) {
        String displayName = null;
        switch (method) {
            case FILE:
                if (uri.getPath() != null) {
                    refreshGallery(context, new File(uri.getPath()), callback);
                }
                break;
            case SAF:
                File file = null;
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    file = MediaFileUtils.getFileFromDocumentUriSAF(context, uri);
                    if (file != null) {
                        refreshGallery(context, file, callback);
                    }
                }
                if (file == null) {
                    displayName = uri.toString();
                }
                break;
            case MEDIA_STORE:
                displayName = finishInsert(context, uri);
                break;
            default:
                break;
        }
        return displayName;
    }

    @TargetApi(Build.VERSION_CODES.Q)
    private static String finishInsert(final Context context,
                                       final Uri uri) {
        String displayName = null;
        if (uri != null) {
            final ContentResolver resolver = context.getContentResolver();

            final ContentValues contentValues = new ContentValues();
            contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0);
            resolver.update(uri, contentValues, null, null);

            try (Cursor cursor = resolver.query(uri, null, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) {
                    final int nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                    displayName = cursor.getString(nameIndex);
                }
            } catch (IllegalArgumentException | SecurityException ignored) {
            }
        }
        return displayName;
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    private static File getFileFromDocumentUriSAF(final Context context,
                                                  final Uri uri) {
        File file = null;
        String authority = uri.getAuthority();
        if ("com.android.externalstorage.documents".equals(authority)) {
            final String id = DocumentsContract.getDocumentId(uri);
            String[] split = id.split(":");
            if (split.length >= 1) {
                String type = split[0];
                String path = split.length >= 2 ? split[1] : "";
                File[] storagePoints = new File("/storage").listFiles();
                if ("primary".equalsIgnoreCase(type)) {
                    final File externalStorage = Environment.getExternalStorageDirectory();
                    file = new File(externalStorage, path);
                }
                for (int i = 0; storagePoints != null && i < storagePoints.length && file == null; i++) {
                    File externalFile = new File(storagePoints[i], path);
                    if (externalFile.exists()) {
                        file = externalFile;
                    }
                }
                if (file == null) {
                    file = new File(path);
                }
            }
        } else if ("com.android.providers.downloads.documents".equals(authority)) {
            final String id = DocumentsContract.getDocumentId(uri);
            if (id.startsWith("raw:")) {
                String filename = id.replaceFirst("raw:", "");
                file = new File(filename);
            } else {
                try {
                    final Uri contentUri = ContentUris.withAppendedId(Uri.parse("content://downloads/public_downloads"), Long.parseLong(id));
                    String filename = getDataColumn(context, contentUri, null, null);
                    if (filename != null) {
                        file = new File(filename);
                    }
                } catch (NumberFormatException ignored) {
                }
            }
        } else if ("com.android.providers.media.documents".equals(authority)) {
            final String docId = DocumentsContract.getDocumentId(uri);
            final String[] split = docId.split(":");
            final String type = split[0];
            Uri contentUri = null;
            switch (type) {
                case "image":
                    contentUri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
                    break;
                case "video":
                    contentUri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
                    break;
                case "audio":
                    contentUri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
                    break;
            }
            final String selection = "_id=?";
            final String[] selectionArgs = new String[]{split[1]};
            String filename = getDataColumn(context, contentUri, selection, selectionArgs);
            if (filename != null) {
                file = new File(filename);
            }
        }
        return file;
    }

    private static String getDataColumn(final Context context,
                                        final Uri uri,
                                        final String selection,
                                        final String[] selectionArgs) {
        final String column = "_data";
        final String[] projection = {column};
        String result = null;
        try (Cursor cursor = context.getContentResolver().query(uri, projection, selection, selectionArgs, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                final int columnIndex = cursor.getColumnIndexOrThrow(column);
                result = cursor.getString(columnIndex);
            }
        } catch (IllegalArgumentException | SecurityException ignored) {
        }
        return result;
    }

    private static void refreshGallery(final Context context,
                                       final File file,
                                       final MediaScannerConnection.OnScanCompletedListener callback) {
        // refresh gallery
        if (file != null && file.exists()) {
            MediaScannerConnection.scanFile(
                    context,
                    new String[]{file.getAbsolutePath()},
                    null,
                    callback);
        }
    }

}
