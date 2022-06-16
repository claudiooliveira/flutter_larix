#import <Foundation/Foundation.h>
#import "StreamerEngineDelegate.h"

@interface ConnectionConfig : NSObject

//! @brief Stream URL (for RTMP should nclude stream key)
@property NSURL* uri;
//! @brief connection mode: Send both audio and video frames or just audio or video
@property ConnectionMode mode;
//! @brief RTMP authenication or  provider-specific mode
@property ConnectionAuthMode auth;

/*! @brief Authenication username
    @discussion For RTMP connection with default auth mode, you shoud provide credentials in URL instead
    (in a form of rtmp://myserver.info/application_key?rtmpauth=username:password/stream_key)
*/
@property NSString* username;
//! @brief Authenication password
@property NSString* password;

/*! @brief Limit of unsent data
    @discussion StreamerEngine will send connectionStateDidChangeId
        with state = kConnectionStateDisconnected and status = kConnectionStatusTimeout
        when send delay will exceed this value
*/
@property UInt64 unsentThresholdMs;

@end
