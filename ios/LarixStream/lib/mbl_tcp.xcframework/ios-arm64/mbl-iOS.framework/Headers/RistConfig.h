#import <Foundation/Foundation.h>
#import "StreamerEngineDelegate.h"


typedef NS_ENUM(int, RistProfile) {
    kRistProfileSimple = 0,
    kRistProfileMain = 1,
    kRistProfileAdvanced = 2
};

@interface RistConfig : NSObject

/*! @brief Stream URL
    @discussion Entire string with parameters are passed to RIST library, so you may set RIST-specific settings here
 */
@property NSURL* uri;
//! @brief connection mode: Send both audio and video frames or just audio or video
@property ConnectionMode mode;
/*! @brief RIST profile
    @discussion Advanced profile is not currently implemented in the library, you must choose between Simple or Main
 */
@property RistProfile profile;

@end
