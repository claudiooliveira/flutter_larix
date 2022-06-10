//! @brief RTMP authenication mode
typedef NS_ENUM(int, ConnectionAuthMode) {
    //! @biref Default (no authenication or credentials in stream URL)
    kConnectionAuthModeDefault = 0,
    //! @biref Limelight authenication
    kConnectionAuthModeLlnw = 1,
    //! @biref Periscope-specific mode (no authenication related, just set chunk size to 4KB)
    kConnectionAuthModePeriscope = 2,
    //! @biref Standard RTMP authentication
    kConnectionAuthModeRtmp = 3,
    //! @biref Akamai specific mode (standard RTMP auth and 32KB chunk size)
    kConnectionAuthModeAkamai = 4
};

typedef NS_ENUM(int, ConnectionMode) {
    kConnectionModeVideoAudio = 0,
    kConnectionModeVideoOnly = 1,
    kConnectionModeAudioOnly = 2
};

//! @brief SRT retransmission algorithm (SRTO_RETRANSMITALGO)
typedef NS_ENUM(int, ConnectionRetransmitAlgo) {
    //! @brief Default (retransmit on every loss report)
    kConnectionRetransmitAlgoDefault = 0,
    //! @brief Reduced retransmissions (not more often than once per RTT); reduced bandwidth consumption
    kConnectionRetransmitAlgoReduced = 1
};

typedef NS_ENUM(int, ConnectionState) {
    kConnectionStateInitialized,
    kConnectionStateConnected,
    kConnectionStateSetup,
    kConnectionStateRecord,
    kConnectionStateDisconnected
};

typedef NS_ENUM(int, ConnectionStatus) {
    kConnectionStatusSuccess,
    kConnectionStatusConnectionFail,
    kConnectionStatusAuthFail,
    kConnectionStatusUnknownFail,
    kConnectionStatusTimeout
};

typedef NS_ENUM(int, RecordState) {
    kRecordStateInitialized,
    kRecordStateStarted,
    kRecordStateStopped,
    kRecordStateFailed,
    kRecordStateStalled
};

//! @brief Method to produce video file:
typedef NS_ENUM(int, FileWritingMode) {
    //! @brief Use same session as for streaming, better performance
    kFileWritingModeSharedSession = 0,
    //! @brief Use separate compression session in AVAssetWriter, compatible with Video Editor and other iOS tools
    kFileWritingModeSeparateSession = 1
};


@protocol StreamerEngineDelegate<NSObject>
/*! @brief Connection state update
    @param connectionID Connection identifer returned by createConnection / createSrtConnection / createRistConnection
    @param state State of connection
    @param status Status of connection
    @param info Additional error details
 */
- (void)connectionStateDidChangeId:(int)connectionID State:(ConnectionState)state Status:(ConnectionStatus)status Info:(nonnull NSDictionary*)info;

/*! @brief Recording state update
    @param state State of recording
    @param url Recording file URL
 */
@optional
- (void)recordStateDidChange: (RecordState) state url: (nullable NSURL*) url;

@end
