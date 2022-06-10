# ConnectionConfig
@Metadata {
    @DocumentationExtension(mergeBehavior: append)
}

Parameters for RTMP/RTSP connection

## Declaration



    typedef NS_ENUM(int, ConnectionAuthMode) {
        kConnectionAuthModeDefault = 0,
        kConnectionAuthModeLlnw = 1,
        kConnectionAuthModePeriscope = 2,
        kConnectionAuthModeRtmp = 3,
        kConnectionAuthModeAkamai = 4
    };

    typedef NS_ENUM(int, ConnectionMode) {
        kConnectionModeVideoAudio = 0,
        kConnectionModeVideoOnly = 1,
        kConnectionModeAudioOnly = 2
    };

    @interface ConnectionConfig : NSObject

        @property NSURL* uri;
        @property ConnectionMode mode;
        @property ConnectionAuthMode auth;
        @property NSString* username;
        @property NSString* password;
        @property UInt64 unsentThresholdMs;

    @end



### Instance Properties
    uri: NSURL
Stream URL (for RTMP should include stream key)

    mode: ConnectionMode
Connection mode: Send both audio and video frames or just audio or video

    auth: ConnectionAuthMode

RTMP authenication or  provider-specific mode

    username: NSString

Authenication username
- Note: For RTMP connection with default auth mode, you shoud provide credentials in URL instead (in a form of rtmp://myserver.info/application_key?rtmpauth=username:password/stream_key)

    password: NSString

Authenication password

    unsentThresholdMs: UInt64 

Limit of unsent data
- Note: StreamerEngine will send connectionStateDidChangeId
with state = kConnectionStateDisconnected and status = kConnectionStatusTimeout
when send delay will exceed this value
